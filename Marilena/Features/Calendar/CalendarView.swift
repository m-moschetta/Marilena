import SwiftUI
import EventKit
import UniformTypeIdentifiers

// MARK: - Calendar View
// Interfaccia principale per la gestione del calendario

struct CalendarView: View {
    
    @StateObject private var calendarManager = CalendarManager()
    @State private var showingCreateEvent = false
    @State private var showingServicePicker = false
    @State private var naturalLanguageInput = ""
    @State private var showingNaturalLanguageInput = false
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Header con informazioni servizio
            serviceHeaderView
            
            // Buttons principali
            actionButtonsView
            
            // Lista eventi
            if calendarManager.isLoading {
                loadingView
            } else if calendarManager.events.isEmpty {
                emptyStateView
            } else {
                eventsListView
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Calendario")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Impostazioni") {
                    showingServicePicker = true
                }
            }
        }
        .alert("Errore", isPresented: .constant(calendarManager.error != nil)) {
            Button("OK") {
                calendarManager.error = nil
            }
        } message: {
            Text(calendarManager.error ?? "")
        }
        .sheet(isPresented: $showingServicePicker) {
            ServicePickerView(calendarManager: calendarManager)
        }
        .sheet(isPresented: $showingCreateEvent) {
            CreateEventView(calendarManager: calendarManager)
        }
        .sheet(isPresented: $showingNaturalLanguageInput) {
            NaturalLanguageEventView(calendarManager: calendarManager)
        }
        .task {
            await initializeCalendar()
        }
    }
    
    // MARK: - Service Header
    
    private var serviceHeaderView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Servizio Attivo:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack {
                Text(calendarManager.currentService?.providerName ?? "Nessuno")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Circle()
                    .fill(calendarManager.currentService?.isAuthenticated == true ? .green : .red)
                    .frame(width: 12, height: 12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            
            // Smart Assistant Button
            Button(action: {
                showingNaturalLanguageInput = true
            }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("Crea Evento con AI")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            HStack(spacing: 12) {
                // Create Event Button
                Button(action: {
                    showingCreateEvent = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Nuovo Evento")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Refresh Button
                Button(action: {
                    Task {
                        await calendarManager.loadEvents()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Aggiorna")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
            Text("Caricamento eventi...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Nessun evento")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Crea il tuo primo evento usando l'assistente AI o il pulsante Nuovo Evento")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Events List
    
    private var eventsListView: some View {
        VStack(spacing: 16) {
            // Sezione Da fare
            reminderSection(title: "Da fare", events: calendarManager.incompleteEvents)
            // Sezione Completati
            reminderSection(title: "Completati", events: calendarManager.completedEvents)
        }
    }

    // MARK: - Reminder Section
    private func reminderSection(title: String, events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if title == "Completati" {
                    Text("\(events.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if events.isEmpty {
                Text(title == "Completati" ? "Nessun promemoria completato" : "Nessun promemoria")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(events) { event in
                            ReminderRow(event: event, manager: calendarManager)
                                .onDrag {
                                    NSItemProvider(object: NSString(string: calendarManager.eventKey(for: event)))
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 280)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers in
                    // Gestione drop tra sezioni: toggle completed se cade nella sezione opposta
                    handleDrop(intoSectionTitle: title, providers: providers)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    private func handleDrop(intoSectionTitle title: String, providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let nsString = object as? NSString else { return }
                    let keyString = nsString as String
                    DispatchQueue.main.async {
                        if let event = calendarManager.eventForKey(keyString) {
                            let isCompleted = calendarManager.isCompleted(event)
                            if (title == "Da fare" && isCompleted) || (title == "Completati" && !isCompleted) {
                                calendarManager.toggleCompleted(event)
                            }
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
    
    // MARK: - Helper Methods
    
    private func initializeCalendar() async {
        // Il servizio preferito è già configurato nel CalendarManager
        if let service = calendarManager.currentService, !service.isAuthenticated {
            await calendarManager.setService(.eventKit) // Default a EventKit
        }
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: CalendarEvent
    let calendarManager: CalendarManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = event.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.startDate, style: .time)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if event.isHappening {
                        Text("In corso")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    } else if event.isFuture {
                        Text("Futuro")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            }
            
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(event.startDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let location = event.location {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(event.providerType.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Reminder Row
struct ReminderRow: View {
    let event: CalendarEvent
    let manager: CalendarManager
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: { manager.toggleCompleted(event) }) {
                Image(systemName: manager.isCompleted(event) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(manager.isCompleted(event) ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .strikethrough(manager.isCompleted(event), color: .secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(event.startDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(event.startDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let location = event.location, !location.isEmpty {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            
            Text(event.providerType.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    CalendarView()
}