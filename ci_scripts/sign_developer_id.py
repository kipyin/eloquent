#!/usr/bin/env python3
"""Sign an Xcode Cloud app with Developer ID Application.

Cloud's archive command passes CODE_SIGN_IDENTITY=- and
AD_HOC_CODE_SIGNING_ALLOWED=YES, which overrides Release-Signing.xcconfig.
The .xcarchive is Sign to Run Locally and has no team, so exportArchive fails
with "No Team Found in Archive". codesign replaces that signature directly.
Notarize runs after ci_post, so CI_DEVELOPER_ID_SIGNED_APP_PATH is not set yet.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

TEAM_RE = re.compile(r"^[A-Za-z0-9]{10}$")
QUOTED_DEVELOPER_ID_RE = re.compile(r'"(Developer ID Application:[^"]*)"')
PAREN_TEAM_RE = re.compile(r"\(([A-Za-z0-9]{10})\)")
VALID_IDENTITIES_MARKER = "Valid identities only"


def log(message):
    print(f"ci_post_xcodebuild: {message}", file=sys.stderr)


def redact(text, team):
    if not text:
        return text
    redacted = PAREN_TEAM_RE.sub("([team])", text)
    if team:
        redacted = re.sub(re.escape(team), "[team]", redacted, flags=re.IGNORECASE)
    return redacted


def run_codesign(args):
    completed = subprocess.run(args, check=False, capture_output=True)
    stdout = completed.stdout.decode("utf-8", "replace")
    stderr = completed.stderr.decode("utf-8", "replace")
    return completed.returncode, stdout, stderr


def identity_listing(security_output):
    marker_at = security_output.find(VALID_IDENTITIES_MARKER)
    if marker_at == -1:
        return security_output
    return security_output[marker_at + len(VALID_IDENTITIES_MARKER) :]


def embedded_teams(name):
    return [match.group(1) for match in PAREN_TEAM_RE.finditer(name)]


def developer_id_names(security_output):
    names = []
    for match in QUOTED_DEVELOPER_ID_RE.finditer(identity_listing(security_output)):
        name = match.group(1).strip()
        if name not in names:
            names.append(name)
    return names


def choose_developer_id_identity(security_output, team):
    """Pick the Developer ID Application identity codesign should use.

    Prefer a name that contains DEVELOPMENT_TEAM. One Developer ID
    Application identity is still used when its common name has no team
    id, or shows a different team. Cloud often displays that certificate
    as "Developer ID Application: <person>".
    """
    names = developer_id_names(security_output)
    wanted = team.upper()
    for name in names:
        if any(item.upper() == wanted for item in embedded_teams(name)):
            return name
    if len(names) == 1:
        return names[0]
    return ""


def safe_listing(text, team):
    if not text or not text.strip():
        return ""
    if "PRIVATE KEY" in text or "BEGIN " in text:
        return "[redacted: unexpected secret material]"
    return redact(text, team)


def is_developer_id(details):
    if "Signature=adhoc" in details or "TeamIdentifier=not set" in details:
        return False
    return "Developer ID Application" in details


def require_identity(team):
    found = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        check=False,
        capture_output=True,
    )
    stdout = found.stdout.decode("utf-8", "replace")
    stderr = found.stderr.decode("utf-8", "replace")
    identity = choose_developer_id_identity(stdout, team)
    if not identity:
        log(
            "no Developer ID Application identity for DEVELOPMENT_TEAM "
            "(value not logged). The Release workflow's Notarize post-action "
            "installs that certificate. See docs/release.md."
        )
        log("security find-identity -v -p codesigning:")
        listing = safe_listing(stdout, team)
        if not listing.strip():
            listing = safe_listing(stderr, team)
        if listing.strip():
            print(listing.rstrip(), file=sys.stderr)
        else:
            log("(no output)")
        raise SystemExit(3)
    if not any(item.upper() == team.upper() for item in embedded_teams(identity)):
        log(
            "using the only Developer ID Application identity; "
            "its name does not contain DEVELOPMENT_TEAM (values not logged)."
        )
    return identity


def copy_app(source, dest):
    if os.path.exists(dest):
        shutil.rmtree(dest)
    parent = os.path.dirname(dest)
    if parent:
        os.makedirs(parent, exist_ok=True)
    # ditto keeps bundle metadata. shutil is the fallback where ditto is absent.
    if shutil.which("ditto"):
        completed = subprocess.run(["ditto", source, dest], check=False, capture_output=True)
        if completed.returncode != 0:
            log("ditto failed to copy the app.")
            raise SystemExit(1)
        return
    shutil.copytree(source, dest, symlinks=True)


def sign_copy(source, dest, team, identity):
    copy_app(source, dest)

    entitlements = None
    try:
        ent_code, ent_stdout, _ent_err = run_codesign(
            ["codesign", "-d", "--entitlements", ":-", dest]
        )
        if ent_code == 0 and ("<plist" in ent_stdout or "bplist" in ent_stdout):
            descriptor, entitlements = tempfile.mkstemp(prefix="eloquent-entitlements-")
            payload = ent_stdout.encode("utf-8")
            written = 0
            while written < len(payload):
                written += os.write(descriptor, payload[written:])
            os.close(descriptor)

        command = [
            "codesign",
            "--force",
            "--sign",
            identity,
            "--options",
            "runtime",
            "--timestamp",
        ]
        if entitlements:
            command.extend(["--entitlements", entitlements])
        command.append(dest)
        code, _stdout, stderr = run_codesign(command)
    finally:
        if entitlements:
            os.unlink(entitlements)
    if code != 0:
        log("codesign Developer ID Application failed.")
        detail = redact(stderr.strip(), team)
        if detail:
            print(detail, file=sys.stderr)
        raise SystemExit(3)

    verify_code, _verify_out, verify_err = run_codesign(["codesign", "-dv", dest])
    if verify_code != 0 or not is_developer_id(verify_err):
        log("codesign left the app without a Developer ID signature.")
        raise SystemExit(4)
    log("signed the app with Developer ID Application (identity not logged).")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--dest", required=True)
    args = parser.parse_args()

    team = (os.environ.get("DEVELOPMENT_TEAM") or "").strip()
    if not TEAM_RE.fullmatch(team):
        log(
            "DEVELOPMENT_TEAM must be a 10-character team id (value not logged). "
            "ci_post uses it to select the Developer ID Application identity."
        )
        raise SystemExit(2)

    if not os.path.isdir(os.path.join(args.source, "Contents", "MacOS")):
        log(f"source is not an app bundle: {args.source}")
        raise SystemExit(1)
    if shutil.which("codesign") is None or shutil.which("security") is None:
        log("codesign or security is not available; cannot sign Developer ID.")
        raise SystemExit(1)

    sign_copy(args.source, args.dest, team, require_identity(team))


if __name__ == "__main__":
    main()
