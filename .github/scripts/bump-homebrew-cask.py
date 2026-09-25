#!/usr/bin/env python3
"""Set version and sha256 on one line each in a Homebrew cask.

Leaves every other line alone (url, livecheck, zap, and the rest).

Usage:
  bump-homebrew-cask.py <cask-path> <version> <sha256>
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

VERSION_LINE = re.compile(r'^([ \t]*version ")([^"]+)(")[ \t]*$', re.MULTILINE)
SHA_LINE = re.compile(
    r'^([ \t]*sha256 ")([0-9a-fA-F]{64})(")[ \t]*$',
    re.MULTILINE,
)
VERSION_VALUE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.]+)?$")
SHA_VALUE = re.compile(r"^[0-9a-f]{64}$")


def main() -> None:
    if len(sys.argv) != 4:
        print(
            "usage: bump-homebrew-cask.py <cask-path> <version> <sha256>",
            file=sys.stderr,
        )
        sys.exit(2)

    path = Path(sys.argv[1])
    version = sys.argv[2]
    sha = sys.argv[3]

    if VERSION_VALUE.fullmatch(version) is None:
        print(f"::error::version {version!r} is not a SemVer string", file=sys.stderr)
        sys.exit(1)
    if SHA_VALUE.fullmatch(sha) is None:
        print("::error::sha256 must be 64 lowercase hex characters", file=sys.stderr)
        sys.exit(1)
    if not path.is_file():
        print(f"::error::cask file not found: {path}", file=sys.stderr)
        sys.exit(1)

    text = path.read_text()
    version_count = len(VERSION_LINE.findall(text))
    sha_count = len(SHA_LINE.findall(text))
    if version_count != 1:
        print(
            f"::error::expected exactly one version line in {path}, found {version_count}",
            file=sys.stderr,
        )
        sys.exit(1)
    if sha_count != 1:
        print(
            f"::error::expected exactly one sha256 line in {path}, found {sha_count}",
            file=sys.stderr,
        )
        sys.exit(1)

    text = VERSION_LINE.sub(rf"\g<1>{version}\g<3>", text, count=1)
    text = SHA_LINE.sub(rf"\g<1>{sha}\g<3>", text, count=1)
    path.write_text(text)


if __name__ == "__main__":
    main()
