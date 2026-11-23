import SwiftUI
import AppKit

struct LibraryView: View {
    @ObservedObject var store: PaletteStore
    @State private var search = ""
    @State private var selection: UUID?
    @State private var editing: Palette?
    @State private var creating = false
    @State private var deleting: Palette?
    @State private var copied = false
    private var filtered: [Palette] { store.palettes.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.colors.contains { $0.localizedCaseInsensitiveContains(search) } } }
    private var selected: Palette? { store.palettes.first { $0.id == selection } }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Label("Palettes", systemImage: "swatchpalette").font(.title3.weight(.semibold))
                    Spacer()
                    Button { creating = true } label: { Image(systemName: "plus") }.buttonStyle(.borderless).help("New palette")
                }.padding(16)
                TextField("Search names or HEX", text: $search).textFieldStyle(.roundedBorder).padding(.horizontal, 12).padding(.bottom, 12)
                Text("Drag to reorder · Check for menu bar")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.bottom, 6)
                List(selection: $selection) {
                    ForEach(filtered) { palette in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(palette.name).font(.headline).lineLimit(1)
                                Spacer()
                                Toggle("Show \(palette.name) in menu bar", isOn: Binding(
                                    get: { palette.showsInMenuBar },
                                    set: { store.setMenuBarVisibility($0, for: palette.id) }
                                )).toggleStyle(.checkbox).labelsHidden()
                                    .help("Show in menu bar")
                            }
                            HStack(spacing: 3) {
                                ForEach(Array(palette.colors.prefix(8).enumerated()), id: \.offset) { _, hex in
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: hex)).frame(height: 17)
                                }
                            }
                        }.padding(.vertical, 7).tag(palette.id)
                        .moveDisabled(!search.isEmpty)
                        .contextMenu {
                            Button("Edit palette") { editing = palette }
                            Button("Copy HEX codes") { copyText(palette.colors.joined(separator: ", ")) }
                            Divider()
                            Button("Move up") { store.move(palette.id, by: -1) }
                                .disabled(store.palettes.first?.id == palette.id)
                            Button("Move down") { store.move(palette.id, by: 1) }
                                .disabled(store.palettes.last?.id == palette.id)
                            Divider()
                            Button("Delete…", role: .destructive) { deleting = palette }
                        }
                    }
                    .onMove { offsets, destination in
                        guard search.isEmpty else { return }
                        store.move(from: offsets, to: destination)
                    }
                }.listStyle(.sidebar)
                HStack(spacing: 12) {
                    Text("Palette order").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { if let selection { store.move(selection, by: -1) } } label: { Image(systemName: "arrow.up") }
                        .disabled(selected == nil || store.palettes.first?.id == selection)
                        .help("Move selected palette up").accessibilityLabel("Move selected palette up")
                    Button { if let selection { store.move(selection, by: 1) } } label: { Image(systemName: "arrow.down") }
                        .disabled(selected == nil || store.palettes.last?.id == selection)
                        .help("Move selected palette down").accessibilityLabel("Move selected palette down")
                }.buttonStyle(.borderless).padding(.horizontal, 12).padding(.vertical, 8)
                HStack(spacing: 6) {
                    Image(systemName: store.cloudEnabled ? "icloud" : "internaldrive")
                    Text(store.syncStatus)
                    Spacer()
                    Menu {
                        Button("Import palettes…", action: store.importPalettes)
                        Button("Export palettes…", action: store.exportPalettes).disabled(store.palettes.isEmpty)
                    } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
                }.font(.caption).foregroundStyle(.secondary).padding(12)
                .help(store.cloudEnabled ? "iCloud propagates changes automatically while signed in to your Apple Account." : "This build saves locally. iCloud requires an Apple developer signed build with the included entitlement.")
            }.navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            if let palette = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(palette.name).font(.largeTitle.weight(.semibold)).textSelection(.enabled)
                                Text("\(palette.colors.count) colors · Click a swatch to copy its HEX").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Edit") { editing = palette }
                        }
                        HStack(spacing: 0) {
                            ForEach(Array(palette.colors.enumerated()), id: \.offset) { _, hex in
                                Button { copyText(hex); copied = true } label: {
                                    Rectangle().fill(Color(hex: hex)).frame(minWidth: 8, minHeight: 200)
                                }.buttonStyle(.plain).help("Copy \(hex)").accessibilityLabel("Copy \(hex)")
                            }
                        }.clipShape(RoundedRectangle(cornerRadius: 16))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], alignment: .leading, spacing: 12) {
                            ForEach(Array(palette.colors.enumerated()), id: \.offset) { _, hex in
                                Button { copyText(hex); copied = true } label: {
                                    HStack {
                                        RoundedRectangle(cornerRadius: 5).fill(Color(hex: hex)).frame(width: 24, height: 24).overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.1)))
                                        Text(hex).font(.system(.body, design: .monospaced))
                                    }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
                            }
                        }
                        HStack {
                            Button { copyText(palette.colors.joined(separator: ", ")); copied = true } label: { Label("Copy palette", systemImage: "doc.on.doc") }
                            if copied { Text("Copied").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Button(role: .destructive) { deleting = palette } label: { Image(systemName: "trash") }.help("Delete palette")
                        }
                    }.padding(32)
                }.onChange(of: selection) { _, _ in copied = false }
            } else {
                ContentUnavailableView {
                    Label(store.palettes.isEmpty ? "A home for your colors" : "Choose a palette", systemImage: "swatchpalette")
                } description: {
                    Text(store.palettes.isEmpty ? "Save the colors you love. Keep them a click away in your menu bar." : "Select a palette in the sidebar, or make something new.")
                } actions: {
                    Button("New palette") { creating = true }.buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .sheet(isPresented: $creating) { EditorView(store: store, original: nil) { selection = $0 } }
        .sheet(item: $editing) { palette in EditorView(store: store, original: palette) { selection = $0 } }
        .confirmationDialog("Delete “\(deleting?.name ?? "")”?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete palette", role: .destructive) { if let deleting { store.delete(deleting) }; deleting = nil }
        } message: { Text("This also removes it from your other Macs when iCloud sync is enabled.") }
        .alert("Palette", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .background {
            Button("") { creating = true }.keyboardShortcut("n").hidden()
        }
    }
}

struct EditorView: View {
    @ObservedObject var store: PaletteStore
    let original: Palette?
    let onSave: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var colors: [String]
    @State private var hex = ""
    @State private var picker = Color(hex: "#5E5CE6")
    @State private var validation: String?

    init(store: PaletteStore, original: Palette?, onSave: @escaping (UUID) -> Void) {
        self.store = store; self.original = original; self.onSave = onSave
        _name = State(initialValue: original?.name ?? "")
        _colors = State(initialValue: original?.colors ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(original == nil ? "New palette" : "Edit palette").font(.title2.weight(.semibold))
            TextField("Palette name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                TextField("#HEX, #HEX…", text: $hex).textFieldStyle(.roundedBorder).onSubmit(addHex)
                Button("Add", action: addHex).disabled(colors.count >= 24)
            }
            HStack {
                ColorPicker("Choose a color", selection: $picker, supportsOpacity: false)
                Button("Add color") {
                    if let rgb = NSColor(picker).usingColorSpace(.sRGB) {
                        colors.append(String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded())))
                        validation = nil
                    }
                }.disabled(colors.count >= 24)
            }
            if let validation { Text(validation).font(.caption).foregroundStyle(.red) }
            if colors.isEmpty {
                Text("Add HEX codes or choose colors above.").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 110)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 8).fill(Color(hex: color)).frame(height: 48)
                                HStack(spacing: 3) {
                                    Text(color).font(.system(size: 10, design: .monospaced))
                                    Button { colors.remove(at: index) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Remove \(color)")
                                }
                            }
                        }
                    }
                }.frame(height: 170)
            }
            HStack {
                Text("\(colors.count)/24 colors").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save palette") {
                    if !hex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        addHex()
                        if validation != nil { return }
                    }
                    if let id = store.save(name: name, colors: colors, id: original?.id) { onSave(id); dismiss() }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 100 || (colors.isEmpty && hex.isEmpty))
            }
        }.padding(24).frame(width: 460)
    }

    private func addHex() {
        let tokens = hex.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;"))).filter { !$0.isEmpty }
        let parsed = tokens.compactMap(Palette.hex)
        guard !tokens.isEmpty, parsed.count == tokens.count else { validation = "Use 3- or 6-digit HEX codes, separated by spaces or commas."; return }
        guard colors.count + parsed.count <= 24 else { validation = "A palette can contain up to 24 colors."; return }
        colors.append(contentsOf: parsed); hex = ""; validation = nil
    }
}

struct QuickView: View {
    @ObservedObject var store: PaletteStore
    let openLibrary: () -> Void
    @State private var copied: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Palette", systemImage: "swatchpalette").font(.headline)
                Spacer()
                Button("Open library", action: openLibrary).buttonStyle(.borderless)
            }
            if store.menuBarPalettes.isEmpty {
                Text(store.palettes.isEmpty ? "Your colors, a click away." : "No palettes selected for the menu bar.")
                    .foregroundStyle(.secondary).padding(.vertical, 18)
                Button(store.palettes.isEmpty ? "Create your first palette" : "Choose palettes in library", action: openLibrary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(store.menuBarPalettes) { palette in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(palette.name).font(.subheadline.weight(.medium)).lineLimit(1)
                                    Spacer()
                                    Button { copyText(palette.colors.joined(separator: ", ")); copied = "Palette copied" } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).help("Copy palette")
                                }
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(palette.colors.count, 8)), spacing: 4) {
                                    ForEach(Array(palette.colors.enumerated()), id: \.offset) { _, hex in
                                        Button { copyText(hex); copied = "\(hex) copied" } label: {
                                            RoundedRectangle(cornerRadius: 5).fill(Color(hex: hex)).frame(height: 32).overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.08)))
                                        }.buttonStyle(.plain).help("Copy \(hex)").accessibilityLabel("Copy \(hex)")
                                    }
                                }
                            }
                        }
                    }.padding(.vertical, 4)
                }.frame(maxHeight: 340)
            }
            Divider()
            HStack {
                Text(copied ?? store.syncStatus).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless)
            }
        }.padding(16).frame(width: 320)
    }
}
