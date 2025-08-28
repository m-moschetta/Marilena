import SwiftUI

// MARK: - Create Event View
// View per creare manualmente un nuovo evento

struct CreateEventView: View {
    
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss
    
    // Form data
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(TimeInterval(CalendarPreferences.defaultDurationMinutes * 60))
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var attendeeEmails: String = ""
    
    // UI states
    @State private var isCreating: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                
                // Basic Information Section
                Section(header: Text("Informazioni Base")) {
                    TextField("Titolo evento", text: $title)
                    
                    TextField("Descrizione (opzionale)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Luogo (opzionale)", text: $location)
                }
                
                // Date and Time Section
                Section(header: Text("Data e Ora")) {
                    Toggle("Tutto il giorno", isOn: $isAllDay)
                        .onChange(of: isAllDay) { oldValue, newValue in
                            if newValue {
                                // Per eventi tutto il giorno, imposta orari di default
                                let calendar = Calendar.current
                                startDate = calendar.startOfDay(for: startDate)
                                endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                            }
                        }
                    
                    DatePicker("Inizio", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .onChange(of: startDate) { oldValue, newValue in
                            // Assicurati che la data di fine sia sempre dopo l'inizio
                            if endDate <= newValue {
                                endDate = newValue.addingTimeInterval(isAllDay ? 86400 : 3600) // 1 day or 1 hour
                            }
                        }
                    
                    DatePicker("Fine", selection: $endDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .onChange(of: endDate) { oldValue, newValue in
                            // Assicurati che la data di fine sia sempre dopo l'inizio
                            if newValue <= startDate {
                                startDate = newValue.addingTimeInterval(isAllDay ? -86400 : -3600) // 1 day or 1 hour before
                            }
                        }
                }
                
                // Attendees Section
                Section(header: Text("Partecipanti"), footer: Text("Inserisci gli indirizzi email dei partecipanti separati da virgole")) {
                    TextField("Email partecipanti (separate da virgola)", text: $attendeeEmails, axis: .vertical)
                        .lineLimit(2...4)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                // Service Info Section
                Section(header: Text("Servizio")) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text(calendarManager.currentService?.providerName ?? "Nessun servizio")
                        Spacer()
                        Circle()
                            .fill(calendarManager.currentService?.isAuthenticated == true ? .green : .red)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .navigationTitle("Nuovo Evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        Task {
                            await createEvent()
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
            .alert("Errore", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // Custom initializer to prefill suggested values (e.g., from DayTimeline selection)
    init(calendarManager: CalendarManager, suggestedStart: Date? = nil, suggestedEnd: Date? = nil, suggestedTitle: String? = nil) {
        self._calendarManager = ObservedObject(initialValue: calendarManager)
        let now = Date()
        let start = suggestedStart ?? now
        let end = suggestedEnd ?? start.addingTimeInterval(TimeInterval(CalendarPreferences.defaultDurationMinutes * 60))
        self._startDate = State(initialValue: start)
        self._endDate = State(initialValue: end > start ? end : start.addingTimeInterval(TimeInterval(CalendarPreferences.defaultDurationMinutes * 60)))
        self._title = State(initialValue: suggestedTitle ?? "")
        self._description = State(initialValue: "")
        self._location = State(initialValue: "")
    }
    
    // MARK: - Helper Methods
    
    private func createEvent() async {
        guard !title.isEmpty else { return }
        
        isCreating = true
        
        do {
            let attendeeEmailArray = attendeeEmails
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let eventRequest = CalendarEventRequest(
                title: title,
                description: description.isEmpty ? nil : description,
                startDate: startDate,
                endDate: endDate,
                location: location.isEmpty ? nil : location,
                isAllDay: isAllDay,
                attendeeEmails: attendeeEmailArray
            )
            
            let _ = try await calendarManager.createEvent(eventRequest)
            
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isCreating = false
            }
        }
    }
    
    private var isFormValid: Bool {
        !title.isEmpty && endDate > startDate
    }
}

#Preview {
    CreateEventView(calendarManager: CalendarManager())
}
