import SwiftUI
import CoreData

struct ChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var chat: ChatMarilena

    @FetchRequest private var messaggi: FetchedResults<MessaggioMarilena>
        @State private var testo = ""
    @State private var isLoading = false
    @State private var isSearchingPerplexity = false
    
    private let openAIService = OpenAIService.shared
    private let profiloService = ProfiloUtenteService.shared
    private let perplexityService = PerplexityService.shared


    init(chat: ChatMarilena) {
        self.chat = chat
        _messaggi = FetchRequest(
            entity: MessaggioMarilena.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \MessaggioMarilena.dataCreazione, ascending: true)],
            predicate: NSPredicate(format: "chat == %@", chat)
        )
    }

    var body: some View {
        NavigationView {
            VStack {
                // Lista messaggi
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if messaggi.isEmpty {
                                welcomeView
                            } else {
                                ForEach(messaggi, id: \.objectID) { messaggio in
                                    MessageRow(messaggio: messaggio)
                                }
                            }
                            
                            if isLoading {
                                HStack {
                                    Text("Marilena sta scrivendo...")
                                        .foregroundColor(.secondary)
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messaggi.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                // Input area moderna e dinamica
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        // Campo di testo compatto che si espande
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .frame(minHeight: 28, maxHeight: testo.isEmpty ? 28 : nil)
                            
                            TextField("Scrivi un messaggio...", text: $testo, axis: .vertical)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.clear)
                                .disabled(isLoading)
                                .lineLimit(1...3)
                        }
                        .animation(.easeOut(duration: 0.15), value: testo.count)
                        
                        // Pulsante Perplexity Search
                        Button(action: searchWithPerplexity) {
                            ZStack {
                                Circle()
                                    .fill(isSearchingPerplexity ? Color.orange : Color(.systemGray5))
                                    .frame(width: 32, height: 32)
                                
                                if isSearchingPerplexity {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "globe.americas.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .disabled(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearchingPerplexity || isLoading)
                        .scaleEffect(isSearchingPerplexity ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchingPerplexity)
                        
                        // Pulsante invia moderno
                        Button(action: inviaMessaggio) {
                            ZStack {
                                Circle()
                                    .fill(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? 
                                          Color(.systemGray4) : Color.blue)
                                    .frame(width: 36, height: 36)
                                
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        .scaleEffect(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle(chat.titolo ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            // Icona moderna con gradiente
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 12) {
                Text("Ciao! Sono Marilena 👋")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("Sono la tua assistente AI personale. Inizia la conversazione scrivendo un messaggio qui sotto!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
    }

    private func inviaMessaggio() {
        guard !testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Salva messaggio utente
        let messaggioUtente = MessaggioMarilena(context: viewContext)
        messaggioUtente.id = UUID()
        messaggioUtente.contenuto = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        messaggioUtente.isUser = true
        messaggioUtente.dataCreazione = Date()
        messaggioUtente.chat = chat
        
        let messaggioTesto = testo
        testo = ""
        
        do {
            try viewContext.save()
        } catch {
            print("Errore salvataggio messaggio: \(error)")
            return
        }
        
        // Invia a OpenAI
        isLoading = true
        let conversationHistory = buildConversationHistory(newMessage: messaggioTesto)
        
        openAIService.sendMessage(
            messages: conversationHistory,
            model: UserDefaults.standard.string(forKey: "selected_model") ?? "gpt-4o-mini"
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let risposta):
                    let messaggioAI = MessaggioMarilena(context: viewContext)
                    messaggioAI.id = UUID()
                    messaggioAI.contenuto = risposta
                    messaggioAI.isUser = false
                    messaggioAI.dataCreazione = Date()
                    messaggioAI.chat = chat
                    
                    try? viewContext.save()
                    
                case .failure(let error):
                    print("Errore OpenAI: \(error)")
                    let messaggioErrore = MessaggioMarilena(context: viewContext)
                    messaggioErrore.id = UUID()
                    messaggioErrore.contenuto = "Mi dispiace, ho avuto un problema. Riprova tra poco."
                    messaggioErrore.isUser = false
                    messaggioErrore.dataCreazione = Date()
                    messaggioErrore.chat = chat
                    
                    try? viewContext.save()
                }
            }
        }
    }
    
    private func buildConversationHistory(newMessage: String) -> [OpenAIMessage] {
        var messages: [OpenAIMessage] = []
        
        // Sistema prompt con contesto utente usando PromptManager
        if let profilo = profiloService.ottieniProfiloUtente(in: viewContext),
           let contesto = profilo.contestoAI, !contesto.isEmpty {
            let systemPrompt = PromptManager.getPrompt(for: .chatBase, replacements: [
                "CONTESTO_UTENTE": contesto
            ])
            messages.append(OpenAIMessage(role: "system", content: systemPrompt))
        } else {
            let systemPrompt = PromptManager.getPrompt(for: .chatBase, replacements: [
                "CONTESTO_UTENTE": "Nessun contesto specifico disponibile"
            ])
            messages.append(OpenAIMessage(role: "system", content: systemPrompt))
        }
        
        // Aggiungi cronologia conversazione
        let messaggiRecenti = Array(messaggi.suffix(15))
        for messaggio in messaggiRecenti {
            messages.append(OpenAIMessage(
                role: messaggio.isUser ? "user" : "assistant",
                content: messaggio.contenuto ?? ""
            ))
        }
        
        // Aggiungi nuovo messaggio
        messages.append(OpenAIMessage(role: "user", content: newMessage))
        
        return messages
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messaggi.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.objectID, anchor: .bottom)
            }
        }
    }
    

    
    private func getUserContext() async -> String {
        if let profilo = profiloService.ottieniProfiloUtente(in: viewContext),
           let contesto = profilo.contestoAI, !contesto.isEmpty {
            return contesto
        }
        return ""
    }
    
    // MARK: - Perplexity Search
    
    private func searchWithPerplexity() {
        let query = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        // Aggiungi il messaggio dell'utente
        let userMessage = MessaggioMarilena(context: viewContext)
        userMessage.id = UUID()
        userMessage.contenuto = query
        userMessage.isUser = true
        userMessage.dataCreazione = Date()
        userMessage.chat = chat
        
        // Svuota il campo di testo
        testo = ""
        
        // Inizia la ricerca
        isSearchingPerplexity = true
        
        Task {
            do {
                let selectedModel = UserDefaults.standard.string(forKey: "selected_perplexity_model") ?? "sonar-pro"
                let searchResult = try await perplexityService.search(query: query, model: selectedModel)
                
                await MainActor.run {
                    // Aggiungi la risposta di Perplexity
                    let perplexityMessage = MessaggioMarilena(context: viewContext)
                    perplexityMessage.id = UUID()
                    perplexityMessage.contenuto = "🌐 **Ricerca Perplexity**\n\n\(searchResult)"
                    perplexityMessage.isUser = false
                    perplexityMessage.dataCreazione = Date()
                    perplexityMessage.chat = chat
                    
                    do {
                        try viewContext.save()
                    } catch {
                        print("Errore nel salvare i messaggi: \(error)")
                    }
                    
                    isSearchingPerplexity = false
                }
                
            } catch {
                await MainActor.run {
                    // Aggiungi messaggio di errore
                    let errorMessage = MessaggioMarilena(context: viewContext)
                    errorMessage.id = UUID()
                    errorMessage.contenuto = "❌ **Errore nella ricerca Perplexity**\n\n\(error.localizedDescription)"
                    errorMessage.isUser = false
                    errorMessage.dataCreazione = Date()
                    errorMessage.chat = chat
                    
                    do {
                        try viewContext.save()
                    } catch {
                        print("Errore nel salvare il messaggio di errore: \(error)")
                    }
                    
                    isSearchingPerplexity = false
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    

}

struct MessageRow: View {
    let messaggio: MessaggioMarilena
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if messaggio.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(messaggio.contenuto ?? "")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    if let data = messaggio.dataCreazione {
                        Text(data, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 4)
                    }
                }
                .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
                
            } else {
                // Avatar moderno con gradiente
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Text("M")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(messaggio.contenuto ?? "")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                        )
                        .foregroundColor(.primary)
                    
                    if let data = messaggio.dataCreazione {
                        Text(data, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
                .frame(maxWidth: .infinity * 0.75, alignment: .leading)
                
                Spacer()
            }
        }
        .id(messaggio.objectID)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let chat = ChatMarilena(context: context)
    chat.id = UUID()
    chat.titolo = "Chat di Prova"
    chat.dataCreazione = Date()
    
    return ChatView(chat: chat)
        .environment(\.managedObjectContext, context)
} 

