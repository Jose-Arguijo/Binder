import SwiftUI

@main
struct BinderApp: App {
    @StateObject private var store = BinderStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(store.colorScheme)
        }
    }
}
