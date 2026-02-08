import SwiftUI

/// Dettaglio rapido per un evento del nuovo calendario.
struct EventDetailView: View {
    @ObservedObject var calendarService: NewCalendarService
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                if let event = calendarService.selectedEvent {
                    Text(event.title)
                        .font(.headline)
                    Text(event.formattedTimeRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }
                    if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .padding(.top, 4)
                    }
                } else {
                    Text("Nessun evento selezionato")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Dettagli evento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        calendarService.showingEventDetail = false
                    }
                }
            }
        }
    }
}
