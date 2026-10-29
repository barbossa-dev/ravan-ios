import RavanUI
import SwiftData

/// Composition root: creates every long-lived object once and hands them to the view tree.
@MainActor
public final class AppDependencies {
    public let store: DictionaryStore
    public let settings: SettingsStore
    public let pronouncer: Pronouncer
    public let router: AppRouter

    public init(container: ModelContainer, settings: SettingsStore = SettingsStore()) {
        self.store = DictionaryStore(container: container)
        self.settings = settings
        self.pronouncer = Pronouncer()
        self.router = AppRouter()
    }

    /// The real app: on-disk SwiftData store.
    public static func live() -> AppDependencies {
        do {
            return AppDependencies(container: try RavanSchema.makeContainer())
        } catch {
            fatalError("Could not open the Ravan database: \(error)")
        }
    }

    /// SwiftUI previews and UI tests: in-memory store.
    public static func preview() -> AppDependencies {
        do {
            return AppDependencies(container: try RavanSchema.makeContainer(inMemory: true))
        } catch {
            fatalError("Could not create the in-memory database: \(error)")
        }
    }
}
