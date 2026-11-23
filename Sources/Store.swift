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
    var palettes: [Palette] { Palette.ordered(records) }
    var menuBarPalettes: [Palette] { palettes.filter(\.showsInMenuBar) }

    init(fileURL: URL? = nil, enableCloud: Bool = true) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Palette", isDirectory: true).appendingPathComponent("palettes.json")
        var code: SecStaticCode?
        var info: CFDictionary?
        SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code)
        if let code { SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) }
        let entitlements = (info as? [String: Any])?[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        cloudEnabled = enableCloud && (entitlements?["com.apple.developer.ubiquity-kvstore-identifier"] as? String)?.contains("$(") == false
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                records = try Palette.validated(JSONDecoder().decode([Palette].self, from: Data(contentsOf: self.fileURL)))
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
        var palette = id.flatMap { id in records.first { $0.id == id && !$0.deleted } }
            ?? Palette(name: name, colors: colors, sortOrder: (palettes.map(\.effectiveOrder).max() ?? -1) + 1)
        // Editing a palette must not change its position or menu bar preference.
        palette.sortOrder = palette.effectiveOrder
        palette.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        palette.colors = colors
        palette.updatedAt = Date()
        do { _ = try Palette.validated([palette]) } catch { self.error = error.localizedDescription; return nil }
        var next = records.filter { $0.id != palette.id }
        next.append(palette)
        guard persist(next) else { return nil }
        publishCloud()
        return palette.id
    }

    func setMenuBarVisibility(_ visible: Bool, for id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id && !$0.deleted }),
              records[index].showsInMenuBar != visible else { return }
        var next = records
        next[index].sortOrder = next[index].effectiveOrder
        next[index].showsInMenuBar = visible
        next[index].updatedAt = Date()
        if persist(next) { publishCloud() }
    }

    func move(from offsets: IndexSet, to destination: Int) {
        var ordered = palettes
        guard !offsets.isEmpty, offsets.allSatisfy({ ordered.indices.contains($0) }),
              (0...ordered.count).contains(destination) else { return }
        let moving = offsets.map { ordered[$0] }
        for index in offsets.reversed() { ordered.remove(at: index) }
        let insertion = destination - offsets.filter { $0 < destination }.count
        ordered.insert(contentsOf: moving, at: insertion)
        guard ordered.map(\.id) != palettes.map(\.id) else { return }
        let positions = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, Double($0.offset)) })
        let now = Date()
        let next = records.map { record -> Palette in
            guard let position = positions[record.id], record.sortOrder != position else { return record }
            var copy = record
            copy.sortOrder = position
            copy.updatedAt = now
            return copy
        }
        if persist(next) { publishCloud() }
    }

    func move(_ id: UUID, by offset: Int) {
        guard let index = palettes.firstIndex(where: { $0.id == id }),
              palettes.indices.contains(index + offset) else { return }
        move(from: IndexSet(integer: index), to: index + offset + (offset > 0 ? 1 : 0))
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
            for index in imported.indices {
                imported[index].sortOrder = imported[index].effectiveOrder
                imported[index].updatedAt = Date()
                imported[index].deleted = false
            }
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
