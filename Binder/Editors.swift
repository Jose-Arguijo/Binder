import PhotosUI
import SwiftUI
import UIKit

struct CollectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BinderCollection
    @State private var iconSearch = ""
    let parentID: UUID?
    let onSave: (BinderCollection) -> Void

    private let symbols = ["sparkles", "bolt.fill", "flame.fill", "leaf.fill", "sun.max.fill", "drop.fill", "heart.fill", "star.fill", "moon.stars.fill", "crown.fill", "trophy.fill", "basketball.fill", "baseball.fill", "football.fill", "gamecontroller.fill", "rectangle.stack.fill", "books.vertical.fill", "photo.on.rectangle.angled", "shippingbox.fill", "ticket.fill", "atom", "pawprint.fill", "car.fill", "music.note"]

    init(existing: BinderCollection?, parentID: UUID?, onSave: @escaping (BinderCollection) -> Void) {
        _draft = State(initialValue: existing ?? BinderCollection(name: "", symbol: "sparkles", colorName: "Indigo"))
        self.parentID = parentID
        self.onSave = onSave
    }

    private var filteredSymbols: [String] {
        guard !iconSearch.isEmpty else { return symbols }
        return symbols.filter { $0.localizedCaseInsensitiveContains(iconSearch) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(draft.tint.opacity(0.15))
                            Image(systemName: draft.symbol)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(draft.tint)
                        }
                        .frame(width: 58, height: 58)
                        TextField("Collection name", text: $draft.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .textInputAutocapitalization(.words)
                    }
                    .padding(.vertical, 5)
                } header: {
                    Text("COLLECTION")
                }

                Section("ICON") {
                    TextField("Find an icon", text: $iconSearch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        ForEach(filteredSymbols, id: \.self) { symbol in
                            Button {
                                draft.symbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(draft.symbol == symbol ? .white : draft.tint)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(draft.symbol == symbol ? draft.tint : draft.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                        }
                    }
                    .padding(.vertical, 3)
                }

                Section("COLOR") {
                    HStack(spacing: 12) {
                        ForEach(BinderPalette.options, id: \.name) { option in
                            let color = BinderPalette.color(for: option.name)
                            Button {
                                draft.colorName = option.name
                            } label: {
                                ZStack {
                                    Circle().fill(color).frame(width: 39, height: 39)
                                    if draft.colorName == option.name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.name)
                            .accessibilityAddTraits(draft.colorName == option.name ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 3)
                }

                if let parentID {
                    Section {
                        Label("Saved inside its parent collection", systemImage: "folder.fill")
                            .foregroundStyle(draft.tint)
                    }
                    .listRowBackground(draft.tint.opacity(0.08))
                }
            }
            .navigationTitle(draft.name.isEmpty ? "New Collection" : "Edit Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.binderMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BinderCard
    @State private var valueText: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var confirmingDelete = false

    let collection: BinderCollection
    let onSave: (BinderCard) -> Void
    let onDelete: (() -> Void)?

    private let conditions = ["Mint", "Near mint", "Excellent", "Lightly played", "Played", "Poor"]

    init(card: BinderCard?, collection: BinderCollection, onSave: @escaping (BinderCard) -> Void, onDelete: (() -> Void)?) {
        let initial = card ?? BinderCard(name: "")
        _draft = State(initialValue: initial)
        _valueText = State(initialValue: initial.value == 0 ? "" : String(initial.value))
        self.collection = collection
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardFace(card: draft, collection: collection, compact: true)
                        .frame(maxWidth: 190)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .listRowBackground(Color.clear)
                }

                Section("CARD DETAILS") {
                    TextField("Card name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    TextField("Set", text: $draft.setName)
                        .textInputAutocapitalization(.words)
                    TextField("Card number", text: $draft.number)
                        .textInputAutocapitalization(.characters)
                    Picker("Condition", selection: $draft.condition) {
                        ForEach(conditions, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper(value: $draft.quantity, in: 1...999) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(draft.quantity)")
                                .foregroundStyle(Color.binderMuted)
                                .monospacedDigit()
                        }
                    }
                    HStack {
                        Text("Value each")
                        Spacer()
                        TextField("0.00", text: $valueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }

                Section("PHOTO") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(draft.photoData == nil ? "Choose a photo" : "Replace photo", systemImage: "photo")
                    }
                    if draft.photoData != nil {
                        Button(role: .destructive) {
                            draft.photoData = nil
                            selectedPhoto = nil
                        } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }
                    Text("No photo? Binder creates a color-matched card face for you.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.binderMuted)
                }

                Section("NOTES") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 90)
                        .overlay(alignment: .topLeading) {
                            if draft.notes.isEmpty {
                                Text("Add a note about this card…")
                                    .foregroundStyle(Color.binderMuted.opacity(0.7))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Label("Delete card", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "New Card" : "Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.binderMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        draft.value = max(0, Double(valueText.replacingOccurrences(of: ",", with: ".")) ?? 0)
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Delete this card?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete card", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto,
                      let data = try? await selectedPhoto.loadTransferable(type: Data.self) else { return }
                if let image = UIImage(data: data) {
                    let maxDimension: CGFloat = 1600
                    let scale = min(1, maxDimension / max(image.size.width, image.size.height))
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let renderer = UIGraphicsImageRenderer(size: size)
                    draft.photoData = renderer.jpegData(withCompressionQuality: 0.82) { _ in
                        image.draw(in: CGRect(origin: .zero, size: size))
                    }
                } else {
                    draft.photoData = data
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct MoveDestination: Identifiable {
    let collection: BinderCollection
    let depth: Int
    var id: UUID { collection.id }
}

struct MoveCollectionView: View {
    @EnvironmentObject private var store: BinderStore
    @Environment(\.dismiss) private var dismiss
    let collectionID: UUID
    @State private var destinationID: UUID?
    @State private var initialized = false

    private var collection: BinderCollection { store.collection(id: collectionID) ?? BinderCollection(name: "Collection", symbol: "folder", colorName: "Indigo") }
    private var excludedIDs: Set<UUID> { descendants(of: collection).union([collectionID]) }
    private var destinationCollections: [MoveDestination] { flatten(store.collections) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    destinationRow(name: "Top level", symbol: "square.stack.3d.up", color: .binderMuted, id: nil, depth: 0)
                    ForEach(destinationCollections.filter { !excludedIDs.contains($0.id) }) { item in
                        destinationRow(name: item.collection.name, symbol: item.collection.symbol, color: item.collection.tint, id: item.collection.id, depth: item.depth)
                    }
                } header: {
                    Text("MOVE UNDER")
                } footer: {
                    Text("Moving a collection carries its cards and every nested shelf with it.")
                }
            }
            .navigationTitle("Move Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.binderMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Move") {
                        if store.moveCollection(id: collectionID, under: destinationID) { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(destinationID == store.parentID(for: collectionID))
                }
            }
            .onAppear {
                if !initialized {
                    destinationID = store.parentID(for: collectionID)
                    initialized = true
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func destinationRow(name: String, symbol: String, color: Color, id: UUID?, depth: Int) -> some View {
        Button {
            destinationID = id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 25)
                Text(name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.binderInk)
                Spacer()
                if destinationID == id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.91))
                }
            }
            .padding(.leading, CGFloat(depth) * 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func flatten(_ items: [BinderCollection], depth: Int = 0) -> [MoveDestination] {
        items.flatMap { item in
            [MoveDestination(collection: item, depth: depth)] + flatten(item.children, depth: depth + 1)
        }
    }

    private func descendants(of item: BinderCollection) -> Set<UUID> {
        item.children.reduce(into: Set<UUID>()) { result, child in
            result.insert(child.id)
            result.formUnion(descendants(of: child))
        }
    }
}
