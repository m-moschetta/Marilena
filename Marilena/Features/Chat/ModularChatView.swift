import SwiftUI
// PERF: Streaming UI: aggiornare in modo incrementale; evitare copie di stringhe grandi; usare buffering per chunk.
// PERF: Valutare `@StateObject` per view model e ridurre ricomposizioni di tutta la vista.
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
    @State private var selectedProvider = "openai"
    @State private var selectedGroqModel = "llama-3.1-8b-instant"
    @State private var selectedAnthropicModel = "claude-3-5-sonnet-20241022"
    // Gateway error alert
    @State private var showGatewayErrorAlert = false
    @State private var gatewayErrorMessage = ""
    
    private let openAIService = OpenAIService.shared
    private let profiloService = ProfiloUtenteService.shared
    private let perplexityService = PerplexityService.shared
    private let groqService = GroqService.shared
    private let anthropicService = AnthropicService.shared
    @StateObject private var emailChatService = EmailChatService()
    
    // Modelli Perplexity disponibili per ricerca
    private let perplexitySearchModels = [
        "sonar",              // Modello base leggero
        "sonar-pro",          // Modello avanzato (default)
        "sonar-deep-research" // Ricerca approfondita multi-step
    ]
    
    // Modelli OpenAI disponibili (verificati e allineati con SettingsView)
    private let availableOpenAIModels = [
        "gpt-4o",                    // Latest GPT-4o, 128K context
        "gpt-4o-mini",               // Fast and affordable, 128K context
        "chatgpt-4o-latest",         // Latest used in ChatGPT
        "gpt-4.1",                   // Full model, 1M context
        "gpt-4.1-mini",              // Compact version, 1M context
        "gpt-4.1-nano",              // Ultra-light version, optimized for speed
        "gpt-4.5-preview",           // Largest model, creative tasks
        "o1",                        // Latest reasoning model
        "o1-mini",                   // Faster reasoning model
        "o3-mini",                   // Latest small reasoning model
        "gpt-4-turbo",               // Previous generation flagship
        "gpt-3.5-turbo"              // Cost-effective option
    ]
    
    // Modelli Groq disponibili (2025 - Aggiornati da documentazione ufficiale)
    private let availableGroqModels = [
        "deepseek-r1-distill-llama-70b",  // 260 T/s, 131K context, CodeForces 1633, MATH 94.5%
        "deepseek-r1-distill-qwen-32b",   // 388 T/s, 128K context, CodeForces 1691, AIME 83.3%  
        "deepseek-r1-distill-qwen-14b",   // 500+ T/s, 64K context, AIME 69.7, MATH 93.9%
        "deepseek-r1-distill-qwen-1.5b",  // 800+ T/s, 32K context, ultra-fast reasoning
        "qwen2.5-72b-instruct",           // Enhanced capabilities, better reasoning
        "qwen2.5-32b-instruct",           // 397 T/s, 128K context, tool calling + JSON mode
        "llama-3.3-70b-versatile",        // General purpose, balanced performance
        "llama-3.1-405b-reasoning",       // Largest model, best for complex tasks
        "llama-3.1-70b-versatile",        // Good balance of size and performance
        "llama-3.1-8b-instant",           // Fast and efficient for simple tasks
        "mixtral-8x7b-32768",             // Mixture of Experts, multilingual
        "gemma2-9b-it",                   // Efficient instruction-tuned model
        "gemma-7b-it"                     // Lightweight but capable
    ]
    
    // Modelli Anthropic disponibili
    private let availableAnthropicModels = [
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-3-haiku-20240307",
        "claude-3-opus-20240229"
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
                    if messaggi.isEmpty {
                        // Stato vuoto centrato verticalmente
                        VStack(spacing: 0) {
                            Spacer()
                            welcomeView
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
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
                                        },
                                        onSendEmail: chat.tipo == "email" ? { emailId, content in
                                            // Invia la risposta email
                                            Task {
                                                do {
                                                    try await emailChatService.sendEmailResponse(
                                                        from: chat,
                                                        response: content,
                                                        originalEmailId: emailId
                                                    )
                                                } catch {
                                                    print("❌ Errore invio email: \(error)")
                                                }
                                            }
                                        } : nil
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
                                ForEach(currentProviderModels, id: \.self) { model in
                                    Button(action: {
                                        // Aggiorna il modello corretto basato sul provider
                                        switch selectedProvider {
                                        case "groq":
                                            selectedGroqModel = model
                                            UserDefaults.standard.set(model, forKey: "selectedGroqChatModel")
                                        case "anthropic":
                                            selectedAnthropicModel = model
                                            UserDefaults.standard.set(model, forKey: "selectedAnthropicModel")
                                        default: // "openai"
                                            selectedModel = model
                                            UserDefaults.standard.set(model, forKey: "selected_model")
                                        }
                                        inviaMessaggio()
                                    }) {
                                        HStack {
                                            Text(getCurrentProviderModelDisplayName(model))
                                            if model == currentSelectedModel {
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
        }
        .navigationTitle(chat.titolo ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Errore Gateway", isPresented: $showGatewayErrorAlert) {
            Button("OK") { showGatewayErrorAlert = false }
        } message: {
            Text(gatewayErrorMessage)
        }
        .onAppear {
            loadChatSettings()
        }
        .onAppear {
            PerformanceSignpost.event("ChatViewAppear")
        }
    }
    
    // MARK: - Welcome View (COPIA ESATTA)
    

// MARK: - Helpers & Subviews for ModularChatView
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
        
        // Invia al provider selezionato
        isLoading = true
        let conversationHistory = buildConversationHistory(newMessage: messaggioTesto)
        
        switch selectedProvider {
        case "groq":
            let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
            let hasGroqKey = (KeychainManager.shared.getAPIKey(for: "groq") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            if forceGateway || !hasGroqKey {
                let assistantId = UUID()
                let assistantMessage = MessaggioMarilena(context: viewContext)
                assistantMessage.id = assistantId
                assistantMessage.contenuto = ""
                assistantMessage.isUser = false
                assistantMessage.dataCreazione = Date()
                assistantMessage.chat = chat
                try? viewContext.save()

                CloudflareGatewayClient.shared.streamChat(
                    messages: conversationHistory,
                    model: selectedGroqModel,
                    onChunk: { delta in
                        if let obj = fetchMessage(by: assistantId) {
                            obj.contenuto = (obj.contenuto ?? "") + delta
                            try? viewContext.save()
                        }
                    },
                    onComplete: {
                        isLoading = false
                    },
                    onError: { error in
                        print("Errore streaming gateway (Groq): \(error)")
                        // Fallback non-streaming via gateway
                        Task {
                            do {
                                let full = try await CloudflareGatewayClient.shared.sendChat(
                                    messages: conversationHistory,
                                    model: selectedGroqModel
                                )
                                if let obj = fetchMessage(by: assistantId) {
                                    obj.contenuto = full
                                    try? viewContext.save()
                                }
                                isLoading = false
                            } catch {
                                gatewayErrorMessage = error.localizedDescription
                                showGatewayErrorAlert = true
                                let messaggioErrore = MessaggioMarilena(context: viewContext)
                                messaggioErrore.id = UUID()
                                messaggioErrore.contenuto = "Mi dispiace, c'è stato un problema. Riprova."
                                messaggioErrore.isUser = false
                                messaggioErrore.dataCreazione = Date()
                                messaggioErrore.chat = chat
                                try? viewContext.save()
                                isLoading = false
                            }
                        }
                    }
                )
            } else {
                Task {
                    do {
                        let risposta = try await groqService.sendMessage(messages: conversationHistory, model: selectedGroqModel)
                        
                        await MainActor.run {
                            let messaggioAI = MessaggioMarilena(context: viewContext)
                            messaggioAI.id = UUID()
                            messaggioAI.contenuto = risposta
                            messaggioAI.isUser = false
                            messaggioAI.dataCreazione = Date()
                            messaggioAI.chat = chat
                            
                            try? viewContext.save()
                            isLoading = false
                        }
                    } catch {
                        await MainActor.run {
                            print("Errore Groq: \(error)")
                            let messaggioErrore = MessaggioMarilena(context: viewContext)
                            messaggioErrore.id = UUID()
                            messaggioErrore.contenuto = "Mi dispiace, ho avuto un problema con Groq. Riprova tra poco."
                            messaggioErrore.isUser = false
                            messaggioErrore.dataCreazione = Date()
                            messaggioErrore.chat = chat
                            
                            try? viewContext.save()
                            isLoading = false
                        }
                    }
                }
            }
            
        case "anthropic":
            // Converti OpenAIMessage in AnthropicMessage
            let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
            let anthropicMessages = conversationHistory.filter { $0.role != "system" }.map { openAIMsg in
                AnthropicMessage(
                    role: openAIMsg.role,
                    content: [AnthropicContent(type: "text", text: openAIMsg.content)]
                )
            }
            
            let hasAnthropicKey = (KeychainManager.shared.getAPIKey(for: "anthropic") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            if forceGateway || !hasAnthropicKey {
                // Usa direttamente il conversationHistory (OpenAI-format) per il gateway
                let assistantId = UUID()
                let assistantMessage = MessaggioMarilena(context: viewContext)
                assistantMessage.id = assistantId
                assistantMessage.contenuto = ""
                assistantMessage.isUser = false
                assistantMessage.dataCreazione = Date()
                assistantMessage.chat = chat
                try? viewContext.save()

                CloudflareGatewayClient.shared.streamChat(
                    messages: conversationHistory,
                    model: selectedAnthropicModel,
                    onChunk: { delta in
                        if let obj = fetchMessage(by: assistantId) {
                            obj.contenuto = (obj.contenuto ?? "") + delta
                            try? viewContext.save()
                        }
                    },
                    onComplete: {
                        isLoading = false
                    },
                    onError: { error in
                        print("Errore streaming gateway (Anthropic): \(error)")
                        // Fallback non-streaming via gateway
                        Task {
                            do {
                                let full = try await CloudflareGatewayClient.shared.sendChat(
                                    messages: conversationHistory,
                                    model: selectedAnthropicModel
                                )
                                if let obj = fetchMessage(by: assistantId) {
                                    obj.contenuto = full
                                    try? viewContext.save()
                                }
                                isLoading = false
                            } catch {
                                gatewayErrorMessage = error.localizedDescription
                                showGatewayErrorAlert = true
                                let messaggioErrore = MessaggioMarilena(context: viewContext)
                                messaggioErrore.id = UUID()
                                messaggioErrore.contenuto = "Mi dispiace, c'è stato un problema. Riprova."
                                messaggioErrore.isUser = false
                                messaggioErrore.dataCreazione = Date()
                                messaggioErrore.chat = chat
                                try? viewContext.save()
                                isLoading = false
                            }
                        }
                    }
                )
            } else {
                anthropicService.sendMessage(messages: anthropicMessages, model: selectedAnthropicModel, maxTokens: 4096, temperature: 0.7) { result in
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
                            print("Errore Anthropic: \(error)")
                            let messaggioErrore = MessaggioMarilena(context: viewContext)
                            messaggioErrore.id = UUID()
                            messaggioErrore.contenuto = "Mi dispiace, ho avuto un problema con Anthropic. Riprova tra poco."
                            messaggioErrore.isUser = false
                            messaggioErrore.dataCreazione = Date()
                            messaggioErrore.chat = chat
                            
                            try? viewContext.save()
                        }
                    }
                }
            }
            
        default: // "openai"
            // Se manca la chiave OpenAI, usa streaming via Cloudflare Gateway
            let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
            let hasOpenAIKey = (KeychainManager.shared.load(key: "openai_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            if forceGateway || !hasOpenAIKey {
                let assistantId = UUID()
                let assistantMessage = MessaggioMarilena(context: viewContext)
                assistantMessage.id = assistantId
                assistantMessage.contenuto = ""
                assistantMessage.isUser = false
                assistantMessage.dataCreazione = Date()
                assistantMessage.chat = chat
                try? viewContext.save()

                CloudflareGatewayClient.shared.streamChat(
                    messages: conversationHistory,
                    model: selectedModel,
                    onChunk: { delta in
                        if let obj = fetchMessage(by: assistantId) {
                            obj.contenuto = (obj.contenuto ?? "") + delta
                            try? viewContext.save()
                        }
                    },
                    onComplete: {
                        isLoading = false
                    },
                    onError: { error in
                        print("Errore streaming gateway: \(error)")
                        // Fallback non-streaming via gateway
                        Task {
                            do {
                                let full = try await CloudflareGatewayClient.shared.sendChat(
                                    messages: conversationHistory,
                                    model: selectedModel
                                )
                                if let obj = fetchMessage(by: assistantId) {
                                    obj.contenuto = full
                                    try? viewContext.save()
                                }
                                isLoading = false
                            } catch {
                                gatewayErrorMessage = error.localizedDescription
                                showGatewayErrorAlert = true
                                let messaggioErrore = MessaggioMarilena(context: viewContext)
                                messaggioErrore.id = UUID()
                                messaggioErrore.contenuto = "Mi dispiace, c'è stato un problema. Riprova."
                                messaggioErrore.isUser = false
                                messaggioErrore.dataCreazione = Date()
                                messaggioErrore.chat = chat
                                try? viewContext.save()
                                isLoading = false
                            }
                        }
                    }
                )
            } else {
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
                            messaggioErrore.contenuto = "Mi dispiace, ho avuto un problema con OpenAI. Riprova tra poco."
                            messaggioErrore.isUser = false
                            messaggioErrore.dataCreazione = Date()
                            messaggioErrore.chat = chat
                            
                            try? viewContext.save()
                        }
                    }
                }
            }
        }
    }

    private func fetchMessage(by id: UUID) -> MessaggioMarilena? {
        let req: NSFetchRequest<MessaggioMarilena> = MessaggioMarilena.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? viewContext.fetch(req))?.first
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
    
    // MARK: - Provider Settings Functions
    
    func loadChatSettings() {
        selectedModel = UserDefaults.standard.string(forKey: "selected_model") ?? "gpt-4o-mini"
        selectedPerplexityModel = UserDefaults.standard.string(forKey: "selected_perplexity_model") ?? "sonar-pro"
        selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "openai"
        let groqUD = UserDefaults.standard.string(forKey: "selectedGroqChatModel") ?? "llama-3.1-8b-instant"
        let anthropicUD = UserDefaults.standard.string(forKey: "selectedAnthropicModel") ?? "claude-3-5-sonnet-20241022"
        selectedGroqModel = normalizeModel(groqUD)
        selectedAnthropicModel = normalizeModel(anthropicUD)
    }
    
    // Modelli dinamici basati sul provider selezionato
    private var currentProviderModels: [String] {
        switch selectedProvider {
        case "groq":
            return availableGroqModels
        case "anthropic":
            return availableAnthropicModels
        default: // "openai"
            return availableOpenAIModels
        }
    }

    // Normalizza display name → ID (se necessario)
    private func normalizeModel(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains(" ") && !trimmed.contains("/") { return trimmed }
        // Prova a risolvere con ModelCatalog per provider corrente
        let lists: [[AIModelInfo]] = [
            ModelCatalog.shared.models(for: .groq),
            ModelCatalog.shared.models(for: .anthropic)
        ]
        for list in lists {
            if let match = list.first(where: { $0.description.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                return match.name
            }
        }
        // Heuristics di fallback
        let lower = trimmed.lowercased()
        if lower.contains("claude") { return "claude-3-5-sonnet-20241022" }
        if lower.contains("qwen") || lower.contains("deepseek") || lower.contains("llama") { return "llama-3.1-8b-instant" }
        return trimmed
    }
    
    // Modello attualmente selezionato per il provider
    private var currentSelectedModel: String {
        switch selectedProvider {
        case "groq":
            return selectedGroqModel
        case "anthropic":
            return selectedAnthropicModel
        default: // "openai"
            return selectedModel
        }
    }
    
    func getOpenAIModelDisplayName(_ model: String) -> String {
        switch model {
        case "gpt-4o":
            return "🌟 GPT-4o (Flagship Multimodal)"
        case "gpt-4o-mini":
            return "⚡ GPT-4o Mini (Fast & Affordable)"
        case "chatgpt-4o-latest":
            return "🚀 ChatGPT-4o Latest"
        case "gpt-4-turbo":
            return "🚀 GPT-4 Turbo (Legacy Powerhouse)"
        case "gpt-3.5-turbo":
            return "💫 GPT-3.5 Turbo (Classic)"
        case "o1":
            return "🧠 o1 (Advanced Reasoning)"
        case "o1-mini":
            return "⚡ o1-mini (Fast Reasoning)"
        case "o1-preview":
            return "🔬 o1-preview (Early Access)"
        default:
            return model
        }
    }
    
    func getAnthropicModelDisplayName(_ model: String) -> String {
        switch model {
        case "claude-opus-4-20250514":
            return "💎 Claude 4 Opus (Most Capable)"
        case "claude-sonnet-4-20250514":
            return "🎯 Claude 4 Sonnet (High Performance)"
        case "claude-3-7-sonnet-20250219":
            return "🧠 Claude 3.7 Sonnet (Hybrid Reasoning)"
        case "claude-3-5-sonnet-20241022":
            return "⚖️ Claude 3.5 Sonnet (Balanced)"
        case "claude-3-5-haiku-20241022":
            return "⚡ Claude 3.5 Haiku (Fast)"
        case "claude-3-opus-20240229":
            return "💎 Claude 3 Opus (Legacy Premium)"
        case "claude-3-sonnet":
            return "🎯 Claude 3 Sonnet (Legacy Balanced)"
        case "claude-3-haiku":
            return "⚡ Claude 3 Haiku (Legacy Fast)"
        default:
            return model
        }
    }
    
    func getGroqModelDisplayName(_ model: String) -> String {
        switch model {
        case "qwen-qwq-32b":
            return "🧠 Qwen QwQ 32B (Latest Reasoning)"
        case "qwen2.5-32b-instruct":
            return "⚡ Qwen 2.5 32B (Fast)"
        case "qwen2.5-72b-instruct":
            return "🚀 Qwen 2.5 72B (Powerful)"
        case "deepseek-r1-distill-qwen-32b":
            return "🎯 DeepSeek R1 Qwen 32B (Coding)"
        case "deepseek-r1-distill-llama-70b":
            return "💎 DeepSeek R1 Llama 70B (Math)"
        case "llama-3.3-70b-versatile":
            return "🦙 Llama 3.3 70B (Versatile)"
        case "llama-3.1-405b-reasoning":
            return "🔬 Llama 3.1 405B (Reasoning)"
        case "llama-3.1-70b-versatile":
            return "⚖️ Llama 3.1 70B (Balanced)"
        case "llama-3.1-8b-instant":
            return "⚡ Llama 3.1 8B (Instant)"
        case "mixtral-8x7b-32768":
            return "🔀 Mixtral 8x7B (Expert Mix)"
        case "gemma2-9b-it":
            return "💫 Gemma 2 9B (Efficient)"
        case "gemma-7b-it":
            return "✨ Gemma 7B (Lightweight)"
        default:
            return model
        }
    }
    
    // Mostra sempre l'ID esatto del modello (quello inviato alle API)
    func getCurrentProviderModelDisplayName(_ model: String) -> String { model }
}

// MARK: - Modular Message Row (COPIA ESATTA COMPLETA)

struct ModularMessageRow: View {
    let messaggio: MessaggioMarilena
    let onSendToAI: (String) -> Void
    let onSearchWithPerplexity: (String) -> Void
    let onSendEmail: ((String, String) -> Void)? // emailId, content
    @State private var isEditing = false
    @State private var editedText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingCanvas = false
    
                        // Helper per identificare se è un draft di risposta email
    private var isEmailResponseDraft: Bool {
        return messaggio.tipo == "email_response_draft"
    }
    
    // Helper per identificare se è un messaggio di conferma invio
    private var isEmailConfirmation: Bool {
        return messaggio.tipo == "email_confirmation"
    }
    
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
                        },
                        onSendEmail: isEmailResponseDraft ? { text in
                            if let emailId = messaggio.emailId {
                                onSendEmail?(emailId, text)
                                showingCanvas = false
                            }
                        } : nil
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
                        VStack(alignment: .leading, spacing: 8) {
                            // Badge speciale per draft email con indicazione interattiva
                            if isEmailResponseDraft {
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope.arrow.triangle.branch")
                                        .font(.caption2)
                                    Text("Bozza Email")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                    
                                    // Indicatore interattivo
                                    HStack(spacing: 2) {
                                        Image(systemName: "hand.tap")
                                            .font(.system(size: 10))
                                        Text("Tieni premuto")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(.blue.opacity(0.7))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isEmailResponseDraft)
                                )
                            }
                            
                            // Badge per conferma invio email
                            if isEmailConfirmation {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("Marilena Assistente")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // TODO: Add thinking support when MessaggioMarilena model is updated with metadata field
                                
                                
                                Text(messaggio.contenuto ?? "")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(
                                                isEmailResponseDraft ? Color.blue.opacity(0.05) :
                                                isEmailConfirmation ? Color.green.opacity(0.05) :
                                                Color(.systemGray6)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(
                                                        isEmailResponseDraft ? Color.blue.opacity(0.3) :
                                                        isEmailConfirmation ? Color.green.opacity(0.3) :
                                                        Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                                    )
                                    .foregroundColor(.primary)

                                // Indicatore routing (mostrato quando si forza il gateway)
                                if UserDefaults.standard.bool(forKey: "force_gateway") {
                                    HStack(spacing: 6) {
                                        Image(systemName: "cloud.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text("via Cloudflare")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 4)
                                }
                            }
                                .textSelection(.enabled)
                                // NUOVO: Haptic Touch per email drafts
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    if isEmailResponseDraft {
                                        // Preparazione haptic
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.prepare()
                                        
                                        // Feedback haptic principale
                                        impactFeedback.impactOccurred()
                                        
                                        // Feedback aggiuntivo per indicare successo
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            let successFeedback = UINotificationFeedbackGenerator()
                                            successFeedback.notificationOccurred(.success)
                                        }
                                        
                                        // Apri canvas direttamente
                                        editedText = messaggio.contenuto ?? ""
                                        showingCanvas = true
                                    }
                                }
                                // NUOVO: Tap normale per indicazioni visive
                                .onTapGesture {
                                    if isEmailResponseDraft {
                                        // Feedback leggero per indicare che è interattivo
                                        let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                                        lightFeedback.impactOccurred()
                                    }
                                }
                        }
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
                        },
                        onSendEmail: isEmailResponseDraft ? { text in
                            if let emailId = messaggio.emailId {
                                onSendEmail?(emailId, text)
                                showingCanvas = false
                            }
                        } : nil
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
    let onSendEmail: ((String) -> Void)? // Nuovo parametro opzionale per inviare email
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var isRichTextFirstResponder = false
    @State private var showOriginal = false
    @State private var isRichTextMode = false
    @State private var showingRegenerateMenu = false
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
                            
                            // Editor principale - Rich Text o TextEditor semplice
                            Group {
                                if isRichTextMode && onSendEmail != nil {
                                    // Rich Text Editor per email
                                    RichTextEditor(
                                        text: $editedText,
                                        isFirstResponder: $isRichTextFirstResponder,
                                        placeholder: "Componi la tua email..."
                                    )
                                    .frame(minHeight: UIScreen.main.bounds.height * 0.6)
                                    .padding(.horizontal, 20)
                                    .onChange(of: isTextFieldFocused) { oldValue, newValue in
                                        isRichTextFirstResponder = newValue
                                    }
                                    .onChange(of: isRichTextFirstResponder) { oldValue, newValue in
                                        if newValue != isTextFieldFocused {
                                            isTextFieldFocused = newValue
                                        }
                                    }
                                } else {
                                    // TextEditor standard per messaggi normali
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
                        // Feedback haptic per annullamento
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        onCancel()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Toggle Rich Text per email
                        if onSendEmail != nil {
                            Button(action: {
                                // Feedback haptic per toggle
                                let selectionFeedback = UISelectionFeedbackGenerator()
                                selectionFeedback.selectionChanged()
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isRichTextMode.toggle()
                                }
                            }) {
                                Image(systemName: isRichTextMode ? "textformat" : "textformat.alt")
                                    .foregroundColor(isRichTextMode ? .blue : .secondary)
                            }
                        }
                        
                        // Menu Rigenera con Haptic
                        Menu {
                            Button("🎭 Più Formale") {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                regenerateContent(style: "Rendi questo testo più formale e professionale")
                            }
                            Button("😊 Più Casual") {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                regenerateContent(style: "Rendi questo testo più casual e amichevole")
                            }
                            Button("📝 Più Breve") {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                regenerateContent(style: "Riassumi questo testo rendendolo più conciso")
                            }
                            Button("📚 Più Dettagliato") {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                regenerateContent(style: "Espandi questo testo aggiungendo più dettagli")
                            }
                            if onSendEmail != nil {
                                Divider()
                                Button("✉️ Formato Email") {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    regenerateContent(style: "Trasforma questo in una email professionale ben formattata")
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.secondary)
                        }
                        
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
                        
                        // Salva con Haptic
                        Button("Fine") {
                            // Feedback haptic per salvataggio
                            let successFeedback = UINotificationFeedbackGenerator()
                            successFeedback.notificationOccurred(.success)
                            
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
                if isRichTextMode && onSendEmail != nil {
                    isRichTextFirstResponder = true
                } else {
                    isTextFieldFocused = true
                }
            }
            // Attiva automaticamente Rich Text per email
            if onSendEmail != nil {
                isRichTextMode = true
            }
            // Notifica che una chat è stata aperta
            NotificationCenter.default.post(name: .chatOpened, object: nil)
        }
        .onDisappear {
            // Notifica che la chat è stata chiusa
            NotificationCenter.default.post(name: .chatClosed, object: nil)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showOriginal)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTextFieldFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRichTextMode)
    }
    
    // MARK: - Helper Functions
    
    private func regenerateContent(style: String) {
        let promptWithStyle = "\(style): \(editedText)"
        onSendToAI(promptWithStyle)
        
        // Feedback haptic
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
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
                    // Feedback haptic per ricerca
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
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
                    // Feedback haptic per rigenerazione
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    onSendToAI(editedText)
                }) {
                    Label("Reinvia", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                
                // Invia Email - solo se è disponibile la callback
                if let sendEmail = onSendEmail {
                    Button(action: {
                        // Feedback haptic per invio email
                        let successFeedback = UINotificationFeedbackGenerator()
                        successFeedback.notificationOccurred(.success)
                        
                        // Doppio feedback haptic per confermare invio dal canvas
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            let finalSuccessFeedback = UINotificationFeedbackGenerator()
                            finalSuccessFeedback.notificationOccurred(.success)
                        }
                        
                        sendEmail(editedText)
                    }) {
                        Label("Invia", systemImage: "envelope.arrow.triangle.branch")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                }
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
                    .liquidGlassEffect(style: variant == .regular ? .regular : .subtle, tint: .white.opacity(opacity))
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
    }}
