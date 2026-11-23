import Foundation

struct Palette: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var colors: [String]
    var updatedAt: Date = Date()
    var deleted: Bool = false

    static func hex(_ input: String) -> String? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard [3, 6].contains(value.count), value.allSatisfy({ "0123456789ABCDEF".contains($0) }) else { return nil }
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        return "#" + value
    }

    static func validated(_ items: [Palette]) throws -> [Palette] {
        guard Set(items.map(\.id)).count == items.count else { throw PaletteError.invalidFile }
        return try items.map { item in
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.name.count <= 100, (1...24).contains(item.colors.count),
                  item.colors.allSatisfy({ hex($0) != nil }) else { throw PaletteError.invalidFile }
            var copy = item
            copy.colors = item.colors.compactMap(hex)
            return copy
        }
    }

    static func merged(_ local: [Palette], _ remote: [Palette]) -> [Palette] {
        var records = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for item in remote {
            if let existing = records[item.id], existing.updatedAt >= item.updatedAt { continue }
            records[item.id] = item
        }
        return records.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

enum PaletteError: LocalizedError {
    case invalidFile, cloudFull
    var errorDescription: String? {
        switch self {
        case .invalidFile: return "Choose a Palette JSON export with unique palettes, names, and 1–24 valid HEX colors per palette."
        case .cloudFull: return "The iCloud palette limit has been reached. Your palettes are saved on this Mac; export a backup before removing older palettes."
        }
    }
}
