# Palette

A small native macOS palette library, built with SwiftUI and AppKit. Requires macOS 14 or later. No third-party dependencies.

## Use

Open Palette.app. Create a palette with a name and 1–24 colors. Paste 3- or 6-digit HEX codes (separated by commas, spaces, or newlines), or use the system color picker and click Add color. Click any swatch to copy its HEX code. The menu bar swatch icon gives quick access to all saved palettes. Closing the library keeps the menu bar app running; Quit exits it.

Search by name or HEX, edit or delete palettes, and import/export JSON using the menu at the bottom of the sidebar. Palettes are saved atomically in ~/Library/Application Support/Palette/palettes.json. Export makes a portable backup. The app follows the system light/dark appearance.

## Build locally

With Apple's Command Line Tools installed:

```sh
./build.sh
open build/Palette.app
```

The script builds for the current Mac's architecture and ad-hoc signs the app for local use. Build output stays out of Git.

Run the model tests:

```sh
./Tests/run.sh
```

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

No third-party dependencies, analytics, or network services beyond optional Apple iCloud sync.
