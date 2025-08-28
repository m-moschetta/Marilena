import SwiftUI

struct EventEditView: View {
    @ObservedObject var calendarManager: CalendarManager
    let originalEvent: CalendarEvent
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var location: String
    @State private var isAllDay: Bool

    @State private var isSaving: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    init(calendarManager: CalendarManager, event: CalendarEvent) {
        self._calendarManager = ObservedObject(initialValue: calendarManager)
        self.originalEvent = event
        self._title = State(initialValue: event.title)
        self._description = State(initialValue: event.description ?? "")
        self._startDate = State(initialValue: event.startDate)
        self._endDate = State(initialValue: event.endDate)
        self._location = State(initialValue: event.location ?? "")
        self._isAllDay = State(initialValue: event.isAllDay)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli")) {
                    TextField("Titolo", text: $title)
                    TextField("Descrizione", text: $description, axis: .vertical).lineLimit(3...6)
                    TextField("Luogo", text: $location)
                }
                Section(header: Text("Data e Ora")) {
                    Toggle("Tutto il giorno", isOn: $isAllDay)
                        .onChange(of: isAllDay) { _, newValue in
                            if newValue {
                                let cal = Calendar.current
                                startDate = cal.startOfDay(for: startDate)
                                endDate = cal.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                            }
                        }
                    DatePicker("Inizio", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .onChange(of: startDate) { _, newValue in
                            if endDate <= newValue { endDate = newValue.addingTimeInterval(isAllDay ? 86400 : 3600) }
                        }
                    DatePicker("Fine", selection: $endDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .onChange(of: endDate) { _, newValue in
                            if newValue <= startDate { startDate = newValue.addingTimeInterval(isAllDay ? -86400 : -3600) }
                        }
                }
            }
            .navigationTitle("Modifica Evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") { Task { await save() } }.disabled(isSaving || title.isEmpty)
                }
            }
            .alert("Errore", isPresented: $showingError) { Button("OK") {} } message: { Text(errorMessage) }
        }
    }

    private func save() async {
        isSaving = true
        let updated = CalendarEvent(
            id: originalEvent.id,
            title: title,
            description: description.isEmpty ? nil : description,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            isAllDay: isAllDay,
            recurrenceRule: originalEvent.recurrenceRule,
            attendees: originalEvent.attendees,
            calendarId: originalEvent.calendarId,
            url: originalEvent.url,
            providerId: originalEvent.providerId,
            providerType: originalEvent.providerType,
            lastModified: Date()
        )
        do {
            try await calendarManager.updateEvent(updated)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; showingError = true; isSaving = false }
        }
    }
}

