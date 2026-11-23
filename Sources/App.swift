import AppKit
import SwiftUI

@main struct PaletteApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var window: NSWindow!
    private var store: PaletteStore!
    private var updater: AppUpdater!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = PaletteStore()
        updater = AppUpdater()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "swatchpalette", accessibilityDescription: "Palette")
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "Palette — your saved colors"
        }
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: QuickView(store: store, updater: updater, openLibrary: { [weak self] in self?.showLibrary() }, checkForUpdates: { [weak self] in self?.checkForUpdates() }))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 610), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Palette"
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("PaletteLibrary")
        window.contentView = NSHostingView(rootView: LibraryView(store: store, updater: updater, checkForUpdates: { [weak self] in self?.checkForUpdates() }))
        window.center()
        setupMenu()
        showLibrary()
    }

    private func setupMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Palette", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        for (title, action) in [
            ("Check for Updates…", #selector(AppUpdater.checkForUpdates(_:))),
            ("Check automatically", #selector(AppUpdater.toggleAutomaticChecks(_:))),
            ("Install updates automatically", #selector(AppUpdater.toggleAutomaticInstallation(_:)))
        ] {
            let item = appMenu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = updater
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Palette", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        NSApp.mainMenu = menu
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { NSApp.activate(ignoringOtherApps: true); popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    func showLibrary() {
        popover.performClose(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func checkForUpdates() {
        popover.performClose(nil)
        updater.checkForUpdates()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showLibrary(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
