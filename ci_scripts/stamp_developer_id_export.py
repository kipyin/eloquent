#!/usr/bin/env python3
"""Stamp an ad-hoc Xcode Cloud archive so Developer ID exportArchive can see a team.

Xcode Cloud archives with CODE_SIGN_IDENTITY=- and AD_HOC_CODE_SIGNING_ALLOWED=YES.
That command line overrides Release-Signing.xcconfig, the product is "Sign to Run
Locally", and the archive Info.plist has no ApplicationProperties.Team.
exportArchive then fails with "No Team Found in Archive".
"""

import argparse
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

TEAM_RE = re.compile(r"^[A-Za-z0-9]{10}$")
IDENTITY_RE = re.compile(
    r'"(Developer ID Application:[^"]*\(([A-Za-z0-9]{10})\))"'
)


def log(message):
    print(f"ci_post_xcodebuild: {message}", file=sys.stderr)


def load_plist(path):
    with open(path, "rb") as handle:
        return plistlib.load(handle)


def dump_plist(path, payload):
    with open(path, "wb") as handle:
        plistlib.dump(payload, handle, fmt=plistlib.FMT_XML, sort_keys=False)


def chosen_team(existing, env_team):
    """Return (team, status). status is kept, mismatch, stamped, or missing."""
    archive_team = (existing or "").strip()
    provided = (env_team or "").strip()
    if archive_team:
        if provided and provided != archive_team:
            return archive_team, "mismatch"
        return archive_team, "kept"
    if not provided:
        return "", "missing"
    if not TEAM_RE.fullmatch(provided):
        return "", "invalid"
    return provided, "stamped"


def explain(status):
    if status == "stamped":
        log(
            "archive has no Team (ad-hoc Sign to Run Locally from CODE_SIGN_IDENTITY=-). "
            'Stamped DEVELOPMENT_TEAM into the archive and export options (value not logged) '
            'so exportArchive does not fail with "No Team Found in Archive".'
        )
        return
    if status == "kept":
        log("archive already has a Team. Export options teamID uses it (value not logged).")
        return
    if status == "mismatch":
        log(
            "DEVELOPMENT_TEAM does not match the Team already in the archive. "
            "Export uses the archive Team (values not logged)."
        )
        return
    if status == "invalid":
        log(
            "DEVELOPMENT_TEAM must be a 10-character team id (value not logged). "
            'exportArchive would fail with "No Team Found in Archive".'
        )
        return
    log(
        "archive has no Team. Xcode Cloud archived with CODE_SIGN_IDENTITY=- and "
        "AD_HOC_CODE_SIGNING_ALLOWED=YES (Sign to Run Locally). exportArchive then fails "
        'with "No Team Found in Archive". Set DEVELOPMENT_TEAM on the Release workflow. '
        "See docs/release.md."
    )


def developer_id_identity(security_output, team):
    for match in IDENTITY_RE.finditer(security_output):
        if match.group(2) == team:
            return match.group(1)
    return ""


def codesign_text(app, *args):
    completed = subprocess.run(
        ["codesign", *args, app],
        check=False,
        capture_output=True,
    )
    stdout = completed.stdout.decode("utf-8", "replace")
    stderr = completed.stderr.decode("utf-8", "replace")
    return completed.returncode, stdout, stderr


def redact(text, team):
    if not text or not team:
        return text
    return text.replace(team, "[team]")


def is_adhoc(stderr, returncode):
    if "Signature=adhoc" in stderr or "TeamIdentifier=not set" in stderr:
        return True
    if re.search(r"TeamIdentifier=[A-Za-z0-9]{10}", stderr):
        return False
    return returncode != 0


def resign_adhoc_app(app, team):
    """Re-sign an ad-hoc archived app with Developer ID when that identity exists.

    Returns the generic SigningIdentity label after a successful re-sign, else "".
    A missing tool, a missing identity, or a codesign failure leaves exportArchive to sign.
    """
    if not os.path.isdir(app):
        log("archived app bundle is missing; exportArchive must produce the Developer ID app.")
        return ""
    if shutil.which("codesign") is None:
        log("codesign not available; leaving the ad-hoc app for exportArchive to sign.")
        return ""

    returncode, _stdout, details = codesign_text(app, "-dv")
    if not is_adhoc(details, returncode):
        log("archived app already has a team signature.")
        return ""

    if shutil.which("security") is None:
        log("security not available; cannot re-sign the ad-hoc archive. exportArchive must sign.")
        return ""

    found = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        check=False,
        capture_output=True,
    )
    listing = found.stdout.decode("utf-8", "replace")
    identity = developer_id_identity(listing, team)
    if not identity:
        log(
            "no Developer ID Application identity for this team. exportArchive must sign. "
            "Add the Notarize post-action so Xcode Cloud installs that certificate. "
            "See docs/release.md."
        )
        return ""

    entitlements = None
    ent_code, ent_stdout, _ent_err = codesign_text(app, "-d", "--entitlements", ":-")
    if ent_code == 0 and ("<plist" in ent_stdout or "bplist" in ent_stdout):
        descriptor, entitlements = tempfile.mkstemp(prefix="eloquent-entitlements-")
        os.write(descriptor, ent_stdout.encode("utf-8"))
        os.close(descriptor)

    command = ["codesign", "--force", "--sign", identity, "--options", "runtime", "--timestamp"]
    if entitlements:
        command.extend(["--entitlements", entitlements])
    command.append(app)
    try:
        completed = subprocess.run(command, check=False, capture_output=True)
    finally:
        if entitlements:
            os.unlink(entitlements)
    if completed.returncode != 0:
        detail = redact(completed.stderr.decode("utf-8", "replace").strip(), team)
        log("re-sign with Developer ID Application failed; exportArchive will sign.")
        if detail:
            print(detail, file=sys.stderr)
        return ""
    log("re-signed the archived app with Developer ID Application (identity not logged).")
    return "Developer ID Application"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True)
    parser.add_argument("--export-template", required=True)
    parser.add_argument("--export-out", required=True)
    parser.add_argument("--product", default=os.environ.get("CI_PRODUCT", "Eloquent"))
    parser.add_argument("--no-resign", action="store_true")
    args = parser.parse_args()

    info_path = os.path.join(args.archive, "Info.plist")
    if not os.path.isfile(info_path):
        log(f"archive Info.plist is missing: {info_path}")
        raise SystemExit(1)
    if not os.path.isfile(args.export_template):
        log(f"export options template is missing: {args.export_template}")
        raise SystemExit(1)

    archive = load_plist(info_path)
    props = archive.setdefault("ApplicationProperties", {})
    team, status = chosen_team(props.get("Team"), os.environ.get("DEVELOPMENT_TEAM"))
    explain(status)
    if not team:
        raise SystemExit(2)

    props["Team"] = team
    signed = ""
    if not args.no_resign:
        app = os.path.join(args.archive, "Products", "Applications", f"{args.product}.app")
        signed = resign_adhoc_app(app, team)
    if signed:
        props["SigningIdentity"] = signed
    dump_plist(info_path, archive)

    export = load_plist(args.export_template)
    export["teamID"] = team
    export["method"] = "developer-id"
    dump_plist(args.export_out, export)


if __name__ == "__main__":
    main()
