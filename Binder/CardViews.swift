import SwiftUI
import UIKit

struct CardFace: View {
    let card: BinderCard
    let collection: BinderCollection
    var compact = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                generatedBackground
                if let data = card.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.08), .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                } else {
                    cardArtwork
                }

                VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                    HStack(spacing: 7) {
                        Image(systemName: collection.symbol)
                            .font(.system(size: compact ? 9 : 11, weight: .bold))
                        Text(collection.name.uppercased())
                            .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if card.quantity > 1 {
                            Text("×\(card.quantity)")
                                .font(.system(size: compact ? 9 : 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.18), in: Capsule())
                        }
                    }
                    Spacer(minLength: 8)
                    Text(card.name.isEmpty ? "Untitled card" : card.name)
                        .font(.system(size: compact ? 17 : 23, weight: .bold, design: .rounded))
                        .tracking(-0.45)
                        .lineLimit(compact ? 2 : 3)
                        .minimumScaleFactor(0.78)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(card.setName.isEmpty ? "Unsorted" : card.setName)
                            .lineLimit(1)
                        if !card.number.isEmpty {
                            Text("· \(card.number)").lineLimit(1)
                        }
                    }
                    .font(.system(size: compact ? 9 : 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    if !compact {
                        HStack {
                            Text(card.condition.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(1)
                            Spacer()
                            Text(card.value.binderCurrency)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .padding(.top, 3)
                    }
                }
                .foregroundStyle(.white)
                .padding(compact ? 13 : 17)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 19 : 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 19 : 25, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: collection.tint.opacity(0.25), radius: compact ? 9 : 17, x: 0, y: compact ? 5 : 12)
        }
        .aspectRatio(0.70, contentMode: .fit)
    }

    private var generatedBackground: some View {
        LinearGradient(colors: [collection.tint.opacity(0.98), collection.tint.opacity(0.63), Color(red: 0.12, green: 0.13, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var cardArtwork: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: geometry.size.width * 0.88)
                    .offset(x: geometry.size.width * 0.32, y: -geometry.size.height * 0.16)
                Circle()
                    .stroke(.white.opacity(0.11), lineWidth: 1)
                    .frame(width: geometry.size.width * 0.76)
                    .offset(x: -geometry.size.width * 0.42, y: geometry.size.height * 0.12)
                Image(systemName: collection.symbol)
                    .font(.system(size: geometry.size.width * 0.35, weight: .light))
                    .foregroundStyle(.white.opacity(0.15))
                    .rotationEffect(.degrees(-14))
                    .offset(x: geometry.size.width * 0.23, y: -geometry.size.height * 0.02)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

struct CarouselDeck: View {
    let cards: [BinderCard]
    let collection: BinderCollection
    @Binding var selection: UUID?
    let onSelect: (BinderCard) -> Void

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.70
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(cards) { card in
                        GeometryReader { itemGeometry in
                            let frame = itemGeometry.frame(in: .named("binderCarousel"))
                            let distance = min(abs(frame.midX - geometry.size.width / 2) / max(geometry.size.width, 1), 1)
                            CardFace(card: card, collection: collection)
                                .scaleEffect(1 - distance * 0.11)
                                .rotationEffect(.degrees(frame.midX < geometry.size.width / 2 ? -7 * distance : 7 * distance), anchor: .bottom)
                                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: distance)
                                .onTapGesture { onSelect(card) }
                        }
                        .frame(width: cardWidth, height: 340)
                        .id(card.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, max(0, (geometry.size.width - cardWidth) / 2))
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selection, anchor: .center)
            .coordinateSpace(name: "binderCarousel")
            .frame(height: 348)
        }
        .frame(height: 348)
        .onAppear {
            if selection == nil { selection = cards.first?.id }
        }
        .onChange(of: cards.map(\.id)) { _, ids in
            if let selected = selection, ids.contains(selected) { return }
            selection = ids.first
        }
    }
}
