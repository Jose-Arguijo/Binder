import SwiftUI

struct BinderCard: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var setName: String = ""
    var number: String = ""
    var condition: String = "Near mint"
    var quantity: Int = 1
    var value: Double = 0
    var notes: String = ""
    var photoData: Data?
}

struct BinderCollection: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var symbol: String
    var colorName: String
    var cards: [BinderCard] = []
    var children: [BinderCollection] = []

    var tint: Color { BinderPalette.color(for: colorName) }
    var cardCount: Int {
        cards.reduce(0) { $0 + max(0, $1.quantity) } + children.reduce(0) { $0 + $1.cardCount }
    }
    var estimatedValue: Double {
        cards.reduce(0) { $0 + max(0, $1.value) * Double(max(0, $1.quantity)) } + children.reduce(0) { $0 + $1.estimatedValue }
    }
}

enum BinderPalette {
    struct Option: Identifiable {
        let name: String
        let hex: UInt
        let symbol: String
        var id: String { name }
    }

    static let options: [Option] = [
        Option(name: "Indigo", hex: 0x7774F5, symbol: "sparkles"),
        Option(name: "Coral", hex: 0xF27B68, symbol: "flame.fill"),
        Option(name: "Mint", hex: 0x4EAA91, symbol: "leaf.fill"),
        Option(name: "Gold", hex: 0xD89A3B, symbol: "sun.max.fill"),
        Option(name: "Blue", hex: 0x4B91D2, symbol: "drop.fill"),
        Option(name: "Rose", hex: 0xD3699D, symbol: "heart.fill")
    ]

    static func color(for name: String) -> Color {
        let hex = options.first(where: { $0.name == name })?.hex ?? options[0].hex
        return Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

enum BinderTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension Double {
    var binderCurrency: String {
        formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

extension Color {
    static let binderCanvas = Color(uiColor: .systemGroupedBackground)
    static let binderCard = Color(uiColor: .secondarySystemGroupedBackground)
    static let binderInk = Color(uiColor: .label)
    static let binderMuted = Color(uiColor: .secondaryLabel)
}
