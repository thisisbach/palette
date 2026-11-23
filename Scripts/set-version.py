#!/usr/bin/env python3
"""Derive monotonically comparable Sparkle bundle versions from stable release tags."""
import plistlib
import re
import sys
from pathlib import Path


def release_version(tag):
    if not re.fullmatch(r"v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*))?", tag):
        raise ValueError("Use a stable release tag such as v1.2 or v1.2.1")
    return tag.removeprefix("v")


if __name__ == "__main__":
    version = release_version(sys.argv[1])
    path = Path(sys.argv[2])
    info = plistlib.loads(path.read_bytes())
    info["CFBundleShortVersionString"] = version
    info["CFBundleVersion"] = version
    path.write_bytes(plistlib.dumps(info, sort_keys=False))
