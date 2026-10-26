import SwiftUI

private enum CollectionSheet: Identifiable {
    case card(BinderCard?)
    case childCollection
    case editCollection
    case moveCollection

    var id: String {
        switch self {
        case .card(let card): "card-\(card?.id.uuidString ?? "new")"
        case .childCollection: "child-collection"
        case .editCollection: "edit-collection"
        case .moveCollection: "move-collection"
        }
    }
}

struct CollectionView: View {
    @EnvironmentObject private var store: BinderStore
    @Environment(\.dismiss) private var dismiss
    let collectionID: UUID
    @State private var searchText = ""
    @State private var gridMode = false
    @State private var selection: UUID?
    @State private var activeSheet: CollectionSheet?
    @State private var confirmingDelete = false

    private var collection: BinderCollection { store.collection(id: collectionID) ?? BinderCollection(name: "Collection", symbol: "square.stack.3d.up", colorName: "Indigo") }
    private var filteredCards: [BinderCard] {
        guard !searchText.isEmpty else { return collection.cards }
        return collection.cards.filter { card in
            [card.name, card.setName, card.number, card.condition, card.notes].contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    private var selectedPosition: Int {
        guard let selection, let index = filteredCards.firstIndex(where: { $0.id == selection }) else { return filteredCards.isEmpty ? 0 : 1 }
        return index + 1
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 23) {
                summaryHeader
                if !collection.children.isEmpty { subcollections }
                searchField
                cardSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 34)
        }
        .background(Color.binderCanvas.ignoresSafeArea())
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    gridMode.toggle()
                } label: {
                    Image(systemName: gridMode ? "rectangle.stack.fill" : "square.grid.2x2")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel(gridMode ? "Show carousel" : "Show grid")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { activeSheet = .card(nil) } label: { Label("Add card", systemImage: "plus.rectangle.on.rectangle") }
                    Button { activeSheet = .childCollection } label: { Label("Add subcollection", systemImage: "folder.badge.plus") }
                    Divider()
                    Button { activeSheet = .editCollection } label: { Label("Edit collection", systemImage: "pencil") }
                    Button { activeSheet = .moveCollection } label: { Label("Move collection", systemImage: "folder") }
                    Divider()
                    Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete collection", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .card(let card):
                CardEditorView(card: card, collection: collection, onSave: { savedCard in
                    if collection.cards.contains(where: { $0.id == savedCard.id }) {
                        store.updateCard(savedCard, in: collectionID)
                    } else {
                        store.addCard(savedCard, to: collectionID)
                    }
                }, onDelete: card.map { target in { store.deleteCard(id: target.id, from: collectionID) } })
            case .childCollection:
                CollectionEditorView(existing: nil, parentID: collectionID) { store.addCollection($0, under: collectionID) }
            case .editCollection:
                CollectionEditorView(existing: collection, parentID: store.parentID(for: collectionID)) { store.updateCollection($0) }
            case .moveCollection:
                MoveCollectionView(collectionID: collectionID)
            }
        }
        .confirmationDialog("Delete \(collection.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete collection", role: .destructive) {
                store.deleteCollection(id: collectionID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All cards and subcollections inside this collection will also be deleted.")
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(collection.tint.opacity(0.16))
                Image(systemName: collection.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(collection.tint)
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 5) {
                Text(collection.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(-0.45)
                    .foregroundStyle(Color.binderInk)
                Text("\(collection.cardCount) cards  ·  \(collection.children.count) subcollection\(collection.children.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.binderMuted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                Text("VALUE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color.binderMuted)
                Text(collection.estimatedValue.binderCurrency)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(collection.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(15)
        .background(Color.binderCard, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).strokeBorder(Color.binderInk.opacity(0.05)))
    }

    private var subcollections: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("SUBCOLLECTIONS", detail: "\(collection.children.count) shelves")
                Spacer()
                Button {
                    activeSheet = .childCollection
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(collection.tint)
                }
                .accessibilityLabel("Add subcollection")
            }
            VStack(spacing: 9) {
                ForEach(collection.children) { child in
                    NavigationLink {
                        CollectionView(collectionID: child.id)
                    } label: {
                        CollectionRow(collection: child)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.binderMuted)
            TextField("Search cards in \(collection.name)", text: $searchText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.binderMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.binderCard, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.binderInk.opacity(0.045)))
    }

    private var cardSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center) {
                sectionTitle(searchText.isEmpty ? "CARDS" : "SEARCH RESULTS", detail: "\(filteredCards.reduce(0) { $0 + $1.quantity }) total")
                Spacer()
                if !filteredCards.isEmpty && !gridMode {
                    Text("\(selectedPosition) / \(filteredCards.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.binderMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.binderCard, in: Capsule())
                }
            }

            if filteredCards.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: searchText.isEmpty ? "rectangle.on.rectangle.angled" : "magnifyingglass")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(collection.tint)
                    Text(searchText.isEmpty ? "This shelf is waiting" : "No cards found")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.binderInk)
                    Text(searchText.isEmpty ? "Add a card to start filling this collection." : "Try another name, set, number or note.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.binderMuted)
                        .multilineTextAlignment(.center)
                    if searchText.isEmpty {
                        Button { activeSheet = .card(nil) } label: {
                            Label("Add a card", systemImage: "plus")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(collection.tint, in: Capsule())
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .padding(.horizontal, 24)
                .background(Color.binderCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else if gridMode {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)], spacing: 15) {
                    ForEach(filteredCards) { card in
                        CardFace(card: card, collection: collection, compact: true)
                            .onTapGesture { activeSheet = .card(card) }
                    }
                }
                .padding(.top, 3)
            } else {
                CarouselDeck(cards: filteredCards, collection: collection, selection: $selection) { card in
                    activeSheet = .card(card)
                }
                .padding(.horizontal, -20)
            }

            if !filteredCards.isEmpty {
                Button { activeSheet = .card(nil) } label: {
                    Label("Add a card", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(collection.tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(collection.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Color.binderMuted)
            Text(detail)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.binderInk)
        }
    }
}
