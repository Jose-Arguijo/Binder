import SwiftUI

@MainActor
final class BinderStore: ObservableObject {
    @Published private(set) var collections: [BinderCollection] {
        didSet { persist() }
    }
    @Published var theme: BinderTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "binder.theme") }
    }

    var colorScheme: ColorScheme? { theme.colorScheme }
    var totalCardCount: Int { collections.reduce(0) { $0 + $1.cardCount } }
    var totalValue: Double { collections.reduce(0) { $0 + $1.estimatedValue } }

    init() {
        theme = BinderTheme(rawValue: UserDefaults.standard.string(forKey: "binder.theme") ?? "system") ?? .system
        if let url = Self.libraryURL,
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([BinderCollection].self, from: data) {
            collections = decoded
        } else {
            collections = Self.sampleCollections
        }
    }

    func collection(id: UUID) -> BinderCollection? { find(id, in: collections) }
    func parentID(for id: UUID) -> UUID? { findParent(id, in: collections, parent: nil) }

    func addCollection(_ collection: BinderCollection, under parentID: UUID? = nil) {
        if let parentID {
            update(parentID, in: &collections) { $0.children.append(collection) }
        } else {
            collections.append(collection)
        }
    }

    func updateCollection(_ collection: BinderCollection) {
        update(collection.id, in: &collections) { $0 = collection }
    }

    func deleteCollection(id: UUID) {
        remove(id, from: &collections)
    }

    @discardableResult
    func moveCollection(id: UUID, under parentID: UUID?) -> Bool {
        guard let moving = collection(id: id) else { return false }
        if let parentID, parentID == id || contains(id: parentID, in: moving.children) { return false }
        remove(id, from: &collections)
        if let parentID {
            guard collection(id: parentID) != nil else { return false }
            update(parentID, in: &collections) { $0.children.append(moving) }
        } else {
            collections.append(moving)
        }
        return true
    }

    func addCard(_ card: BinderCard, to collectionID: UUID) {
        update(collectionID, in: &collections) { $0.cards.append(card) }
    }

    func updateCard(_ card: BinderCard, in collectionID: UUID) {
        update(collectionID, in: &collections) { collection in
            guard let index = collection.cards.firstIndex(where: { $0.id == card.id }) else { return }
            collection.cards[index] = card
        }
    }

    func deleteCard(id: UUID, from collectionID: UUID) {
        update(collectionID, in: &collections) { $0.cards.removeAll { $0.id == id } }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(collections), let url = Self.libraryURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Binder could not save its library: %@", error.localizedDescription)
        }
    }

    private static var libraryURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Binder/library.json")
    }

    private func find(_ id: UUID, in list: [BinderCollection]) -> BinderCollection? {
        for item in list {
            if item.id == id { return item }
            if let match = find(id, in: item.children) { return match }
        }
        return nil
    }

    private func findParent(_ id: UUID, in list: [BinderCollection], parent: UUID?) -> UUID? {
        for item in list {
            if item.id == id { return parent }
            if let found = findParent(id, in: item.children, parent: item.id) { return found }
        }
        return nil
    }

    private func update(_ id: UUID, in list: inout [BinderCollection], change: (inout BinderCollection) -> Void) {
        for index in list.indices {
            if list[index].id == id {
                change(&list[index])
                return
            }
            update(id, in: &list[index].children, change: change)
        }
    }

    private func remove(_ id: UUID, from list: inout [BinderCollection]) {
        list.removeAll { $0.id == id }
        for index in list.indices { remove(id, from: &list[index].children) }
    }

    private func contains(id: UUID, in list: [BinderCollection]) -> Bool {
        list.contains { $0.id == id || contains(id: id, in: $0.children) }
    }

    private static var sampleCollections: [BinderCollection] {
        let holos = BinderCollection(name: "First Edition Holos", symbol: "sparkles", colorName: "Gold", cards: [
            BinderCard(name: "Charizard", setName: "Base Set", number: "4/102", condition: "Lightly played", quantity: 1, value: 385),
            BinderCard(name: "Blastoise", setName: "Base Set", number: "2/102", condition: "Near mint", quantity: 1, value: 145)
        ])
        let baseSet = BinderCollection(name: "Base Set", symbol: "rectangle.stack.fill", colorName: "Coral", cards: [
            BinderCard(name: "Pikachu", setName: "Base Set", number: "58/102", condition: "Near mint", quantity: 3, value: 12),
            BinderCard(name: "Ninetales", setName: "Base Set", number: "12/102", condition: "Excellent", quantity: 1, value: 8.5)
        ], children: [holos])
        let pokemon = BinderCollection(name: "Pokémon", symbol: "bolt.fill", colorName: "Coral", cards: [
            BinderCard(name: "Eevee", setName: "Twilight Masquerade", number: "188/167", condition: "Near mint", quantity: 2, value: 7.25)
        ], children: [baseSet])
        let magic = BinderCollection(name: "Magic: The Gathering", symbol: "flame.fill", colorName: "Indigo", cards: [
            BinderCard(name: "Sol Ring", setName: "Commander Masters", number: "396", condition: "Near mint", quantity: 2, value: 3.75),
            BinderCard(name: "The One Ring", setName: "Tales of Middle-earth", number: "246", condition: "Near mint", quantity: 1, value: 72)
        ])
        let sports = BinderCollection(name: "Basketball", symbol: "basketball.fill", colorName: "Mint", cards: [
            BinderCard(name: "Rookie Season", setName: "Courtside", number: "RC-12", condition: "Excellent", quantity: 1, value: 28)
        ])
        return [pokemon, magic, sports]
    }
}
