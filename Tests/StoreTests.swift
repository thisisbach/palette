import Foundation

@main struct StoreTests {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("palettes.json")

        let old = Palette(name: "Old", colors: ["#123456"], updatedAt: Date(timeIntervalSince1970: 10))
        let recent = Palette(name: "Recent", colors: ["#ABCDEF"], updatedAt: Date(timeIntervalSince1970: 20))
        let newest = Palette(name: "Newest", colors: ["#FFFFFF"], updatedAt: Date(timeIntervalSince1970: 30))
        // Reproduce the 1.0 file format, with neither new field present.
        let encoded = try JSONEncoder().encode([old, newest, recent])
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [[String: Any]]
        for index in legacy.indices {
            legacy[index].removeValue(forKey: "sortOrder")
            legacy[index].removeValue(forKey: "showsInMenuBar")
        }
        try JSONSerialization.data(withJSONObject: legacy).write(to: url)
        let store = PaletteStore(fileURL: url, enableCloud: false)
        precondition(store.error == nil)
        precondition(store.palettes.map(\.name) == ["Newest", "Recent", "Old"])
        precondition(store.menuBarPalettes.count == 3)

        // Preference changes and edits must not move legacy palettes.
        store.setMenuBarVisibility(false, for: recent.id)
        precondition(store.palettes.map(\.name) == ["Newest", "Recent", "Old"])
        precondition(store.menuBarPalettes.map(\.name) == ["Newest", "Old"])
        precondition(store.save(name: "Renamed", colors: ["#112233"], id: recent.id) == recent.id)
        precondition(store.palettes.map(\.name) == ["Newest", "Renamed", "Old"])
        precondition(!store.palettes[1].showsInMenuBar)

        // Move down, up, and to a drag destination at the end.
        store.move(newest.id, by: 1)
        precondition(store.palettes.map(\.name) == ["Renamed", "Newest", "Old"])
        store.move(old.id, by: -1)
        precondition(store.palettes.map(\.name) == ["Renamed", "Old", "Newest"])
        store.move(from: IndexSet(integer: 0), to: 3)
        precondition(store.palettes.map(\.name) == ["Old", "Newest", "Renamed"])
        precondition(store.menuBarPalettes.map(\.name) == ["Old", "Newest"])
        store.move(from: IndexSet([0, 2]), to: 1)
        precondition(store.palettes.map(\.name) == ["Old", "Renamed", "Newest"])

        let snapshot = store.records
        store.move(from: IndexSet(integer: 100), to: 0)
        store.move(old.id, by: -1)
        store.move(from: IndexSet(integer: 0), to: 1)
        precondition(store.records == snapshot)

        // Settings survive relaunch and subsequent editing.
        let reopened = PaletteStore(fileURL: url, enableCloud: false)
        precondition(reopened.records == store.records)
        precondition(reopened.palettes.map(\.name) == ["Old", "Renamed", "Newest"])
        precondition(reopened.menuBarPalettes.map(\.name) == ["Old", "Newest"])
        let newID = reopened.save(name: "New", colors: ["#654321"])!
        precondition(reopened.palettes.last?.id == newID)
        precondition(reopened.palettes.last?.showsInMenuBar == true)
        reopened.setMenuBarVisibility(true, for: recent.id)
        precondition(reopened.menuBarPalettes.count == 4)
        for palette in reopened.palettes { reopened.setMenuBarVisibility(false, for: palette.id) }
        precondition(reopened.menuBarPalettes.isEmpty && reopened.palettes.count == 4)

        // JSON export/import and cloud merging retain both preferences.
        let exported = try JSONEncoder().encode(reopened.palettes)
        let imported = try Palette.validated(JSONDecoder().decode([Palette].self, from: exported))
        precondition(imported == reopened.palettes)
        let merged = Palette.merged(snapshot, reopened.records)
        precondition(Palette.ordered(merged).map(\.name) == reopened.palettes.map(\.name))
        precondition(Palette.ordered(merged).allSatisfy { !$0.showsInMenuBar })
        reopened.delete(reopened.palettes[0])
        precondition(reopened.palettes.count == 3 && reopened.menuBarPalettes.isEmpty)
        precondition(reopened.error == nil)
        print("Passed legacy migration, reordering, menu bar selection, edit preservation, persistence, and sync metadata tests.")
    }
}
