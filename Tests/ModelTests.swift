import Foundation

@main struct ModelTests {
    static func main() throws {
        precondition(Palette.hex(" #abc ") == "#AABBCC")
        precondition(Palette.hex("abcdef") == "#ABCDEF")
        for invalid in ["", "#12", "#12345G", "#12345678", "ééé", "##123"] { precondition(Palette.hex(invalid) == nil) }
        let id = UUID()
        let original = Palette(id: id, name: "Ocean", colors: ["#123456"], updatedAt: Date(timeIntervalSince1970: 10))
        var changed = original
        changed.name = "Sea"
        changed.updatedAt = Date(timeIntervalSince1970: 20)
        precondition(Palette.merged([original], [changed]) == [changed])
        precondition(Palette.merged([changed], [original]) == [changed])
        var deleted = changed
        deleted.deleted = true
        deleted.updatedAt = Date(timeIntervalSince1970: 30)
        precondition(Palette.merged([changed], [deleted]).first?.deleted == true)
        precondition(Palette.merged([deleted], [changed]).first?.deleted == true)
        let other = Palette(name: "Other", colors: ["#fff"])
        precondition(Palette.merged([original], [other]).count == 2)
        let validated = try Palette.validated([other])
        precondition(validated[0].colors == ["#FFFFFF"])
        let encoded = try JSONEncoder().encode([original, other])
        let decoded = try JSONDecoder().decode([Palette].self, from: encoded)
        precondition(decoded == [original, other])
        for items in [[original, original], [Palette(name: "", colors: ["#fff"])], [Palette(name: "Empty", colors: [])], [Palette(name: "Bad", colors: ["#GGG"])]] {
            do { _ = try Palette.validated(items); fatalError("Invalid import accepted") } catch PaletteError.invalidFile {}
        }
        print("Passed HEX validation, import validation, JSON round trip, conflict merge, and deletion tests.")
    }
}
