import SwiftUI

// MARK: - Service Picker View
// View per scegliere il servizio calendario da utilizzare

struct ServicePickerView: View {
    
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedServiceType: CalendarServiceType = .eventKit
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.gearshape")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Scegli Servizio Calendario")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Seleziona il provider per gestire i tuoi eventi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Service Options
                VStack(spacing: 16) {
                    ForEach(CalendarServiceType.allCases, id: \.self) { serviceType in
                        ServiceOptionView(
                            serviceType: serviceType,
                            isSelected: selectedServiceType == serviceType,
                            isAvailable: isServiceAvailable(serviceType)
                        ) {
                            selectedServiceType = serviceType
                        }
                    }
                }
                .padding(.horizontal)
                
                // Preferences
                PreferencesSection()
                    .padding(.horizontal)
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Salva e Configura") {
                        Task {
                            await configureService()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(calendarManager.isLoading)
                    
                    Button("Annulla") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Servizi Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Imposta il servizio attualmente attivo come selezionato
            if let currentService = calendarManager.currentService {
                selectedServiceType = currentService.serviceType
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isServiceAvailable(_ serviceType: CalendarServiceType) -> Bool {
        switch serviceType {
        case .eventKit:
            return true // EventKit è sempre disponibile
        case .googleCalendar:
            // Verifica se l'utente è loggato con Google
            return true // Per ora sempre disponibile per test
        case .microsoftGraph:
            return false // Non ancora implementato
        }
    }
    
    private func configureService() async {
        await calendarManager.setService(selectedServiceType)
        await MainActor.run {
            dismiss()
        }
    }
}

// MARK: - Service Option View

struct ServiceOptionView: View {
    let serviceType: CalendarServiceType
    let isSelected: Bool
    let isAvailable: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            if isAvailable {
                onSelect()
            }
        }) {
            HStack(spacing: 16) {
                
                // Icon
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isAvailable ? .blue : .gray)
                    .frame(width: 32)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(serviceType.displayName)
                        .font(.headline)
                        .foregroundColor(isAvailable ? .primary : .gray)
                    
                    Text(serviceDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected && isAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else if !isAvailable {
                    Text("Non disponibile")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected && isAvailable ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected && isAvailable ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .disabled(!isAvailable)
    }
    
    private var iconName: String {
        switch serviceType {
        case .eventKit:
            return "calendar"
        case .googleCalendar:
            return "globe"
        case .microsoftGraph:
            return "building.2"
        }
    }
    
    private var serviceDescription: String {
        switch serviceType {
        case .eventKit:
            return "Usa i calendari configurati sul dispositivo (iCloud, Google, Exchange, ecc.)"
        case .googleCalendar:
            return "Accesso diretto a Google Calendar con funzionalità avanzate"
        case .microsoftGraph:
            return "Integrazione con Microsoft 365 e Outlook (Enterprise)"
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ServicePickerView(calendarManager: CalendarManager())
}

// MARK: - Preferences Section

private struct PreferencesSection: View {
    @State private var defaultDuration: Int = CalendarPreferences.defaultDurationMinutes

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferenze")
                .font(.headline)
            HStack {
                Text("Durata predefinita nuovo evento")
                Spacer()
                Picker("Durata", selection: $defaultDuration) {
                    Text("15m").tag(15)
                    Text("30m").tag(30)
                    Text("60m").tag(60)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .onChange(of: defaultDuration) { _, newValue in
                CalendarPreferences.defaultDurationMinutes = newValue
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6))
        )
    }
}
