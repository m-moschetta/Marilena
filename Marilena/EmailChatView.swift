import SwiftUI
import CoreData

// MARK: - Email Chat View
// Vista specializzata per le chat mail con analisi thread e generazione risposte

public struct EmailChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var chat: ChatMarilena
    @StateObject private var emailChatService = EmailChatService()
    @StateObject private var aiService = EmailAIService()
    
    @FetchRequest private var messaggi: FetchedResults<MessaggioMarilena>
    @State private var testo = ""
    @State private var isLoading = false
    @State private var showingThreadAnalysis = false
    @State private var threadAnalysis: EmailThreadAnalysis?
    @State private var selectedResponseType: EmailResponseType?
    @State private var showingCustomPrompt = false
    @State private var customPrompt = ""
    @State private var showingSendSheet = false
    @State private var responseToSend = ""
    
    // MARK: - Initialization
    
    public init(chat: ChatMarilena) {
        self.chat = chat
        self._messaggi = FetchRequest(
            entity: MessaggioMarilena.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \MessaggioMarilena.dataCreazione, ascending: true)],
            predicate: NSPredicate(format: "chat == %@", chat)
        )
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header con info email
            emailChatHeader
            
            Divider()
                .background(Color(UIColor.separator))
            
            // Contenuto chat
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Messaggi esistenti
                        ForEach(messaggi, id: \.id) { messaggio in
                            EmailMessageView(messaggio: messaggio)
                        }
                        
                        // Indicatore caricamento
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Analizzando email...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: messaggi.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // Input area
            emailInputArea
        }
        .navigationTitle(chat.emailSender ?? "Chat Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingThreadAnalysis = true
                } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundStyle(.blue)
                }
            }
        }
        .onAppear {
            analyzeThread()
        }
        .sheet(isPresented: $showingThreadAnalysis) {
            EmailThreadAnalysisView(analysis: threadAnalysis)
        }
        .sheet(isPresented: $showingCustomPrompt) {
            CustomPromptView(
                prompt: $customPrompt,
                onGenerate: generateCustomResponse,
                onCancel: { showingCustomPrompt = false }
            )
        }
        .alert("Invia Risposta", isPresented: $showingSendSheet) {
            Button("Invia") {
                sendEmailResponse()
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Sei sicuro di voler inviare questa risposta email?")
        }
    }
    
    // MARK: - Header
    
    private var emailChatHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Avatar mittente
                Circle()
                    .fill(.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text((chat.emailSender?.prefix(1) ?? "?").uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chat.emailSender ?? "Mittente sconosciuto")
                        .font(.headline)
                    
                    Text(chat.emailSubject ?? "Nessun oggetto")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Indicatori
                VStack(alignment: .trailing, spacing: 2) {
                    if let lastDate = chat.lastEmailDate {
                        Text(formatDate(lastDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Badge messaggi
                    Text("\(messaggi.count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            
            // Quick actions
            if let analysis = threadAnalysis {
                HStack(spacing: 8) {
                    EmailQuickResponseButton(
                        title: "Sì",
                        icon: "checkmark.circle.fill",
                        gradient: .green,
                        action: { generateResponse(.yes) }
                    )
                    
                    EmailQuickResponseButton(
                        title: "No",
                        icon: "xmark.circle.fill",
                        gradient: .red,
                        action: { generateResponse(.no) }
                    )
                    
                    EmailQuickResponseButton(
                        title: "Personalizza",
                        icon: "pencil.circle.fill",
                        gradient: .blue,
                        action: { generateResponse(.custom) }
                    )
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .liquidGlass(.subtle)
        .padding(.horizontal)
    }
    
    // MARK: - Input Area
    
    private var emailInputArea: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Scrivi la tua risposta...", text: $testo, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.blue)
                }
                .disabled(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Pulsanti azione
            HStack {
                Button("Analizza Thread") {
                    analyzeThread()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                Spacer()
                
                Button("Invia Email") {
                    showingSendSheet = true
                    responseToSend = testo
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
                .disabled(testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .liquidGlass(.subtle)
        .padding(.horizontal)
    }
    
    // MARK: - Methods
    
    private func sendMessage() {
        guard !testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messaggio = MessaggioMarilena(context: viewContext)
        messaggio.id = UUID()
        messaggio.contenuto = testo
        messaggio.isUser = true
        messaggio.tipo = "user"
        messaggio.dataCreazione = Date()
        messaggio.chat = chat
        
        testo = ""
        
        do {
            try viewContext.save()
        } catch {
            print("❌ EmailChatView: Errore salvataggio messaggio: \(error)")
        }
    }
    
    private func analyzeThread() {
        Task {
            isLoading = true
            threadAnalysis = await emailChatService.analyzeEmailThread(for: chat)
            isLoading = false
        }
    }
    
    private func generateResponse(_ type: EmailResponseType) {
        selectedResponseType = type
        
        Task {
            isLoading = true
            
            switch type {
            case .yes:
                if let draft = await aiService.generateDraft(
                    for: getLastEmail(),
                    context: "Genera una risposta positiva e accettante. Sii professionale e cordiale."
                ) {
                    testo = draft.content
                }
            case .no:
                if let draft = await aiService.generateDraft(
                    for: getLastEmail(),
                    context: "Genera una risposta negativa ma educata. Spiega gentilmente perché non puoi accettare."
                ) {
                    testo = draft.content
                }
            case .custom:
                showingCustomPrompt = true
            }
            
            isLoading = false
        }
    }
    
    private func generateCustomResponse() {
        Task {
            isLoading = true
            
            if let draft = await aiService.generateCustomResponse(
                for: getLastEmail(),
                basedOn: nil,
                withPrompt: customPrompt
            ) {
                testo = draft.content
                showingCustomPrompt = false
                customPrompt = ""
            }
            
            isLoading = false
        }
    }
    
    private func sendEmailResponse() {
        Task {
            do {
                try await emailChatService.sendEmailResponse(from: chat, response: responseToSend)
                testo = ""
                responseToSend = ""
            } catch {
                print("❌ EmailChatView: Errore invio email: \(error)")
            }
        }
    }
    
    private func getLastEmail() -> EmailMessage {
        // Crea un'EmailMessage dal chat per l'analisi AI
        return EmailMessage(
            id: chat.id?.uuidString ?? "",
            from: chat.emailSender ?? "",
            to: [],
            subject: chat.emailSubject ?? "",
            body: messaggi.last?.contenuto ?? "",
            date: chat.lastEmailDate ?? Date()
        )
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messaggi.last {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Email Message View

struct EmailMessageView: View {
    let messaggio: MessaggioMarilena
    
    var body: some View {
        HStack {
            if messaggio.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(messaggio.contenuto ?? "")
                        .padding()
                        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    
                    if let data = messaggio.dataCreazione {
                        Text(formatDate(data))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(messaggio.contenuto ?? "")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                    
                    if let data = messaggio.dataCreazione {
                        Text(formatDate(data))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Email Thread Analysis View

struct EmailThreadAnalysisView: View {
    let analysis: EmailThreadAnalysis?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let analysis = analysis {
                        // Statistiche
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Statistiche Thread")
                                .font(.headline)
                            
                            HStack {
                                EmailStatItem(title: "Email Totali", value: "\(analysis.totalEmails)")
                                EmailStatItem(title: "Tono", value: analysis.conversationTone)
                                EmailStatItem(title: "Urgenza", value: analysis.urgency.displayName)
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        
                        // Suggerimento
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggerimento AI")
                                .font(.headline)
                            
                            HStack {
                                Image(systemName: analysis.suggestedResponseType.icon)
                                    .foregroundStyle(analysis.suggestedResponseType.color)
                                Text("Risposta \(analysis.suggestedResponseType.displayName.lowercased())")
                                    .font(.subheadline)
                                    .foregroundStyle(analysis.suggestedResponseType.color)
                            }
                            .padding()
                            .background(analysis.suggestedResponseType.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        
                        // Contesto
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contesto Conversazione")
                                .font(.headline)
                            
                            Text(analysis.context)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("Analisi non disponibile")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Analisi Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Email Stat Item

struct EmailStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Email Quick Response Button

struct EmailQuickResponseButton: View {
    let title: String
    let icon: String
    let gradient: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(gradient.opacity(0.1), in: Capsule())
            .foregroundStyle(gradient)
        }
        .buttonStyle(.plain)
    }
} 