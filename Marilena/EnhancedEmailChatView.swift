import SwiftUI
import CoreData

// MARK: - Enhanced Email Chat View
// Vista potenziata per gestire il workflow completo: Email + Chat + Trascrizioni + Canvas

public struct EnhancedEmailChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var chat: ChatMarilena
    @StateObject private var enhancedService = EnhancedEmailChatService()
    @StateObject private var aiService = EmailAIService()
    
    @FetchRequest private var messaggi: FetchedResults<MessaggioMarilena>
    @State private var testo = ""
    @State private var isLoading = false
    
    // Workflow states
    @State private var showingTranscriptionPicker = false
    @State private var selectedTranscription: Trascrizione?
    @State private var showingCanvasEditor = false
    @State private var currentDraft: EmailDraft?
    @State private var canvasContent = ""
    @State private var isEditingCanvas = false
    @State private var showingSendConfirmation = false
    
    // Quick actions
    @State private var showingQuickActions = true
    @State private var searchQuery = ""
    @State private var searchResults: [String] = []
    
    public init(chat: ChatMarilena) {
        self.chat = chat
        self._messaggi = FetchRequest(
            entity: MessaggioMarilena.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \MessaggioMarilena.dataCreazione, ascending: true)],
            predicate: NSPredicate(format: "chat == %@", chat)
        )
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header con info email e Marilena
            enhancedEmailChatHeader
            
            Divider()
                .background(Color(UIColor.separator))
            
            // Contenuto chat con canvas integrato
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Messaggi esistenti
                        ForEach(messaggi, id: \.id) { messaggio in
                            EnhancedEmailMessageView(
                                messaggio: messaggio,
                                onEditCanvas: { content in
                                    canvasContent = content
                                    isEditingCanvas = true
                                    showingCanvasEditor = true
                                },
                                onApproveAndSend: { content in
                                    approveAndSend(content)
                                }
                            )
                        }
                        
                        // Quick Actions Panel (quando non ci sono messaggi o mostrato)
                        if messaggi.isEmpty || showingQuickActions {
                            quickActionsPanel
                        }
                        
                        // Search Results
                        if !searchResults.isEmpty {
                            searchResultsView
                        }
                        
                        // Indicatore caricamento
                        if isLoading || enhancedService.isLoading {
                            marilenaThinkingView
                        }
                    }
                    .padding()
                }
                .onChange(of: messaggi.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // Input area potenziata
            enhancedInputArea
        }
        .navigationTitle("🤖 Assistente Marilena")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("🔍 Scegli Trascrizione") {
                        showingTranscriptionPicker = true
                    }
                    
                    Button("📝 Apri Canvas") {
                        showingCanvasEditor = true
                    }
                    
                    Button(showingQuickActions ? "Nascondi Azioni Rapide" : "Mostra Azioni Rapide") {
                        withAnimation {
                            showingQuickActions.toggle()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.blue)
                }
            }
        }
        .onAppear {
            setupEnhancedChat()
        }
        .sheet(isPresented: $showingTranscriptionPicker) {
            TranscriptionPickerView(
                transcriptions: enhancedService.availableTranscriptions,
                selectedTranscription: $selectedTranscription
            ) { transcription in
                Task {
                    await integrateTranscription(transcription)
                }
            }
        }
        .sheet(isPresented: $showingCanvasEditor) {
            CanvasEditorView(
                content: $canvasContent,
                isEditing: $isEditingCanvas,
                onSave: { content in
                    saveCanvasContent(content)
                },
                onSend: { content in
                    approveAndSend(content)
                }
            )
        }
        .alert("Conferma Invio", isPresented: $showingSendConfirmation) {
            Button("Invia") {
                Task {
                    await finalizeAndSend()
                }
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Sei sicuro di voler inviare questa risposta?")
        }
    }
    
    // MARK: - Header
    
    private var enhancedEmailChatHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Avatar Marilena
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text("🤖")
                            .font(.title2)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Marilena - Assistente Email")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let sender = chat.emailSender {
                        Text("Email da: \(sender)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Status indicators
                VStack(alignment: .trailing, spacing: 2) {
                    if let selectedTranscription = selectedTranscription {
                        Label("\(selectedTranscription.paroleTotali) parole", systemImage: "waveform")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    
                    if !enhancedService.availableTranscriptions.isEmpty {
                        Text("\(enhancedService.availableTranscriptions.count) trascrizioni")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Contextual suggestions
            if !enhancedService.contextualSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(enhancedService.contextualSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                handleSuggestion(suggestion)
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Quick Actions Panel
    
    private var quickActionsPanel: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("Cosa posso fare per te?")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(QuickResponseType.allCases, id: \.self) { type in
                    QuickActionCard(type: type) {
                        handleQuickAction(type)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .liquidGlass(.subtle)
    }
    
    // MARK: - Search Results View
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.green)
                Text("Informazioni trovate")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                
                Button("Genera Bozza") {
                    generateDraftFromSearchResults()
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
            }
            
            ForEach(searchResults.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Risultato \(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(searchResults[index])
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Marilena Thinking View
    
    private var marilenaThinkingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Marilena sta pensando...")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Text("Analizzando email e trascrizioni")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Enhanced Input Area
    
    private var enhancedInputArea: some View {
        VStack(spacing: 8) {
            // Search bar per trascrizioni
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Cerca nelle trascrizioni...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        searchInTranscriptions()
                    }
                
                if !searchQuery.isEmpty {
                    Button("Cerca") {
                        searchInTranscriptions()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            
            // Main message input
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Chiedi a Marilena...", text: $testo, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties
    
    private var canSendMessage: Bool {
        !testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    // MARK: - Actions
    
    private func setupEnhancedChat() {
        // Se c'è un'email associata, avvia il workflow
        if let emailId = messaggi.first(where: { $0.emailId != nil })?.emailId {
            // Crea EmailMessage dai dati esistenti per avviare il workflow
            if let sender = chat.emailSender,
               let subject = chat.emailSubject {
                let emailMessage = EmailMessage(
                    id: emailId,
                    from: sender,
                    to: [],
                    subject: subject,
                    body: messaggi.first?.contenuto ?? "",
                    date: chat.lastEmailDate ?? Date()
                )
                
                Task {
                    _ = await enhancedService.startEmailResponseWorkflow(for: emailMessage)
                }
            }
        }
    }
    
    private func handleQuickAction(_ type: QuickResponseType) {
        Task {
            switch type {
            case .searchTranscriptions:
                showingTranscriptionPicker = true
                
            case .generateDraft:
                await generateFullDraft()
                
            case .needMoreTime:
                await generateStandardResponse("Più tempo")
                
            case .scheduleMeeting:
                await generateStandardResponse("Programma meeting")
                
            case .decline:
                await generateStandardResponse("Declina")
                
            case .forward:
                await generateStandardResponse("Forward")
            }
        }
    }
    
    private func handleSuggestion(_ suggestion: String) {
        testo = suggestion
        sendMessage()
    }
    
    private func sendMessage() {
        guard !testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageContent = testo
        testo = ""
        
        // Crea messaggio utente
        let userMessage = MessaggioMarilena(context: viewContext)
        userMessage.id = UUID()
        userMessage.contenuto = messageContent
        userMessage.isUser = true
        userMessage.tipo = "user"
        userMessage.dataCreazione = Date()
        userMessage.chat = chat
        
        // Processa la richiesta con Marilena
        Task {
            await processUserRequest(messageContent)
        }
        
        try? viewContext.save()
    }
    
    private func searchInTranscriptions() {
        guard !searchQuery.isEmpty else { return }
        
        Task {
            isLoading = true
            
            if let emailMessage = getEmailMessageFromChat() {
                if let results = await enhancedService.gatherInformationFromTranscriptions(
                    for: emailMessage, 
                    question: searchQuery
                ) {
                    searchResults = [results]
                } else {
                    searchResults = ["Nessuna informazione trovata per: \(searchQuery)"]
                }
            }
            
            isLoading = false
            searchQuery = ""
        }
    }
    
    private func generateDraftFromSearchResults() {
        guard !searchResults.isEmpty else { return }
        
        Task {
            if let emailMessage = getEmailMessageFromChat() {
                let gatheredInfo = searchResults.joined(separator: "\n\n")
                
                if let draft = await enhancedService.generateEmailResponseWithApproval(
                    for: emailMessage,
                    using: gatheredInfo,
                    withTranscription: selectedTranscription
                ) {
                    currentDraft = draft
                    canvasContent = draft.content
                    await enhancedService.saveToCanvasForApproval(draft, in: chat)
                }
            }
        }
    }
    
    private func integrateTranscription(_ transcription: Trascrizione) async {
        selectedTranscription = transcription
        
        // Crea messaggio di integrazione
        let integrationMessage = MessaggioMarilena(context: viewContext)
        integrationMessage.id = UUID()
        integrationMessage.contenuto = """
        🎤 **Trascrizione integrata**
        
        ✅ Ora posso usare questa registrazione per aiutarti a rispondere all'email.
        
        **Cosa posso fare:**
        • Cercare informazioni specifiche nella trascrizione
        • Generare una bozza basata sui contenuti
        • Combinare email + trascrizione per una risposta completa
        
        Dimmi cosa cercare o clicca "Genera Bozza"!
        """
        integrationMessage.isUser = false
        integrationMessage.tipo = "transcription_integrated"
        integrationMessage.dataCreazione = Date()
        integrationMessage.chat = chat
        
        try? viewContext.save()
    }
    
    private func generateFullDraft() async {
        guard let emailMessage = getEmailMessageFromChat() else { return }
        
        isLoading = true
        
        let gatheredInfo = searchResults.isEmpty ? nil : searchResults.joined(separator: "\n\n")
        
        if let draft = await enhancedService.generateEmailResponseWithApproval(
            for: emailMessage,
            using: gatheredInfo,
            withTranscription: selectedTranscription,
            customInstructions: "Genera una risposta completa e professionale"
        ) {
            currentDraft = draft
            canvasContent = draft.content
            await enhancedService.saveToCanvasForApproval(draft, in: chat)
        }
        
        isLoading = false
    }
    
    private func generateStandardResponse(_ type: String) async {
        // Genera risposte template per azioni standard
        let templates = [
            "Più tempo": "Grazie per la tua email. Ho bisogno di un po' più di tempo per darti una risposta completa. Ti ricontatterò entro [specifica tempo].",
            "Programma meeting": "Grazie per la tua email. Penso che sarebbe utile programmare un meeting per discutere di questo. Quando saresti disponibile?",
            "Declina": "Ti ringrazio per la proposta, ma al momento non posso accettare. Ti auguro il meglio per il progetto.",
            "Forward": "Ti inoltro questa email che potrebbe essere di tuo interesse."
        ]
        
        if let template = templates[type] {
            canvasContent = template
            showingCanvasEditor = true
        }
    }
    
    private func processUserRequest(_ request: String) async {
        // Processa la richiesta dell'utente con Marilena
        isLoading = true
        
        // Simula elaborazione Marilena
        let response = """
        🤖 **Marilena risponde:**
        
        Ho capito che vuoi: "\(request)"
        
        \(generateMarilenaResponse(for: request))
        """
        
        let marilenaMessage = MessaggioMarilena(context: viewContext)
        marilenaMessage.id = UUID()
        marilenaMessage.contenuto = response
        marilenaMessage.isUser = false
        marilenaMessage.tipo = "marilena_response"
        marilenaMessage.dataCreazione = Date()
        marilenaMessage.chat = chat
        
        try? viewContext.save()
        isLoading = false
    }
    
    private func generateMarilenaResponse(for request: String) -> String {
        let lowerRequest = request.lowercased()
        
        if lowerRequest.contains("cerca") || lowerRequest.contains("trova") {
            return "Perfetto! Sto cercando nelle tue registrazioni. Usa la barra di ricerca qui sopra per dirmi cosa cercare specificamente."
        } else if lowerRequest.contains("bozza") || lowerRequest.contains("risposta") {
            return "Ottima idea! Clicca su 'Genera Bozza' nelle azioni rapide e io creerò una risposta basata su quello che so."
        } else if lowerRequest.contains("aiuto") || lowerRequest.contains("help") {
            return "Sono qui per aiutarti! Posso cercare nelle tue registrazioni, generare bozze di risposta e gestire la tua corrispondenza. Cosa ti serve?"
        } else {
            return "Interessante! Fammi sapere come posso aiutarti meglio. Posso cercare informazioni, generare risposte o rispondere a domande specifiche."
        }
    }
    
    private func saveCanvasContent(_ content: String) {
        canvasContent = content
    }
    
    private func approveAndSend(_ content: String) {
        canvasContent = content
        showingSendConfirmation = true
    }
    
    private func finalizeAndSend() async {
        do {
            try await enhancedService.approveAndSendDraft(from: chat, modifiedContent: canvasContent)
            currentDraft = nil
            canvasContent = ""
            showingCanvasEditor = false
        } catch {
            // Gestisci errore
            print("Errore invio: \(error)")
        }
    }
    
    private func getEmailMessageFromChat() -> EmailMessage? {
        guard let sender = chat.emailSender,
              let subject = chat.emailSubject,
              let emailId = messaggi.first(where: { $0.emailId != nil })?.emailId else {
            return nil
        }
        
        return EmailMessage(
            id: emailId,
            from: sender,
            to: [],
            subject: subject,
            body: messaggi.first?.contenuto ?? "",
            date: chat.lastEmailDate ?? Date()
        )
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messaggi.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let type: QuickResponseType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text(type.displayName)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct EnhancedEmailMessageView: View {
    let messaggio: MessaggioMarilena
    let onEditCanvas: (String) -> Void
    let onApproveAndSend: (String) -> Void
    
    @State private var isEditing = false
    @State private var editedContent = ""
    
    var body: some View {
        HStack {
            if messaggio.isUser {
                Spacer()
                userMessageView
            } else {
                assistantMessageView
                Spacer()
            }
        }
    }
    
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(messaggio.contenuto ?? "")
                .padding()
                .background(.blue, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.white)
            
            Text(formatTime(messaggio.dataCreazione ?? Date()))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var assistantMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: messaggio.tipo == "marilena_response" ? "brain.head.profile" : "sparkles")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(6)
                    .background(.blue.opacity(0.1), in: Circle())
                
                if isCanvasMessage {
                    canvasMessageView
                } else {
                    regularMessageView
                }
            }
            
            Text(formatTime(messaggio.dataCreazione ?? Date()))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)
        }
    }
    
    private var isCanvasMessage: Bool {
        messaggio.tipo == "email_draft_canvas" && messaggio.emailCanEdit == true
    }
    
    private var canvasMessageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditing {
                VStack(spacing: 8) {
                    TextEditor(text: $editedContent)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    
                    HStack {
                        Button("Annulla") {
                            isEditing = false
                            editedContent = messaggio.emailResponseDraft ?? ""
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Salva") {
                            onEditCanvas(editedContent)
                            isEditing = false
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Approva e Invia") {
                            onApproveAndSend(editedContent)
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(messaggio.contenuto ?? "")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .textSelection(.enabled)
                    
                    HStack {
                        Button("✏️ Modifica nel Canvas") {
                            editedContent = messaggio.emailResponseDraft ?? ""
                            isEditing = true
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("✅ Approva e Invia") {
                            onApproveAndSend(messaggio.emailResponseDraft ?? "")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
    
    private var regularMessageView: some View {
        Text(messaggio.contenuto ?? "")
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .textSelection(.enabled)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Canvas Editor View

struct CanvasEditorView: View {
    @Binding var content: String
    @Binding var isEditing: Bool
    let onSave: (String) -> Void
    let onSend: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $content)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Editor Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button("Salva") {
                            onSave(content)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Invia") {
                            onSend(content)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

// MARK: - Transcription Picker

struct TranscriptionPickerView: View {
    let transcriptions: [Trascrizione]
    @Binding var selectedTranscription: Trascrizione?
    let onSelect: (Trascrizione) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(transcriptions) { transcription in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Registrazione Audio")
                        .font(.headline)
                    
                    Text("\(transcription.paroleTotali) parole")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let date = transcription.dataCreazione {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .onTapGesture {
                    onSelect(transcription)
                    dismiss()
                }
            }
            .navigationTitle("Scegli Trascrizione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}