#!/usr/bin/env python3
"""Sign a stable release and advance its Sparkle feed after assets are uploaded."""
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import format_datetime

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE)
ROOT = Path(__file__).resolve().parent.parent


def run(*args, input=None):
    return subprocess.run(args, input=input, capture_output=True, check=True).stdout


def version_tuple(version):
    spec = importlib.util.spec_from_file_location("versions", ROOT / "Scripts/set-version.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    parsed = module.release_version(version)
    return tuple((list(map(int, parsed.split("."))) + [0, 0])[:3])


def make_feed(tag, info, archive, signature):
    version = info["CFBundleShortVersionString"]
    page = f"https://github.com/thisisbach/palette/releases/tag/{tag}"
    rss = ET.Element("rss", version="2.0")
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Palette updates"
    ET.SubElement(channel, "link").text = "https://github.com/thisisbach/palette"
    ET.SubElement(channel, "description").text = "Stable Palette releases for macOS."
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"Palette {version}"
    ET.SubElement(item, "link").text = page
    ET.SubElement(item, "pubDate").text = format_datetime(datetime.now(timezone.utc))
    ET.SubElement(item, f"{{{SPARKLE}}}version").text = info["CFBundleVersion"]
    ET.SubElement(item, f"{{{SPARKLE}}}shortVersionString").text = version
    ET.SubElement(item, f"{{{SPARKLE}}}minimumSystemVersion").text = info["LSMinimumSystemVersion"]
    ET.SubElement(item, "description").text = f"Palette {version} is available. See the release page for changes."
    ET.SubElement(item, "enclosure", {
        "url": f"https://github.com/thisisbach/palette/releases/download/{tag}/{archive.name}",
        "length": str(archive.stat().st_size),
        "type": "application/octet-stream",
        f"{{{SPARKLE}}}edSignature": signature,
    })
    ET.indent(rss)
    return ET.tostring(rss, encoding="utf-8", xml_declaration=True)


def main(tag):
    os.chdir(ROOT)
    version_tuple(tag)  # Reject malformed tags before constructing paths or URLs.
    version = tag.removeprefix("v")
    repo = "thisisbach/palette"
    metadata = json.loads(run("gh", "release", "view", tag, "--repo", repo,
                              "--json", "isDraft,isPrerelease,tagName"))
    if metadata["isDraft"] or metadata["isPrerelease"]:
        raise ValueError("Only published stable releases can update the stable feed")

    # Do not overwrite an existing release or roll the feed back on a delayed job.
    parent = None
    remote = subprocess.run(["git", "ls-remote", "--exit-code", "origin", "refs/heads/updates"], capture_output=True)
    if remote.returncode == 0:
        run("git", "fetch", "origin", "refs/heads/updates")
        parent = run("git", "rev-parse", "FETCH_HEAD").decode().strip()
        previous = ET.fromstring(run("git", "show", f"{parent}:appcast.xml"))
        latest = previous.findtext(f"channel/item/{{{SPARKLE}}}shortVersionString")
        if latest is None:
            raise ValueError("Existing feed does not identify its latest version")
        if version_tuple(version) <= version_tuple(latest):
            print(f"Feed already contains {latest}; not replacing it with {version}.")
            return
    elif remote.returncode != 2:
        raise RuntimeError("Could not read the existing update branch")

    dist = ROOT / "dist"
    archive = dist / f"Palette-{version}-macOS-universal.zip"
    info = plistlib.loads((dist / "Palette.app/Contents/Info.plist").read_bytes())
    if info["CFBundleVersion"] != version or info["CFBundleShortVersionString"] != version:
        raise ValueError("Release tag and packaged application versions must match")
    if info["CFBundleIdentifier"] != "app.palette.mac" or not info.get("SURequireSignedFeed"):
        raise ValueError("Packaged app is missing the signed Palette updater configuration")

    private_key = os.environ.get("SPARKLE_PRIVATE_KEY", "").strip().encode()
    if not private_key:
        raise ValueError("Configure the SPARKLE_PRIVATE_KEY GitHub Actions secret before publishing")
    # Check the private key matches the public key actually embedded in the app.
    public = run("swift", "-module-cache-path", str(Path(os.environ.get("TMPDIR", "/tmp")) / "palette-module-cache"),
                 "Scripts/key-public.swift", input=private_key).decode().strip()
    if public != info["SUPublicEDKey"]:
        raise ValueError("Signing key does not match the app's embedded public key")

    def sign(*args):
        result = subprocess.run([str(ROOT / "Vendor/Sparkle/bin/sign_update"), "--ed-key-file", "-", *map(str, args)],
                                input=private_key, capture_output=True)
        if result.returncode:
            # Never echo signing-tool output that could include invalid key material.
            raise RuntimeError("Sparkle signing/verification failed")
        return result.stdout.decode().strip()

    signature = sign("-p", archive)
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError("Invalid Ed25519 signature")
    sign("--verify", archive, signature)
    feed = dist / "appcast.xml"
    feed.write_bytes(make_feed(tag, info, archive, signature))
    sign(feed)
    sign("--verify", feed)
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (dist / "SHA256SUMS.txt").write_text(f"{checksum}  {archive.name}\n")
    run("gh", "release", "upload", tag, str(archive), str(dist / "SHA256SUMS.txt"), str(feed),
        "--repo", repo, "--clobber")

    # Publish a feed-only branch, preserving its history and rejecting concurrent changes.
    blob = run("git", "hash-object", "-w", str(feed)).decode().strip()
    tree = run("git", "mktree", input=f"100644 blob {blob}\tappcast.xml\n".encode()).decode().strip()
    parents = ["-p", parent] if parent else []
    commit = run("git", "-c", "user.name=github-actions[bot]", "-c",
                 "user.email=41898282+github-actions[bot]@users.noreply.github.com",
                 "commit-tree", tree, *parents, "-m", f"Publish signed Palette {version} update feed").decode().strip()
    run("git", "push", "origin", f"{commit}:refs/heads/updates")
    print(f"Published signed Palette {version} update: https://github.com/{repo}/releases/tag/{tag}")


if __name__ == "__main__":
    main(sys.argv[1])
