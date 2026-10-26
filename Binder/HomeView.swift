import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: BinderStore
    @State private var showingNewCollection = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 27) {
                    header
                    collectionOverview
                    collectionList
                    footerNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .background(Color.binderCanvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewCollection) {
                CollectionEditorView(existing: nil, parentID: nil) { collection in
                    store.addCollection(collection)
                }
            }
        }
        .tint(.binderInk)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.91))
                    Text("BINDER")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(2.4)
                        .foregroundStyle(Color.binderMuted)
                }
                Text("Your collection,\nbeautifully kept.")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .tracking(-0.9)
                    .lineSpacing(-1)
                    .foregroundStyle(Color.binderInk)
            }
            Spacer(minLength: 0)
            Menu {
                ForEach(BinderTheme.allCases) { theme in
                    Button {
                        store.theme = theme
                    } label: {
                        Label(theme.label, systemImage: theme.icon)
                    }
                }
            } label: {
                Image(systemName: store.theme.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.binderInk)
                    .frame(width: 44, height: 44)
                    .background(Color.binderCard, in: Circle())
                    .overlay(Circle().strokeBorder(Color.binderInk.opacity(0.06)))
            }
            .accessibilityLabel("Appearance: \(store.theme.label)")
        }
        .padding(.top, 8)
    }

    private var collectionOverview: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Label("IN YOUR BINDER", systemImage: "circle.grid.2x2.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.25)
                    .foregroundStyle(.white.opacity(0.72))
                Text("\(store.totalCardCount)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .foregroundStyle(.white)
                Text("cards collected")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 8)
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1, height: 77)
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 9) {
                Label("ESTIMATED VALUE", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.72))
                Text(store.totalValue.binderCurrency)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text("across all collections")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 21)
        .background {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.34, green: 0.34, blue: 0.72), Color(red: 0.48, green: 0.45, blue: 0.91)], startPoint: .bottomLeading, endPoint: .topTrailing))
                .overlay(alignment: .topTrailing) {
                    Circle().fill(.white.opacity(0.06)).frame(width: 155, height: 155).offset(x: 38, y: -82)
                }
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        }
        .shadow(color: Color(red: 0.36, green: 0.35, blue: 0.75).opacity(0.18), radius: 18, x: 0, y: 9)
    }

    private var collectionList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collections")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .tracking(-0.45)
                    Text("Your shelves, all in one place")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.binderMuted)
                }
                Spacer()
                Button {
                    showingNewCollection = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color(red: 0.45, green: 0.43, blue: 0.91), in: Circle())
                }
                .accessibilityLabel("Add collection")
            }

            if store.collections.isEmpty {
                ContentUnavailableView {
                    Label("A fresh start", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Create your first collection to begin cataloging.")
                } actions: {
                    Button("Create collection") { showingNewCollection = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.collections) { collection in
                        NavigationLink {
                            CollectionView(collectionID: collection.id)
                        } label: {
                            CollectionRow(collection: collection, depth: 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var footerNote: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Your collection stays on this device")
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundStyle(Color.binderMuted.opacity(0.75))
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
}

struct CollectionRow: View {
    let collection: BinderCollection
    var depth: Int = 0

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(collection.tint.opacity(0.14))
                Image(systemName: collection.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(collection.tint)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text(collection.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.binderInk)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(collection.cardCount) cards")
                    Circle().frame(width: 3, height: 3)
                    Text(collection.estimatedValue.binderCurrency)
                    if !collection.children.isEmpty {
                        Circle().frame(width: 3, height: 3)
                        Text("\(collection.children.count) shelf\(collection.children.count == 1 ? "" : "s")")
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.binderMuted)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.binderMuted.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.binderCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.binderInk.opacity(0.045)))
        .shadow(color: .black.opacity(0.025), radius: 8, x: 0, y: 3)
    }
}
