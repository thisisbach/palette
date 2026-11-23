import AppKit
import Combine
import Sparkle
import SwiftUI

@MainActor final class AppUpdater: NSObject, ObservableObject, NSMenuItemValidation {
    let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = true
    @Published private(set) var automaticInstallation = true

    override init() {
        super.init()
        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates).receive(on: RunLoop.main).assign(to: &$canCheck)
        updater.publisher(for: \.automaticallyChecksForUpdates).receive(on: RunLoop.main).assign(to: &$automaticChecks)
        updater.publisher(for: \.automaticallyDownloadsUpdates).receive(on: RunLoop.main).assign(to: &$automaticInstallation)
        controller.startUpdater()
    }

    @objc func checkForUpdates(_ sender: Any? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(sender)
    }

    @objc func toggleAutomaticChecks(_ sender: Any?) {
        controller.updater.automaticallyChecksForUpdates.toggle()
    }

    @objc func toggleAutomaticInstallation(_ sender: Any?) {
        controller.updater.automaticallyDownloadsUpdates.toggle()
    }

    func setAutomaticChecks(_ enabled: Bool) { controller.updater.automaticallyChecksForUpdates = enabled }
    func setAutomaticInstallation(_ enabled: Bool) { controller.updater.automaticallyDownloadsUpdates = enabled }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(checkForUpdates(_:)): return controller.updater.canCheckForUpdates
        case #selector(toggleAutomaticChecks(_:)):
            menuItem.state = controller.updater.automaticallyChecksForUpdates ? .on : .off
            return true
        case #selector(toggleAutomaticInstallation(_:)):
            menuItem.state = controller.updater.automaticallyDownloadsUpdates ? .on : .off
            return controller.updater.automaticallyChecksForUpdates
        default: return true
        }
    }
}

struct UpdateCommands: View {
    @ObservedObject var updater: AppUpdater
    let check: () -> Void
    var body: some View {
        Button("Check for Updates…", action: check).disabled(!updater.canCheck)
        Toggle("Check automatically", isOn: Binding(get: { updater.automaticChecks }, set: updater.setAutomaticChecks))
        Toggle("Install updates automatically", isOn: Binding(get: { updater.automaticInstallation }, set: updater.setAutomaticInstallation))
            .disabled(!updater.automaticChecks)
    }
}
