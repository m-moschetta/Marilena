import Foundation

enum DefaultEventDuration: Int, CaseIterable {
    case m15 = 15
    case m30 = 30
    case m60 = 60
}

enum CalendarPreferences {
    private static let defaultDurationKey = "CalendarDefaultEventDurationMinutes"

    static var defaultDurationMinutes: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: defaultDurationKey)
            return value > 0 ? value : 30
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultDurationKey)
        }
    }
}

