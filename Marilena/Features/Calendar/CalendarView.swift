import SwiftUI
import EventKit
import UniformTypeIdentifiers

// MARK: - Calendar View
// Nuovo calendario ispirato a Fantastical

struct CalendarView: View {

    @StateObject private var calendarManager = CalendarManager()

    var body: some View {
        // Nuovo calendario Fantastical-style
        NewCalendarView(calendarManager: calendarManager)
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    CalendarView()
}
