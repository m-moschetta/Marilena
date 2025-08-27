import SwiftUI

// MARK: - Natural Language Event View
// View per creare eventi usando linguaggio naturale (AI Assistant)

struct NaturalLanguageEventView: View {
    
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingPreview: Bool = false
    @State private var parsedEvent: CalendarEvent?
    
    // Esempi di input
    private let exampleInputs = [
        "Riunione di team domani alle 15:00",
        "Pranzo con cliente venerdì alle 12:30",
        "Conferenza importante lunedì prossimo dalle 9 alle 17",
        "Call con fornitori giovedì alle 14:00 per 2 ore",
        "Presentazione progetto martedì alle 10:30"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Assistente AI Calendario")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Descrivi il tuo evento in linguaggio naturale e l'AI creerà automaticamente l'appuntamento")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cosa vuoi programmare?")
                        .font(.headline)
                    
                    TextField("Es: Riunione di team domani alle 15:00", text: $inputText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .submitLabel(.done)
                        .onSubmit {
                            if !inputText.isEmpty {
                                Task {
                                    await processNaturalLanguage()
                                }
                            }
                        }
                    
                    if inputText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Esempi:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ForEach(exampleInputs.prefix(3), id: \.self) { example in
                                Button(action: {
                                    inputText = example
                                }) {
                                    Text("• \(example)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Action Button
                Button(action: {
                    Task {
                        await processNaturalLanguage()
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isProcessing ? "Elaborazione..." : "Crea Evento con AI")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(inputText.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(inputText.isEmpty || isProcessing)
                
                // Service Info
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Gli eventi verranno creati in: \(calendarManager.currentService?.providerName ?? "Nessun servizio")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Spacer()
                
            }
            .padding()
            .navigationTitle("Assistente AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .alert("Errore", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func processNaturalLanguage() async {
        guard !inputText.isEmpty else { return }
        
        isProcessing = true
        
        do {
            let _ = try await calendarManager.createEventFromText(inputText)
            
            await MainActor.run {
                // Mostra feedback di successo
                inputText = ""
                isProcessing = false
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Errore durante la creazione dell'evento: \(error.localizedDescription)"
                showingError = true
                isProcessing = false
            }
        }
    }
}

#Preview {
    NaturalLanguageEventView(calendarManager: CalendarManager())
}