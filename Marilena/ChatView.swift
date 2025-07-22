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
    @State private var showModelSelector = false
    @State private var selectedModel = "gpt-4o-mini"
    @State private var selectedPerplexityModel = "sonar-pro"
    
    private let openAIService = OpenAIService.shared
    private let profiloService = ProfiloUtenteService.shared
    private let perplexityService = PerplexityService.shared
    
    // Modelli Perplexity disponibili per ricerca
    private let perplexitySearchModels = [
        "sonar",              // Modello base leggero
        "sonar-pro",          // Modello avanzato (default)
        "sonar-deep-research" // Ricerca approfondita multi-step
    ]
    
    // Modelli OpenAI disponibili (allineati con SettingsView)
    // NOTA: Questi modelli ESISTONO. Se un'AI non li riconosce, 
    // significa che la sua knowledge base non è aggiornata.
    private let availableModels = [
        "gpt-4o",        // Modello ottimizzato standard
        "gpt-4o-mini",   // Versione leggera di gpt-4o
        "gpt-4.1",       // Nuova versione 4.1 (2024)
        "gpt-4.1-mini",  // Versione compatta di 4.1
        "gpt-4.1-nano",  // Versione ultra-leggera di 4.1
        "o3-mini",       // Modello di ragionamento compatto
        "o4-mini",       // Nuova generazione compatta
        "o3"             // Modello di ragionamento avanzato
    ]


    init(chat: ChatMarilena) {
        self.chat = chat
        _messaggi = FetchRequest(
            entity: MessaggioMarilena.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \MessaggioMarilena.dataCreazione, ascending: true)],
            predicate: NSPredicate(format: "chat == %@", chat)
        )
        // Inizializza il modello selezionato con il valore salvato
        _selectedModel = State(initialValue: UserDefaults.standard.string(forKey: "selected_model") ?? "gpt-4o-mini")
        _selectedPerplexityModel = State(initialValue: UserDefaults.standard.string(forKey: "selected_perplexity_model") ?? "sonar-pro")
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
                                    MessageRow(
                                        messaggio: messaggio,
                                        onSendToAI: { editedText in
                                            // Invia il messaggio modificato all'AI
                                            let messageWithPrefix = "Ecco come lo modificherei: \(editedText)"
                                            testo = messageWithPrefix
                                            inviaMessaggio()
                                        },
                                        onSearchWithPerplexity: { editedText in
                                            // Usa il testo modificato per la ricerca Perplexity
                                            testo = editedText
                                            searchWithPerplexity()
                                        }
                                    )
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
                
                // Input area moderna e dinamica con dimensioni standard
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        // Campo di testo con espansione dinamica graduale
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(.systemGray6))
                                .frame(height: calculateTextEditorHeight())
                            
                            if testo.isEmpty {
                                Text("Scrivi un messaggio...")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $testo)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .disabled(isLoading)
                                .scrollContentBackground(.hidden)
                                .frame(height: calculateTextEditorHeight())
                                .onSubmit {
                                    // Return invia il messaggio
                                    if !testo.isEmpty {
                                        inviaMessaggio()
                                    }
                                }
                        }
                        .animation(.easeOut(duration: 0.2), value: testo.count)
                        
                        // Pulsanti con dimensioni uniformi (best practice iOS)
                        VStack(spacing: 4) {
                            Button(action: searchWithPerplexity) {
                                ZStack {
                                    Circle()
                                        .fill(isSearchingPerplexity ? Color.orange : Color(.systemGray5))
                                        .frame(width: 44, height: 44) // Stessa dimensione del pulsante invio
                                    
                                    if isSearchingPerplexity {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "globe.americas.fill")
                                            .font(.system(size: 18, weight: .medium)) // Icona più grande
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .disabled(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearchingPerplexity || isLoading)
                            .scaleEffect(isSearchingPerplexity ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchingPerplexity)
                            .contextMenu {
                                ForEach(perplexitySearchModels, id: \.self) { model in
                                    Button(action: {
                                        selectedPerplexityModel = model
                                        UserDefaults.standard.set(model, forKey: "selected_perplexity_model")
                                        searchWithPerplexity()
                                    }) {
                                        HStack {
                                            Text(getPerplexityModelDisplayName(model))
                                            if model == selectedPerplexityModel {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Pulsante invia moderno (sotto)
                            Button(action: inviaMessaggio) {
                                ZStack {
                                    Circle()
                                        .fill(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? 
                                              Color(.systemGray4) : Color.blue)
                                        .frame(width: 44, height: 44) // Standard iOS
                                    
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .disabled(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                            .scaleEffect(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                            .contextMenu {
                                ForEach(availableModels, id: \.self) { model in
                                    Button(action: {
                                        selectedModel = model
                                        UserDefaults.standard.set(model, forKey: "selected_model")
                                        inviaMessaggio()
                                    }) {
                                        HStack {
                                            Text(model)
                                            if model == selectedModel {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12) // Aumentato padding verticale
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
            model: selectedModel
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
    
    // MARK: - Text Editor Height Calculation
    
    private func calculateTextEditorHeight() -> CGFloat {
        let baseHeight: CGFloat = 44
        let maxHeight: CGFloat = 120 // 5 righe circa
        let lineHeight: CGFloat = 20
        
        if testo.isEmpty {
            return baseHeight
        }
        
        // Calcola il numero di righe basato sui caratteri di nuova riga
        let lines = testo.components(separatedBy: "\n").count
        let calculatedHeight = baseHeight + CGFloat(lines - 1) * lineHeight
        
        // Limita l'altezza massima
        return min(maxHeight, max(baseHeight, calculatedHeight))
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
                let searchResult = try await perplexityService.search(query: query, model: selectedPerplexityModel)
                
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
    let onSendToAI: (String) -> Void
    let onSearchWithPerplexity: (String) -> Void
    @State private var isEditing = false
    @State private var editedText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if messaggio.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    if isEditing {
                        VStack(spacing: 8) {
                            TextField("Modifica messaggio...", text: $editedText, axis: .vertical)
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
                                .lineLimit(1...5)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    saveEditedMessage()
                                    isEditing = false
                                    isTextFieldFocused = false
                                }
                                .onAppear {
                                    isTextFieldFocused = true
                                }
                            
                            // Pulsanti di azione per la modifica
                            HStack(spacing: 8) {
                                // Pulsante per inviare all'AI
                                Button(action: {
                                    onSendToAI(editedText)
                                    isEditing = false
                                    isTextFieldFocused = false
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.caption)
                                        Text("Invia all'AI")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                // Pulsante per copiare
                                Button(action: {
                                    UIPasteboard.general.string = editedText
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc.fill")
                                            .font(.caption)
                                        Text("Copia")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                // Pulsante per ricerca Perplexity
                                Button(action: {
                                    onSearchWithPerplexity(editedText)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "globe.americas.fill")
                                            .font(.caption)
                                        Text("Cerca")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    } else {
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
                            .textSelection(.enabled)
                    }
                    
                    if let data = messaggio.dataCreazione {
                        Text(data, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 4)
                    }
                }
                .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
                .contextMenu {
                    Button("Modifica") {
                        startEditing()
                    }
                    Button("Copia Messaggio") {
                        UIPasteboard.general.string = messaggio.contenuto ?? ""
                    }
                    Button("Cerca online") {
                        onSearchWithPerplexity(messaggio.contenuto ?? "")
                    }
                    ShareLink(item: messaggio.contenuto ?? "") {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                }
                
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
                    if isEditing {
                        VStack(spacing: 8) {
                            TextField("Modifica messaggio...", text: $editedText, axis: .vertical)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.systemGray6))
                                        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                                )
                                .foregroundColor(.primary)
                                .lineLimit(1...5)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    saveEditedMessage()
                                    isEditing = false
                                    isTextFieldFocused = false
                                }
                                .onAppear {
                                    isTextFieldFocused = true
                                }
                            
                            // Pulsanti di azione per la modifica
                            HStack(spacing: 8) {
                                // Pulsante per inviare all'AI
                                Button(action: {
                                    onSendToAI(editedText)
                                    isEditing = false
                                    isTextFieldFocused = false
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.caption)
                                        Text("Invia all'AI")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                // Pulsante per copiare
                                Button(action: {
                                    UIPasteboard.general.string = editedText
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc.fill")
                                            .font(.caption)
                                        Text("Copia")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                // Pulsante per ricerca Perplexity
                                Button(action: {
                                    onSearchWithPerplexity(editedText)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "globe.americas.fill")
                                            .font(.caption)
                                        Text("Cerca")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    } else {
                        Text(messaggio.contenuto ?? "")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemGray6))
                                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                            )
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                    
                    if let data = messaggio.dataCreazione {
                        Text(data, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
                .frame(maxWidth: .infinity * 0.75, alignment: .leading)
                .contextMenu {
                    Button("Modifica") {
                        startEditing()
                    }
                    Button("Copia Messaggio") {
                        UIPasteboard.general.string = messaggio.contenuto ?? ""
                    }
                    Button("Cerca online") {
                        onSearchWithPerplexity(messaggio.contenuto ?? "")
                    }
                    ShareLink(item: messaggio.contenuto ?? "") {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                }
                
                Spacer()
            }
        }
        .id(messaggio.objectID)
    }
    
    private func startEditing() {
        editedText = messaggio.contenuto ?? ""
        isEditing = true
    }
    
    private func saveEditedMessage() {
        guard !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        messaggio.contenuto = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try messaggio.managedObjectContext?.save()
        } catch {
            print("Errore salvataggio messaggio modificato: \(error)")
        }
        
        isEditing = false
        isTextFieldFocused = false
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

// MARK: - Helper Functions

extension ChatView {
    private func getPerplexityModelDisplayName(_ model: String) -> String {
        switch model {
        case "sonar":
            return "Sonar (Base)"
        case "sonar-pro":
            return "Sonar Pro"
        case "sonar-deep-research":
            return "Deep Research"
        default:
            return model
        }
    }
} 

// MARK: - Responsive Layout Manager
class ResponsiveLayoutManager {
    static let shared = ResponsiveLayoutManager()
    
    private init() {}
    
    // MARK: - Device Detection
    func isPad() -> Bool {
        #if canImport(Device)
        return Device.current.isPad
        #endif
        return false
    }
    
    // MARK: - Touch Targets
    func getTouchTarget() -> CGFloat {
        return isPad() ? 60 : 44 // 60pt per iPad, 44pt per iPhone
    }
    
    // MARK: - Spacing
    func getSpacing() -> CGFloat {
        return isPad() ? 24 : 16 // Maggiorato per tablet
    }
    
    // MARK: - Layout Dimensions
    func getSidebarWidth() -> CGFloat {
        return isPad() ? 320 : 0 // Sidebar per iPad
    }
    
    // MARK: - Font Sizes
    func getFontSize() -> CGFloat {
        return isPad() ? 18 : 16 // Maggiorato per tablet
    }
    
    // MARK: - Corner Radius
    func getCornerRadius() -> CGFloat {
        return isPad() ? 24 : 20 // Maggiorato per tablet
    }
}

// MARK: - Responsive Style Guide
struct ResponsiveStyleGuide {
    static let shared = ResponsiveStyleGuide()
    
    // Colori specifici per iPad
    static let ipadAccentColor = Color.blue.opacity(0.9)
    static let ipadBackgroundColor = Color(.systemBackground).opacity(0.95)
    
    // Spaziature specifici
    static let ipadHorizontalPadding = 32
    static let ipadVerticalPadding = 24
    
    // Touch targets specifici
    static let ipadTouchTarget = 60
    
    // Fonti specifici
    static let ipadTitleFont = Font(.title2.weight(.semibold))
    static let ipadBodyFont = Font(.body.weight(.medium))
} 

