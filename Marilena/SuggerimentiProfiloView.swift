import SwiftUI
import CoreData

struct SuggerimentiProfiloView: View {
    let profilo: ProfiloUtente
    @State private var suggerimenti: [SuggerimentoContesto] = []
    @State private var tendenzaMessaggi: TendenzaMessaggi?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                
                Text("Suggerimenti")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !suggerimenti.isEmpty {
                    Text("\(suggerimenti.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            
            // Tendenza messaggi
            if let tendenza = tendenzaMessaggi {
                TendenzaMessaggiCard(tendenza: tendenza)
            }
            
            // Lista suggerimenti
            if suggerimenti.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Profilo Completo!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Il tuo profilo è completo e aggiornato")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(suggerimenti.indices, id: \.self) { index in
                    SuggerimentoCard(
                        suggerimento: suggerimenti[index],
                        profilo: profilo
                    ) {
                        // Rimuovi suggerimento completato
                        suggerimenti.remove(at: index)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .onAppear {
            caricaSuggerimenti()
        }
    }
    
    private func caricaSuggerimenti() {
        suggerimenti = ContestoAIService.shared.generaSuggerimentiContesto(profilo: profilo)
        tendenzaMessaggi = ContestoAIService.shared.analizzaTendenzaMessaggi(profilo: profilo)
    }
}

// MARK: - Card Tendenza Messaggi
struct TendenzaMessaggiCard: View {
    let tendenza: TendenzaMessaggi
    
    var body: some View {
        HStack(spacing: 12) {
            // Indicatore colorato
            Circle()
                .fill(Color(tendenza.tipo.colore))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tendenza.tipo.descrizione)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.1f", tendenza.mediaGiornaliera)) messaggi/giorno")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(tendenza.messaggiRecenti)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("ultimi 7gg")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Card Suggerimento
struct SuggerimentoCard: View {
    let suggerimento: SuggerimentoContesto
    let profilo: ProfiloUtente
    let onCompleted: () -> Void
    
    @State private var showingAction = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icona priorità
            Image(systemName: suggerimento.priorita.icona)
                .font(.title3)
                .foregroundColor(Color(suggerimento.priorita.colore))
                .frame(width: 24)
            
            // Contenuto
            VStack(alignment: .leading, spacing: 4) {
                Text(suggerimento.titolo)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(suggerimento.descrizione)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Pulsante azione
            Button(action: {
                eseguiAzione()
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingAction) {
            NavigationView {
                vistaPerAzione()
                    .navigationTitle(suggerimento.titolo)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Chiudi") {
                                showingAction = false
                                onCompleted()
                            }
                        }
                    }
            }
        }
    }
    
    private func eseguiAzione() {
        switch suggerimento.tipo {
        case .aggiornamentoContesto:
            // Aggiorna contesto AI
            profilo.dataUltimoAggiornamentoContesto = Date()
            profilo.contestoAI = "Contesto aggiornato automaticamente"
            
            do {
                try profilo.managedObjectContext?.save()
                onCompleted()
            } catch {
                print("Errore aggiornamento contesto: \(error)")
            }
            
        case .completaProfilo, .aggiungiFoto:
            showingAction = true
        }
    }
    
    @ViewBuilder
    private func vistaPerAzione() -> some View {
        switch suggerimento.tipo {
        case .completaProfilo, .aggiungiFoto:
            ModificaProfiloView(profilo: profilo)
            
        case .aggiornamentoContesto:
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Contesto Aggiornato!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Il tuo profilo è stato aggiornato con le conversazioni recenti")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Continua") {
                    showingAction = false
                    onCompleted()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let profilo = ProfiloUtenteService.shared.creaProfiloDefault(in: context)
    SuggerimentiProfiloView(profilo: profilo)
} 