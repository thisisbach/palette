# Palette

A small native macOS palette library, built with SwiftUI and AppKit. Requires macOS 14 or later. Uses [Sparkle](https://sparkle-project.org/) for signed automatic updates.

[Download the latest app release](https://github.com/thisisbach/palette/releases/latest). Unzip the app and drag it into Applications. Release builds support Apple Silicon and Intel, save locally, and are ad-hoc signed without Apple notarization; macOS may require manual approval to open them.

## Use

Open Palette.app. Create a palette with a name and 1–24 colors. Paste 3- or 6-digit HEX codes (separated by commas, spaces, or newlines), or use the system color picker and click Add color. Click any swatch to copy its HEX code. The menu bar swatch icon gives quick access to all saved palettes. Closing the library keeps the menu bar app running; Quit exits it.

Search by name or HEX, edit or delete palettes, and import/export JSON using the menu at the bottom of the sidebar. Palettes are saved atomically in ~/Library/Application Support/Palette/palettes.json. Export makes a portable backup. The app follows the system light/dark appearance.

Drag palettes in the sidebar to set their display order (clear the search first), or select one and use the up/down buttons below the list. The same order is used in the menu bar. Editing a palette keeps its position; new palettes are added at the end.

Check or uncheck the box beside each palette to choose whether it appears in the menu bar. Unchecked palettes remain in your library. Order and visibility are saved across launches, included in JSON exports, and synced by iCloud in developer-signed builds. Palettes saved by version 1.0 retain their previous order and start checked.

## Build locally

With Apple's Command Line Tools installed:

```sh
./build.sh
open build/Palette.app
```

The script downloads a pinned, SHA-256-verified official Sparkle distribution, builds for the current Mac's architecture, embeds its framework, and ad-hoc signs the app for local use. Build output and downloaded dependencies stay out of Git. For a universal build use `PALETTE_ARCHITECTURES="arm64 x86_64" ./build.sh`.

Before opening the Xcode project, run `./Scripts/fetch-sparkle.sh` once to install the same pinned framework into `Vendor/Sparkle`.

Run the model tests:

```sh
./Tests/run.sh
```

The suite also checks persistence, update-feed versions, and rejection of tampered archives, incorrect signing keys, and modified update feeds.

## Automatic updates

Version 1.2 and later check for updates daily and enable automatic download/installation by default. Sparkle installs when the app quits or offers to install and relaunch when necessary. System authorization may be required if the app is in a protected location. The menu bar's gear menu, the library's More menu, and the Palette application menu offer **Check for Updates…**, **Check automatically**, and **Install updates automatically**. Settings are saved on this Mac. Users of version 1.1 or earlier need to install version 1.2 manually once.

Update archives and the update feed are signed with Ed25519. The app verifies the archive before extraction and requires a signed feed from `https://raw.githubusercontent.com/thisisbach/palette/updates/appcast.xml`. Update signing is separate from Apple's Developer ID signing/notarization: releases remain ad-hoc signed and local-only until Apple signing is configured.

### Publishing a new version

1. Push the desired source to GitHub.
2. Create and publish a **stable GitHub release** with a tag such as `v1.3` or `v1.3.1` pointing at that source. The tag must contain this updater workflow (version 1.2 or later).
3. Wait for **Build and publish app updates** in GitHub Actions to succeed. It tests, builds a universal app, sets the bundle version from the release tag, packages it, signs the ZIP and feed, uploads the app/checksum/feed to the release, and advances the `updates` branch. No manual appcast editing is needed.

Drafts and prereleases are excluded. Tags must be increasing numeric versions; a delayed or rerun workflow cannot roll the feed back or replace an already-published version. The workflow can also be run manually with an existing stable release tag. Do not edit the published signed ZIP or appcast; publish a new version instead.

The signing seed is configured as the repository's **SPARKLE_PRIVATE_KEY** GitHub Actions secret. Only its public key is committed in Info.plist. An owner backup is stored in the ignored `.secrets/sparkle-private-key` on the development Mac (when available); retain a secure backup. Never commit that seed, log it, or rotate it casually: existing apps trust its matching public key. Forks must generate their own keys and change the feed/repository URLs before distributing.

The workflow uses contents-write permission solely to upload release assets and publish the feed branch. Signing secrets are provided only to its signing/publishing step.

## Enable iCloud

The command-line build saves locally. iCloud requires a build provisioned and signed with your Apple Developer team and the iCloud key-value storage entitlement.

1. Install full Xcode and open Palette.xcodeproj.
2. Select the Palette target → Signing & Capabilities, choose your Apple Developer team, and set a unique bundle identifier. The same identifier must be used on every Mac.
3. Enable the iCloud capability with **Key-value storage**. The included Palette.entitlements supplies `$(TeamIdentifierPrefix)$(CFBundleIdentifier)`. Let Xcode provision the app with your team's iCloud entitlement.
4. Build and run the signed app on Macs signed into the same Apple Account with iCloud Drive enabled. The footer will read “iCloud enabled” once the entitlement is present. This indicates capability availability, not confirmation of server delivery. Verify changes arrive on a second Mac before relying on sync.

Sync uses Apple's key-value store. Each palette has its own record; the newest timestamp wins when the same palette is edited on two Macs. Deletions retain a timestamped tombstone to prevent older copies from reappearing. Separate palettes merge independently. Keep Mac clocks automatic. Apple's limits are approximately 1 MB and 1,024 keys; this app stops uploading at a conservative 900 KB / 999 records and keeps saving locally. Deleted records count toward that quota. Export backups occasionally.

End-to-end iCloud sync has not been tested because a developer signing identity and a second signed-in Mac were unavailable. The Xcode project was checked for plist syntax; a full Xcode build could not run because only Command Line Tools are installed.

## Project layout

- Sources/App.swift — menu bar item, library window, application lifecycle.
- Sources/Views.swift — library, palette editor, quick-access popover.
- Sources/Models.swift — validation and timestamp conflict merging.
- Sources/Store.swift — local persistence, iCloud, import/export, clipboard.
- Palette.entitlements — signing entitlement for iCloud key-value storage.
- Sources/Updater.swift — Sparkle update controller and update settings.
- Scripts/prepare-release.sh, Scripts/publish-release.py — universal packaging and signed feed publishing.
- .github/workflows/release.yml — automatic stable-release publishing.

No analytics. Network access is used for GitHub/Sparkle update checks and optional Apple iCloud sync. Sparkle's license and dependency notices are included in `Resources/Sparkle-LICENSE.txt` and in the built app.
