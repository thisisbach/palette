import Foundation

struct Palette: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var colors: [String]
    var updatedAt: Date = Date()
    var deleted: Bool = false
    var sortOrder: Double? = nil
    var showsInMenuBar: Bool = true

    // Older palettes retain their previous newest-first order until explicitly moved.
    var effectiveOrder: Double { sortOrder ?? -updatedAt.timeIntervalSince1970 }

    enum CodingKeys: String, CodingKey {
        case id, name, colors, updatedAt, deleted, sortOrder, showsInMenuBar
    }

    init(id: UUID = UUID(), name: String, colors: [String], updatedAt: Date = Date(),
         deleted: Bool = false, sortOrder: Double? = nil, showsInMenuBar: Bool = true) {
        self.id = id; self.name = name; self.colors = colors; self.updatedAt = updatedAt
        self.deleted = deleted; self.sortOrder = sortOrder; self.showsInMenuBar = showsInMenuBar
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        colors = try values.decode([String].self, forKey: .colors)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        deleted = try values.decode(Bool.self, forKey: .deleted)
        sortOrder = try values.decodeIfPresent(Double.self, forKey: .sortOrder)
        showsInMenuBar = try values.decodeIfPresent(Bool.self, forKey: .showsInMenuBar) ?? true
    }

    static func ordered(_ records: [Palette]) -> [Palette] {
        records.filter { !$0.deleted }.sorted {
            if $0.effectiveOrder != $1.effectiveOrder { return $0.effectiveOrder < $1.effectiveOrder }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

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
                  item.colors.allSatisfy({ hex($0) != nil }),
                  item.sortOrder?.isFinite ?? true else { throw PaletteError.invalidFile }
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
