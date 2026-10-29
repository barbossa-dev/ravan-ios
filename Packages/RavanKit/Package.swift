// swift-tools-version: 6.2
import PackageDescription

/// Domain + data targets: Swift 6 language mode, nothing is implicitly main-actor.
let core: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
]

/// SwiftUI targets run on the main actor by default (Swift 6.2 approachable concurrency).
let ui: [SwiftSetting] = core + [.defaultIsolation(MainActor.self)]

let features = ["FeatureHome", "FeatureWord", "FeatureEditor", "FeatureLibrary", "FeatureReview", "FeatureSettings"]

let package = Package(
    name: "RavanKit",
    defaultLocalization: "fa",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "RavanModel", targets: ["RavanModel"]),
    ],
    targets: [
        // Layer 1 — pure domain: value types, Leitner scheduler, backup format.
        .target(name: "RavanModel", swiftSettings: core),

        // Layer 2 — infrastructure.
        .target(
            name: "RavanData",
            dependencies: ["RavanModel"],
            resources: [.process("Resources")],
            swiftSettings: core
        ),
        .target(name: "RavanSpeech", dependencies: ["RavanModel"], swiftSettings: core),

        // Layer 3 — design system and shared UI.
        .target(name: "RavanDesign", swiftSettings: ui),
        .target(
            name: "RavanUI",
            dependencies: ["RavanModel", "RavanData", "RavanSpeech", "RavanDesign"],
            swiftSettings: ui
        ),

        // Layer 4 — features (never depend on each other).
        .target(name: "FeatureHome", dependencies: ["RavanUI"], swiftSettings: ui),
        .target(name: "FeatureWord", dependencies: ["RavanUI"], swiftSettings: ui),
        .target(name: "FeatureEditor", dependencies: ["RavanUI"], swiftSettings: ui),
        .target(name: "FeatureLibrary", dependencies: ["RavanUI"], swiftSettings: ui),
        .target(name: "FeatureReview", dependencies: ["RavanUI"], swiftSettings: ui),
        .target(name: "FeatureSettings", dependencies: ["RavanUI"], swiftSettings: ui),

        // Layer 5 — composition root: tabs, navigation, dependency wiring.
        .target(
            name: "AppFeature",
            dependencies: ["RavanUI"] + features.map { .target(name: $0) },
            swiftSettings: ui
        ),

        .testTarget(name: "RavanModelTests", dependencies: ["RavanModel"], swiftSettings: core),
    ]
)
