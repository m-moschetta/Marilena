import SwiftUI

struct EventDetailSheet: View {
    let event: CalendarEvent
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var editEventIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    Text(dateRangeString(start: event.startDate, end: event.endDate, allDay: event.isAllDay))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { calendarManager.toggleCompleted(event) }) {
                    Label(calendarManager.isCompleted(event) ? "Completato" : "Da fare",
                          systemImage: calendarManager.isCompleted(event) ? "checkmark.circle.fill" : "circle")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .foregroundColor(calendarManager.isCompleted(event) ? .green : .secondary)
                }
            }

            if let location = event.location, !location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location")
                    Text(location)
                }.font(.subheadline).foregroundColor(.secondary)
            }

            if let notes = event.description, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note").font(.subheadline.weight(.semibold))
                    Text(notes)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .lineLimit(6)
                }
                .padding(.top, 4)
            }

            Spacer()

            HStack {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: { Label("Elimina", systemImage: "trash") }
                Spacer()
                Button {
                    startEdit()
                } label: { Label("Modifica", systemImage: "pencil") }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .confirmationDialog("Eliminare l'evento?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) { Task { await deleteEvent() } }
            Button("Annulla", role: .cancel) {}
        }
        .sheet(isPresented: $showingEdit) {
            editSheet
        }
    }

    @ViewBuilder
    private var editSheet: some View {
        EventEditView(calendarManager: calendarManager, event: event)
    }

    private func startEdit() {
        showingEdit = true
    }

    private func deleteEvent() async {
        if let id = event.id ?? event.providerId {
            do {
                try await calendarManager.deleteEvent(id)
                await MainActor.run { dismiss() }
            } catch {
                // Best-effort; in futuro mostrare errore dettagliato
            }
        }
    }

    private func dateRangeString(start: Date, end: Date, allDay: Bool) -> String {
        let df = DateFormatter()
        if allDay {
            df.dateStyle = .medium; df.timeStyle = .none
            return df.string(from: start)
        } else {
            df.dateStyle = .medium; df.timeStyle = .short
            return df.string(from: start) + " – " + (DateFormatter.shortTime.string(from: end))
        }
    }
}

private extension DateFormatter {
    static var shortTime: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f
    }()
}
