import AppKit
import SwiftUI
import Security
import UniformTypeIdentifiers

@MainActor final class PaletteStore: ObservableObject {
    @Published private(set) var records: [Palette] = []
    @Published var error: String?
    @Published private(set) var syncStatus = "Saved on this Mac"
    let cloudEnabled: Bool
    private let fileURL: URL
    private var observer: NSObjectProtocol?
    private var writable = true
    private let prefix = "palette."
    var palettes: [Palette] { records.filter { !$0.deleted }.sorted { $0.updatedAt > $1.updatedAt } }

    init() {
        fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Palette", isDirectory: true).appendingPathComponent("palettes.json")
        var code: SecStaticCode?
        var info: CFDictionary?
        SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code)
        if let code { SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) }
        let entitlements = (info as? [String: Any])?[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        cloudEnabled = (entitlements?["com.apple.developer.ubiquity-kvstore-identifier"] as? String)?.contains("$(") == false
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                records = try Palette.validated(JSONDecoder().decode([Palette].self, from: Data(contentsOf: fileURL)))
            }
        } catch {
            writable = false
            self.error = "Could not read your saved palettes. The original file has been preserved. \(error.localizedDescription)"
        }
        if cloudEnabled {
            syncStatus = "iCloud enabled"
            observer = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil, queue: .main) { [weak self] notification in
                let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
                Task { @MainActor in
                    guard let self else { return }
                    if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
                        self.syncStatus = "iCloud storage limit reached"
                        self.error = PaletteError.cloudFull.localizedDescription
                    } else { self.mergeCloud() }
                }
            }
            NSUbiquitousKeyValueStore.default.synchronize()
            mergeCloud()
        }
    }

    func save(name: String, colors: [String], id: UUID? = nil) -> UUID? {
        let palette = Palette(id: id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), colors: colors)
        do { _ = try Palette.validated([palette]) } catch { self.error = error.localizedDescription; return nil }
        var next = records.filter { $0.id != palette.id }
        next.append(palette)
        guard persist(next) else { return nil }
        publishCloud()
        return palette.id
    }

    func delete(_ palette: Palette) {
        var tombstone = palette
        tombstone.deleted = true
        tombstone.updatedAt = Date()
        if persist(records.filter { $0.id != palette.id } + [tombstone]) { publishCloud() }
    }

    @discardableResult private func persist(_ next: [Palette]) -> Bool {
        guard writable else { error = "Your saved file could not be read. Export your current palettes, then restore the file in Application Support/Palette before restarting."; return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: fileURL, options: .atomic)
            records = next
            return true
        } catch { self.error = "Could not save palettes: \(error.localizedDescription)"; return false }
    }

    private func mergeCloud() {
        let remote = NSUbiquitousKeyValueStore.default.dictionaryRepresentation.filter { $0.key.hasPrefix(prefix) }.values.compactMap { value -> Palette? in
            guard let data = value as? Data, let item = try? JSONDecoder().decode(Palette.self, from: data),
                  let valid = try? Palette.validated([item]) else { return nil }
            return valid.first
        }
        if persist(Palette.merged(records, remote)) { publishCloud() }
    }

    private func publishCloud() {
        guard cloudEnabled else { return }
        let cloud = NSUbiquitousKeyValueStore.default
        let encoded = records.compactMap { item -> (String, Data)? in
            guard let data = try? JSONEncoder().encode(item) else { return nil }
            return (prefix + item.id.uuidString, data)
        }
        guard encoded.count < 1000, encoded.reduce(0, { $0 + $1.1.count + $1.0.utf8.count }) < 900_000 else {
            syncStatus = "Saved locally · iCloud limit reached"
            error = PaletteError.cloudFull.localizedDescription
            return
        }
        for (key, data) in encoded where cloud.data(forKey: key) != data { cloud.set(data, forKey: key) }
        syncStatus = "iCloud enabled"
    }

    func exportPalettes() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Palettes.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(palettes).write(to: url, options: .atomic)
        } catch { self.error = error.localizedDescription }
    }

    func importPalettes() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 5_000_000 else { throw PaletteError.invalidFile }
            var imported = try Palette.validated(JSONDecoder().decode([Palette].self, from: data))
            for index in imported.indices { imported[index].updatedAt = Date(); imported[index].deleted = false }
            if persist(Palette.merged(records, imported)) { publishCloud() }
        } catch { self.error = error.localizedDescription }
    }
}

func copyText(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

extension Color {
    init(hex: String) {
        let number = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
        self.init(.sRGB, red: Double((number >> 16) & 255) / 255, green: Double((number >> 8) & 255) / 255, blue: Double(number & 255) / 255, opacity: 1)
    }
}
