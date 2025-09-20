import Foundation

public struct DateHelper {
    public static func date(year: Int, month: Int, day: Int) -> Date {
        return DateComponents(calendar: .current, year: year, month: month, day: day).date ?? Date()
    }

    public static func date(year: Int, month: Int) -> Date {
        return DateComponents(calendar: .current, year: year, month: month).date ?? Date()
    }
}