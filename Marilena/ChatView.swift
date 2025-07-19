import SwiftUI
import CoreData

struct ChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var chat: ChatMarilena

    @FetchRequest private var messaggi: FetchedResults<MessaggioMarilena>
    @State private var testo = ""
    @State private var isLoading = false
    private let openAIService = OpenAIService.shared
    private let profiloService = ProfiloUtenteService.shared

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
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        // Campo di testo dinamico
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .frame(minHeight: 44, maxHeight: 120)
                            
                            TextField("Scrivi un messaggio...", text: $testo, axis: .vertical)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .disabled(isLoading)
                                .lineLimit(1...5)
                                .onChange(of: testo) { _ in
                                    // Scroll automatico quando il testo cresce
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            // Forza il refresh della UI
                                        }
                                    }
                                }
                        }
                        
                        // Pulsante invia moderno
                        Button(action: inviaMessaggio) {
                            ZStack {
                                Circle()
                                    .fill(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? 
                                          Color(.systemGray4) : Color.blue)
                                    .frame(width: 44, height: 44)
                                
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        .scaleEffect(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
        
        // Sistema prompt con contesto utente
        if let profilo = profiloService.ottieniProfiloUtente(in: viewContext),
           let contesto = profilo.contestoAI, !contesto.isEmpty {
            messages.append(OpenAIMessage(
                role: "system",
                content: """
                Sei Marilena, un'assistente AI personale amichevole e utile. 
                
                Contesto dell'utente:
                \(contesto)
                
                Rispondi sempre in italiano e mantieni un tono cordiale e professionale.
                """
            ))
        } else {
            messages.append(OpenAIMessage(
                role: "system",
                content: "Sei Marilena, un'assistente AI personale amichevole e utile. Rispondi sempre in italiano."
            ))
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
