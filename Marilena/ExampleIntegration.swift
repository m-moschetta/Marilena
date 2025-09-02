import SwiftUI
import CoreData

// MARK: - Esempio Pratico di Integrazione Sistema Chat Email Potenziato
// Questo file mostra come integrare il nuovo sistema nella tua app

// MARK: - 1. Vista Principale con Enhanced Email Chat

struct EmailManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var enhancedService = EnhancedEmailChatService()
    @StateObject private var emailService = EmailService()
    
    @FetchRequest(
        entity: ChatMarilena.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatMarilena.lastEmailDate, ascending: false)],
        predicate: NSPredicate(format: "tipo == %@", "email")
    ) private var emailChats: FetchedResults<ChatMarilena>
    
    var body: some View {
        NavigationStack {
            VStack {
                // Header con statistiche
                emailStatsHeader
                
                // Lista email chats
                List {
                    ForEach(emailChats, id: \.objectID) { chat in
                        NavigationLink(destination: EnhancedEmailChatView(chat: chat)) {
                            EnhancedEmailChatRowView(chat: chat)
                        }
                    }
                }
                .refreshable {
                    await refreshEmails()
                }
            }
            .navigationTitle("🤖 Email con Marilena")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Test Email") {
                        createTestEmail()
                    }
                }
            }
        }
        .onAppear {
            setupEmailNotifications()
        }
    }
    
    // MARK: - Header con Statistiche
    
    private var emailStatsHeader: some View {
        HStack(spacing: 20) {
            VStack {
                Text("\(emailChats.count)")
                    .font(.title2.bold())
                    .foregroundStyle(.blue)
                Text("Chat Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack {
                Text("\(emailChatsAwaitingApproval)")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                Text("In Attesa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack {
                Text("\(emailChatsCompleted)")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
                Text("Completate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties
    
    private var emailChatsAwaitingApproval: Int {
        emailChats.filter { $0.workflowStatus == .awaitingApproval }.count
    }
    
    private var emailChatsCompleted: Int {
        emailChats.filter { $0.workflowStatus == .completed }.count
    }
    
    // MARK: - Actions
    
    private func refreshEmails() async {
        // TODO: Implement email refresh functionality
        print("Email refresh not yet implemented")
    }
    
    private func setupEmailNotifications() {
        NotificationCenter.default.addObserver(
            forName: .newEmailReceived,
            object: nil,
            queue: .main
        ) { notification in
            if let email = notification.object as? EmailMessage {
                handleNewEmail(email)
            }
        }
    }
    
    private func handleNewEmail(_ email: EmailMessage) {
        Task {
            _ = await enhancedService.startEmailResponseWorkflow(for: email)
        }
    }
    
    private func createTestEmail() {
        // Crea email di test per demo
        let testEmail = EmailMessage(
            id: UUID().uuidString,
            from: "test@example.com",
            to: ["me@example.com"],
            subject: "Test Email - Progetto Alpha",
            body: "Ciao, volevo aggiornarti sul progetto Alpha. Possiamo programmare una call per martedì?",
            date: Date()
        )
        
        Task {
            _ = await enhancedService.startEmailResponseWorkflow(for: testEmail)
        }
    }
}

// MARK: - 2. Row View Potenziata per Email Chats

struct EnhancedEmailChatRowView: View {
    let chat: ChatMarilena
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Avatar con status
                ZStack {
                    Circle()
                        .fill(workflowStatusColor)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: workflowStatusIcon)
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chat.emailSender ?? "Mittente Sconosciuto")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(chat.emailSubject ?? "Nessun Oggetto")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Text(workflowStatusText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(workflowStatusColor.opacity(0.2))
                        .foregroundStyle(workflowStatusColor)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let lastDate = chat.lastEmailDate {
                        Text(lastDate.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    // Indicators
                    HStack(spacing: 4) {
                        if chat.hasTranscriptionContext {
                            Image(systemName: "waveform")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        
                        if !chat.canvasDrafts.isEmpty {
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        
                        Text("\(chat.messaggi?.count ?? 0)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Quick preview del ultimo messaggio
            if let lastMessage = chat.lastMessage?.contenuto {
                Text(lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 52)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var workflowStatusColor: Color {
        Color(chat.workflowStatus.color)
    }
    
    private var workflowStatusIcon: String {
        chat.workflowStatus.icon
    }
    
    private var workflowStatusText: String {
        chat.workflowStatus.displayName
    }
}

// MARK: - 3. Esempio Workflow Completo Step-by-Step

struct EmailWorkflowDemoView: View {
    @State private var currentStep = 0
    @State private var isWorkflowRunning = false
    @StateObject private var enhancedService = EnhancedEmailChatService()
    
    private let workflowSteps = [
        "📧 Email ricevuta",
        "🤖 Marilena si presenta",
        "🔍 Ricerca nelle trascrizioni",
        "✍️ Generazione bozza AI",
        "📝 Editing nel canvas",
        "✅ Approvazione utente",
        "📤 Invio automatico",
        "🎉 Completamento workflow"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🤖 Demo Workflow Marilena")
                .font(.title.bold())
            
            // Progress indicator
            VStack(spacing: 12) {
                ForEach(0..<workflowSteps.count, id: \.self) { index in
                    HStack {
                        Circle()
                            .fill(stepColor(index))
                            .frame(width: 20, height: 20)
                        
                        Text(workflowSteps[index])
                            .font(.body)
                            .foregroundStyle(stepColor(index))
                        
                        Spacer()
                        
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        } else if index == currentStep && isWorkflowRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // Controls
            HStack(spacing: 20) {
                Button("Avvia Demo") {
                    startWorkflowDemo()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorkflowRunning)
                
                Button("Reset") {
                    resetDemo()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step Colors
    
    private func stepColor(_ index: Int) -> Color {
        if index < currentStep {
            return .green
        } else if index == currentStep {
            return .blue
        } else {
            return .gray
        }
    }
    
    // MARK: - Demo Actions
    
    private func startWorkflowDemo() {
        isWorkflowRunning = true
        currentStep = 0
        
        // Simula ogni step del workflow
        Task {
            for step in 0..<workflowSteps.count {
                await MainActor.run {
                    currentStep = step
                }
                
                // Simula processing time per ogni step
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 secondi
            }
            
            await MainActor.run {
                isWorkflowRunning = false
            }
        }
    }
    
    private func resetDemo() {
        currentStep = 0
        isWorkflowRunning = false
    }
}

// MARK: - 4. Extension per Chat Helper Methods

extension ChatMarilena {
    var lastMessage: MessaggioMarilena? {
        guard let messages = messaggi?.allObjects as? [MessaggioMarilena] else { return nil }
        return messages
            .sorted { ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) }
            .first
    }
    
    var hasActiveCanvas: Bool {
        return !canvasDrafts.isEmpty && canvasDrafts.contains { $0.emailCanEdit }
    }
    
    var transcriptionCount: Int {
        return linkedTranscriptions.count
    }
    
    var workflowProgress: Double {
        switch workflowStatus {
        case .initial: return 0.1
        case .contextGathered: return 0.3
        case .draftGenerated: return 0.6
        case .awaitingApproval: return 0.8
        case .sent, .completed: return 1.0
        }
    }
}

// MARK: - 5. Integration Preview

struct IntegrationPreviewView: View {
    var body: some View {
        TabView {
            EmailManagementView()
                .tabItem {
                    Label("Email Chat", systemImage: "envelope.badge")
                }
            
            EmailWorkflowDemoView()
                .tabItem {
                    Label("Demo", systemImage: "play.circle")
                }
        }
    }
}

// MARK: - 6. Main App Integration Example

struct EnhancedEmailApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            IntegrationPreviewView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

// MARK: - 7. Test Data Helper

struct EmailTestDataHelper {
    static func createSampleEmailChat(in context: NSManagedObjectContext) -> ChatMarilena {
        let chat = ChatMarilena(context: context)
        chat.id = UUID()
        chat.dataCreazione = Date()
        chat.titolo = "Chat Email di Test"
        chat.emailSender = "cliente@test.com"
        chat.emailSubject = "Progetto Alpha - Conferma Meeting"
        chat.tipo = "email"
        chat.lastEmailDate = Date()
        
        // Messaggio iniziale email
        let emailMessage = MessaggioMarilena(context: context)
        emailMessage.id = UUID()
        emailMessage.contenuto = """
        📧 Email da cliente@test.com
        Oggetto: Progetto Alpha - Conferma Meeting
        
        Ciao! Volevo confermare il meeting di martedì per discutere del progetto Alpha.
        Hai avuto modo di rivedere i documenti che ti ho inviato?
        
        Grazie!
        """
        emailMessage.isUser = false
        emailMessage.tipo = "email_context"
        emailMessage.dataCreazione = Date()
        emailMessage.emailId = UUID().uuidString
        emailMessage.chat = chat
        
        // Risposta Marilena
        let marilenaMessage = MessaggioMarilena(context: context)
        marilenaMessage.id = UUID()
        marilenaMessage.contenuto = """
        🤖 Ciao! Sono Marilena, la tua assistente AI.
        
        Ho ricevuto questa email da cliente@test.com sul progetto Alpha.
        
        Posso aiutarti a:
        🔍 Cercare informazioni nelle tue registrazioni
        ✍️ Generare una bozza di risposta
        📅 Programmare il meeting
        
        Cosa vuoi che faccia?
        """
        marilenaMessage.isUser = false
        marilenaMessage.tipo = "marilena_context"
        marilenaMessage.dataCreazione = Date().addingTimeInterval(60)
        marilenaMessage.chat = chat
        
        try? context.save()
        return chat
    }
    
    static func createSampleTranscription(in context: NSManagedObjectContext) -> Trascrizione {
        let trascrizione = Trascrizione(context: context)
        trascrizione.id = UUID()
        trascrizione.dataCreazione = Date().addingTimeInterval(-86400) // 1 giorno fa
        trascrizione.testoCompleto = """
        Oggi abbiamo discusso del progetto Alpha con il team.
        Il budget approvato è di 50mila euro e dobbiamo completare entro fine marzo.
        I documenti principali sono la specifica tecnica e il piano di progetto.
        Il cliente è molto interessato e vuole un meeting settimanale per aggiornamenti.
        Martedì prossimo faremo il kickoff ufficiale alle 14:00.
        """
        trascrizione.paroleTotali = 45
        trascrizione.accuratezza = 0.95
        trascrizione.linguaRilevata = "it"
        
        try? context.save()
        return trascrizione
    }
}