import FeatureEditor
import FeatureHome
import FeatureLibrary
import FeatureReview
import FeatureSettings
import FeatureWord
import RavanUI
import SwiftUI

/// The app shell: a Liquid Glass tab bar with a dedicated search tab, one navigation stack per
/// tab, the word editor sheet and the full-screen review session.
public struct RavanRootView: View {
    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        RootTabs()
            .environment(dependencies.store)
            .environment(dependencies.settings)
            .environment(dependencies.pronouncer)
            .environment(dependencies.router)
            // The interface is Persian: right-to-left everywhere, Persian digits in formatters.
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "fa_IR"))
            .preferredColorScheme(dependencies.settings.colorScheme)
            .tint(RavanColor.brand)
            .task {
                await dependencies.store.prepare()
                #if DEBUG
                ScreenshotMode.apply(store: dependencies.store, router: dependencies.router)
                #endif
            }
    }
}

private struct RootTabs: View {
    @Environment(DictionaryStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        let dueCount = store.revision >= 0 ? store.dueCount() : 0

        TabView(selection: $router.selectedTab) {
            Tab("خانه", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeView().appDestinations()
                }
            }
            Tab("واژه‌ها", systemImage: "books.vertical.fill", value: AppTab.library) {
                NavigationStack(path: $router.libraryPath) {
                    LibraryView().appDestinations()
                }
            }
            Tab("مرور", systemImage: "rectangle.stack.fill", value: AppTab.review) {
                NavigationStack(path: $router.reviewPath) {
                    ReviewDashboardView().appDestinations()
                }
            }
            .badge(dueCount)
            Tab("تنظیمات", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack(path: $router.settingsPath) {
                    SettingsView().appDestinations()
                }
            }
            Tab("جستجو", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                NavigationStack(path: $router.searchPath) {
                    SearchView().appDestinations()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $router.editor) { request in
            WordEditorView(request: request) { wordID, isNew in
                if isNew { router.open(.word(wordID)) }
            }
        }
        .fullScreenCover(item: $router.session) { request in
            ReviewSessionView(request: request)
        }
    }
}

private extension View {
    /// Every pushed screen of the app, registered once per navigation stack.
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .word(let id): WordDetailView(wordID: id)
            case .deck(let id): DeckDetailView(deckID: id)
            }
        }
    }
}
