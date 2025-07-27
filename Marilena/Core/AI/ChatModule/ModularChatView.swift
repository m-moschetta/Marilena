import SwiftUI
import Combine
import CoreData

// MARK: - Extension per iOS 26 Compatibility

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V {
        return block(self)
    }
}

// MARK: - Modular Chat View (Copia ESATTA di ChatView.swift)

public struct ModularChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
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
    
    // MARK: - Configuration
    private let title: String
    private let showSettings: Bool
    
    // MARK: - Initialization
    
    public init(
        chat: ChatMarilena,
        title: String? = nil,
        showSettings: Bool = true
    ) {
        self.chat = chat
        self.title = title ?? chat.titolo ?? "Chat AI"
        self.showSettings = showSettings
        
        // FetchRequest come nell'originale
        self._messaggi = FetchRequest(
            entity: MessaggioMarilena.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \MessaggioMarilena.dataCreazione, ascending: true)],
            predicate: NSPredicate(format: "chat == %@", chat)
        )
        
        // Inizializza il modello selezionato con il valore salvato
        self._selectedModel = State(initialValue: UserDefaults.standard.string(forKey: "selected_model") ?? "gpt-4o-mini")
        self._selectedPerplexityModel = State(initialValue: UserDefaults.standard.string(forKey: "selected_perplexity_model") ?? "sonar-pro")
    }
    
    public var body: some View {
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
                                    ModularMessageRow(
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
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messaggi.count) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
        }
    }
    
                                // Input area moderna e dinamica con dimensioni standard (COPIA ESATTA)
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 8) {
                        // Campo di testo con espansione dinamica graduale
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.systemGray6))
                        .frame(height: calculateTextEditorHeight())
                    
                            if testo.isEmpty {
                        Text("Scrivi un messaggio...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    
                            TextEditor(text: $testo)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
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
                        .animation(.easeOut(duration: 0.2), value: testo.components(separatedBy: "\n").count)
                        .animation(.easeOut(duration: 0.2), value: calculateTextEditorHeight())
                        
                        // Pulsanti rimpiccioliti e vicini in orizzontale
                        HStack(spacing: 6) {
                            Button(action: searchWithPerplexity) {
                                ZStack {
                                    Circle()
                                        .fill(isSearchingPerplexity ? Color.orange : Color(.systemGray5))
                                        .frame(width: 36, height: 36) // Rimpicciolito da 44 a 36
                                    
                                    if isSearchingPerplexity {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "globe.americas.fill")
                                            .font(.system(size: 16, weight: .medium)) // Icona più piccola
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
                            
                            // Pulsante invia rimpicciolito
                            Button(action: inviaMessaggio) {
                    ZStack {
                        Circle()
                                        .fill(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? 
                                  Color(.systemGray4) : Color.blue)
                                        .frame(width: 36, height: 36) // Rimpicciolito da 44 a 36
                        
                                    if isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold)) // Icona più piccola
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
                    .padding(.vertical, 8) // Ridotto padding verticale da 12 a 8
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle(chat.titolo ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Welcome View (COPIA ESATTA)
    
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
    
    // MARK: - Functions (COPIA ESATTA)
    
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
    
    private func calculateTextEditorHeight() -> CGFloat {
        let baseHeight: CGFloat = 60 // Aumentato da 44 a 60 per più spazio di default
        let maxHeight: CGFloat = 140 // Aumentato da 120 a 140 per permettere più righe
        let lineHeight: CGFloat = 20
        let textWidth: CGFloat = UIScreen.main.bounds.width - 120 // Larghezza disponibile per il testo
        
        if testo.isEmpty {
            return baseHeight
        }
        
        // Calcola il numero di righe basato sui caratteri di nuova riga manuali
        let manualLines = testo.components(separatedBy: "\n").count
        
        // Stima le righe dovute al wrapping automatico
        let font = UIFont.systemFont(ofSize: 16) // Dimensione font del TextEditor
        let textAttributes = [NSAttributedString.Key.font: font]
        let textSize = (testo as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: textAttributes,
            context: nil
        )
        
        let totalLines = max(manualLines, Int(ceil(textSize.height / lineHeight)))
        let calculatedHeight = baseHeight + CGFloat(totalLines - 1) * lineHeight
        
        // Limita l'altezza massima
        return min(maxHeight, max(baseHeight, calculatedHeight))
    }
    
    // MARK: - Perplexity Search (COPIA ESATTA)
    
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
        
        // Salva il messaggio utente
        do {
            try viewContext.save()
        } catch {
            print("Errore salvataggio messaggio utente per Perplexity: \(error)")
            isSearchingPerplexity = false
            return
        }
        
        // Prepara il contesto della conversazione per Perplexity
        let conversationHistory = buildConversationHistory(newMessage: query)
        let contextualQuery = buildContextualPerplexityQuery(query: query, history: conversationHistory)
        
        // Chiama Perplexity con il contesto
        Task {
            do {
                let searchResult = try await perplexityService.search(query: contextualQuery, model: selectedPerplexityModel)
                
                await MainActor.run {
                    // Crea messaggio di risposta da Perplexity
                    let perplexityMessage = MessaggioMarilena(context: viewContext)
                    perplexityMessage.id = UUID()
                    perplexityMessage.contenuto = "🌐 **Ricerca Perplexity**\n\n\(searchResult)"
                    perplexityMessage.isUser = false
                    perplexityMessage.dataCreazione = Date()
                    perplexityMessage.chat = chat
                    
                    do {
                        try viewContext.save()
                    } catch {
                        print("Errore salvataggio risposta Perplexity: \(error)")
                    }
                    
                    isSearchingPerplexity = false
                }
                
            } catch {
                await MainActor.run {
                    print("Errore Perplexity: \(error)")
                    isSearchingPerplexity = false
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
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
    
    private func buildContextualPerplexityQuery(query: String, history: [OpenAIMessage]) -> String {
        // Se non c'è cronologia, usa solo la query
        guard !history.isEmpty else { return query }
        
        // Prendi gli ultimi 6 messaggi per il contesto (3 coppie domanda-risposta)
        let recentHistory = Array(history.suffix(6))
        
        var contextString = "Contesto della conversazione precedente:\n"
        for message in recentHistory {
            let role = message.role == "user" ? "Utente" : "AI"
            contextString += "\n\(role): \(message.content)"
        }
        
        contextString += "\n\nNuova domanda da ricercare: \(query)"
        contextString += "\n\nRispondi considerando il contesto della conversazione precedente."
        
        return contextString
    }
}

// MARK: - Modular Message Row (COPIA ESATTA COMPLETA)

struct ModularMessageRow: View {
    let messaggio: MessaggioMarilena
    let onSendToAI: (String) -> Void
    let onSearchWithPerplexity: (String) -> Void
    @State private var isEditing = false
    @State private var editedText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingCanvas = false
    
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
                    Button("Apri in un canvas") {
                        editedText = messaggio.contenuto ?? ""
                        showingCanvas = true
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
                .sheet(isPresented: $showingCanvas) {
                    MessageEditCanvas(
                        originalText: messaggio.contenuto ?? "",
                        editedText: $editedText,
                        onSendToAI: { text in
                            onSendToAI(text)
                            showingCanvas = false
                        },
                        onSearchWithPerplexity: { text in
                            onSearchWithPerplexity(text)
                            showingCanvas = false
                        },
                        onSave: {
                            saveEditedMessage()
                            showingCanvas = false
                        },
                        onCancel: {
                            showingCanvas = false
                        }
                    )
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
                    Button("Apri in un canvas") {
                        editedText = messaggio.contenuto ?? ""
                        showingCanvas = true
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
                .sheet(isPresented: $showingCanvas) {
                    MessageEditCanvas(
                        originalText: messaggio.contenuto ?? "",
                        editedText: $editedText,
                        onSendToAI: { text in
                            onSendToAI(text)
                            showingCanvas = false
                        },
                        onSearchWithPerplexity: { text in
                            onSearchWithPerplexity(text)
                            showingCanvas = false
                        },
                        onSave: {
                            saveEditedMessage()
                            showingCanvas = false
                        },
                        onCancel: {
                            showingCanvas = false
                        }
                    )
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

// MARK: - Message Edit Canvas - LIQUID GLASS AVANZATO iOS 26

struct MessageEditCanvas: View {
    let originalText: String
    @Binding var editedText: String
    let onSendToAI: (String) -> Void
    let onSearchWithPerplexity: (String) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var showOriginal = false
    @Environment(\.colorScheme) var colorScheme
    

    
    var body: some View {
        NavigationView {
            ZStack {
                // Background pulitissimo come Apple Notes
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Contenuto principale
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Testo originale (se diverso)
                            if showOriginal && originalText != editedText {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Testo originale:")
                                        .font(.caption)
                            .foregroundColor(.secondary)
                                    
                                    Text(originalText)
                                        .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                                        .padding(16)
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                            }
                            
                            // TextEditor principale - IDENTICO AD APPLE NOTES
                            TextEditor(text: $editedText)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.primary)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .focused($isTextFieldFocused)
                                .frame(minHeight: UIScreen.main.bounds.height * 0.6)
                                .padding(.horizontal, 20)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    
                    // Toolbar liquid glass AVANZATO solo quando tastiera è visibile
                    if isTextFieldFocused {
                        advancedLiquidGlassToolbar
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
            }
            .navigationTitle("Modifica Testo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar superiore minimalista
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        onCancel()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Toggle originale solo se diverso
                        if originalText != editedText {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showOriginal.toggle()
                                }
                            }) {
                                Image(systemName: showOriginal ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Salva
                        Button("Fine") {
                            onSave()
                        }
                        .fontWeight(.medium)
                        .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            // Focus automatico come Apple Notes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showOriginal)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTextFieldFocused)
    }
    
    // MARK: - Advanced Liquid Glass Toolbar - TUTTE LE NUOVE API iOS 26
    
    @ViewBuilder
    private var advancedLiquidGlassToolbar: some View {
        // Toolbar completamente pulita e flottante come Apple Notes
        HStack(spacing: 0) {
            // Pulsanti completamente puliti senza effetti
            Group {
                // Copia
                Button(action: {
                    UIPasteboard.general.string = editedText
                    // Haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }) {
                    Label("Copia", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                
                // Cerca
                Button(action: {
                    onSearchWithPerplexity(editedText)
                }) {
                    Label("Cerca", systemImage: "magnifyingglass")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                
                // Reinvia all'AI - icona corretta
                Button(action: {
                    onSendToAI(editedText)
                }) {
                    Label("Reinvia", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 60)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

}

// MARK: - Glass Background Component - COMPATIBILE iOS 26

struct GlassBackground: View {
    let cornerRadius: CGFloat
    let opacity: CGFloat
    let variant: LiquidGlassVariant
    
    enum LiquidGlassVariant {
        case regular
        case clear
    }
    
    init(cornerRadius: CGFloat = 0, opacity: CGFloat = 0.25, variant: LiquidGlassVariant = .regular) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.variant = variant
    }
    
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                // Vero Liquid Glass iOS 26 con API ufficiali
                RoundedRectangle(cornerRadius: cornerRadius)
                    .glassEffect(variant == .regular ? .regular.tint(.white.opacity(opacity)) : .clear)
            } else {
                // Fallback per iOS < 26
                legacyGlassBackground
            }
        }
        .shadow(
            color: .black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    @ViewBuilder
    private var legacyGlassBackground: some View {
        ZStack {
            // Base blur layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            
            // Glassmorphism layer
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.white.opacity(opacity))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .white.opacity(0.1),
                                    .white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            // Inner glow effect
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
        }
    }
}

// MARK: - Glass Modifier - AGGIORNATO per iOS 26

struct GlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: CGFloat
    let variant: GlassBackground.LiquidGlassVariant
    
    func body(content: Content) -> some View {
        content
            .background(
                GlassBackground(
                    cornerRadius: cornerRadius,
                    opacity: opacity,
                    variant: variant
                )
            )
    }
}

extension View {
    func glass(
        cornerRadius: CGFloat = 20,
        opacity: CGFloat = 0.25,
        variant: GlassBackground.LiquidGlassVariant = .regular
    ) -> some View {
        modifier(GlassModifier(
            cornerRadius: cornerRadius,
            opacity: opacity,
            variant: variant
        ))
    }
}

// MARK: - Preview (existing)

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let chat = ChatMarilena(context: context)
    chat.id = UUID()
    chat.titolo = "Chat Demo"
    chat.dataCreazione = Date()
    
    return NavigationView {
        ModularChatView(chat: chat, title: "Chat AI Demo")
            .environment(\.managedObjectContext, context)
    }
} 