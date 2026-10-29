import Observation
import SwiftUI

/// Pushed destinations inside a tab's navigation stack.
public enum AppRoute: Hashable, Sendable {
    case word(String)
    case deck(String)
}

public enum AppTab: Hashable, Sendable {
    case home, library, review, settings, search
}

/// Presents the word editor as a sheet.
public struct EditorRequest: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var wordID: String?
    public var initialText: String
}

/// Presents a flash-card session full screen.
public struct SessionRequest: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var deckID: String?
    public var practice: Bool
}

/// App-wide navigation state. Features ask the router to navigate; only the app shell
/// (AppFeature) knows how to build each destination, so features never import each other.
@MainActor
@Observable
public final class AppRouter {
    public var selectedTab: AppTab = .home
    public var homePath: [AppRoute] = []
    public var libraryPath: [AppRoute] = []
    public var reviewPath: [AppRoute] = []
    public var settingsPath: [AppRoute] = []
    public var searchPath: [AppRoute] = []
    public var editor: EditorRequest?
    public var session: SessionRequest?

    public init() {}

    public func open(_ route: AppRoute) {
        switch selectedTab {
        case .home: homePath.append(route)
        case .library: libraryPath.append(route)
        case .review: reviewPath.append(route)
        case .settings: settingsPath.append(route)
        case .search: searchPath.append(route)
        }
    }

    public func openEditor(wordID: String? = nil, initialText: String = "") {
        editor = EditorRequest(wordID: wordID, initialText: initialText)
    }

    public func startReview(deckID: String? = nil, practice: Bool = false) {
        session = SessionRequest(deckID: deckID, practice: practice)
    }

    public func select(_ tab: AppTab) {
        selectedTab = tab
    }
}
