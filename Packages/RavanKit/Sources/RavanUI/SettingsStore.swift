import Foundation
import Observation
import RavanModel
import SwiftUI

/// User preferences, persisted in UserDefaults.
@MainActor
@Observable
public final class SettingsStore {
    public var theme: ThemePreference { didSet { defaults.set(theme.rawValue, forKey: Keys.theme) } }
    public var accent: Accent { didSet { defaults.set(accent.rawValue, forKey: Keys.accent) } }
    /// 0.5 … 1.5
    public var speechRate: Double { didSet { defaults.set(speechRate, forKey: Keys.speechRate) } }
    public var autoPronounce: Bool { didSet { defaults.set(autoPronounce, forKey: Keys.autoPronounce) } }
    public var reviewDirection: ReviewDirection { didSet { defaults.set(reviewDirection.rawValue, forKey: Keys.direction) } }
    public var dailyGoal: Int { didSet { defaults.set(dailyGoal, forKey: Keys.dailyGoal) } }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = ThemePreference(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        accent = Accent(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .us
        speechRate = defaults.object(forKey: Keys.speechRate) as? Double ?? 0.9
        autoPronounce = defaults.object(forKey: Keys.autoPronounce) as? Bool ?? true
        reviewDirection = ReviewDirection(rawValue: defaults.string(forKey: Keys.direction) ?? "") ?? .englishToPersian
        dailyGoal = defaults.object(forKey: Keys.dailyGoal) as? Int ?? 20
    }

    public var colorScheme: ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private enum Keys {
        static let theme = "settings.theme"
        static let accent = "settings.accent"
        static let speechRate = "settings.speechRate"
        static let autoPronounce = "settings.autoPronounce"
        static let direction = "settings.reviewDirection"
        static let dailyGoal = "settings.dailyGoal"
    }
}
