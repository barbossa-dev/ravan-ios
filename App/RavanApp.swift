import AppFeature
import SwiftUI

@main
struct RavanApp: App {
    @State private var dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RavanRootView(dependencies: dependencies)
        }
    }
}
