#if false
import SwiftUI
import CoreData

// MARK: - Chat Integration

struct EmailChatResponseView: View {
    let emailWithContext: EmailWithContext
    @ObservedObject var contextualService: EmailContextualResponseService
    @StateObject private var chatService = EmailChatService()
    @Environment(\.dismiss) private var dismiss

    @State private var chatCreated = false
    @State private var showingChat = false

    var body: some View {
        NavigationView {
            VStack {
                if !chatCreated {
                    // Mostra contesto prima di aprire la chat
                    emailContextPreview
                } else {
                    // Una volta creata la chat, mostra la vista principale
                    mainChatView
                }
            }
            .navigationTitle("Rispondi via Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apri Chat") {
                        showingChat = true
                    }
                    .fontWeight(.semibold)
                    .disabled(!chatCreated)
                }
            }
            .sheet(isPresented: $showingChat) {
                if let chat = chatService.currentEmailChat {
                    ModularChatView(chat: chat)
                        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                }
            }
            .task {
                await createOrLoadChat()
            }
        }
    }

    private var emailContextPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Email originale
                originalEmailSection

                // Contesto disponibile
                if emailWithContext.context.hasRichContext {
                    contextSection
                }

                // Azioni
                actionButtons
            }
            .padding()
        }
    }

    private var mainChatView: some View {
        VStack {
            Text("Chat creata con successo!")
                .font(.headline)
                .foregroundColor(.green)

            Text("La chat è stata configurata con tutto il contesto disponibile.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .padding()
    }

    private var originalEmailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Email Originale")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Da", value: emailWithContext.email.from)
                InfoRow(label: "Oggetto", value: emailWithContext.email.subject)
                InfoRow(label: "Data", value: formatDate(emailWithContext.email.date))

                Divider()

                Text(emailWithContext.email.body)
                    .font(.body)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contesto Incluso nella Chat")
                .font(.headline)

            // Eventi
            if !emailWithContext.context.relatedEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Eventi Recenti", systemImage: "calendar")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(emailWithContext.context.relatedEvents.prefix(3), id: \.id) { event in
                        EventContextRow(event: event)
                    }
                }
            }

            // Registrazioni
            if !emailWithContext.context.relatedRecordings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Registrazioni", systemImage: "mic.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 8)

                    ForEach(Array(emailWithContext.context.relatedRecordings.prefix(3).enumerated()), id: \.element.objectID) { index, recording in
                        RecordingContextRow(recording: recording)
                    }
                }
            }

            // Trascrizioni disponibili
            if !emailWithContext.context.transcriptions.isEmpty {
                Label("\(emailWithContext.context.transcriptions.count) trascrizioni incluse", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !chatCreated {
                Button {
                    Task {
                        await createChatWithContext()
                    }
                } label: {
                    HStack {
                        Image(systemName: "message.circle.fill")
                        Text("Crea Chat con Contesto")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                Button {
                    showingChat = true
                } label: {
                    HStack {
                        Image(systemName: "message.circle.fill")
                        Text("Apri Chat")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
    }

    private func createOrLoadChat() async {
        // Prima cerca se esiste già una chat con questo mittente
        if let existingChat = await chatService.findExistingEmailChat(for: emailWithContext.email.from) {
            chatService.currentEmailChat = existingChat
            await updateChatWithContext(existingChat)
            chatCreated = true
        } else {
            // Crea nuova chat
            if let newChat = await chatService.createEmailChat(for: emailWithContext.email) {
                chatService.currentEmailChat = newChat
                await updateChatWithContext(newChat)
                chatCreated = true
            }
        }
    }

    private func createChatWithContext() async {
        // Crea nuova chat con tutto il contesto
        if let chat = await chatService.createEmailChat(for: emailWithContext.email) {
            chatService.currentEmailChat = chat
            await updateChatWithContext(chat)
            chatCreated = true
        }
    }

    private func updateChatWithContext(_ chat: ChatMarilena) async {
        // Aggiungi messaggio di contesto alla chat
        await addContextMessageToChat(chat)
    }

    private func addContextMessageToChat(_ chat: ChatMarilena) async {
        let contextMessage = MessaggioMarilena(context: PersistenceController.shared.container.viewContext)
        contextMessage.id = UUID()
        contextMessage.contenuto = buildContextMessage()
        contextMessage.isUser = false
        contextMessage.tipo = "email_context"
        contextMessage.dataCreazione = Date()
        contextMessage.emailId = emailWithContext.email.id
        contextMessage.chat = chat

        do {
            try PersistenceController.shared.container.viewContext.save()
        } catch {
            print("❌ Errore salvataggio messaggio contesto: \(error)")
        }
    }

    private func buildContextMessage() -> String {
        var message = """
        📧 **Email da \(emailWithContext.email.from)**

        **Oggetto:** \(emailWithContext.email.subject)
        **Data:** \(formatDate(emailWithContext.email.date))

        **Contenuto originale:**
        \(emailWithContext.email.body)

        """

        // Aggiungi contesto eventi
        if !emailWithContext.context.relatedEvents.isEmpty {
            message += """

            📅 **Eventi recenti con questo contatto:**
            """
            for event in emailWithContext.context.relatedEvents.prefix(3) {
                message += """
            • \(event.title) (\(formatDate(event.startDate)))
            """
            }
        }

        // Aggiungi contesto registrazioni
        if !emailWithContext.context.relatedRecordings.isEmpty {
            message += """

            🎙️ **Registrazioni durante incontri:**
            """
            for recording in emailWithContext.context.relatedRecordings.prefix(2) {
                message += """
            • \(recording.titolo ?? "Registrazione senza titolo") (\(Int(recording.durata / 60)) min)
            """
            }
        }

        message += """

        💭 **Ora puoi rispondere tramite questa chat con tutto il contesto disponibile.**
        """

        return message
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Email Response Suggestions View
/// Vista che mostra le email che necessitano risposta con suggerimenti contestuali intelligenti

public struct EmailResponseSuggestionsView: View {
    @StateObject private var contextualService: EmailContextualResponseService
    @StateObject private var emailService = EmailService()
    @State private var selectedEmail: EmailWithContext?
    @State private var showingResponse = false
    @State private var isLoadingInitial = true
    
    private let calendarManager: CalendarManager
    private let context: NSManagedObjectContext
    
    public init(calendarManager: CalendarManager, context: NSManagedObjectContext) {
        self.calendarManager = calendarManager
        self.context = context
        
        let aiService = EmailAIService()
        _contextualService = StateObject(wrappedValue: EmailContextualResponseService(
            aiService: aiService,
            calendarManager: calendarManager,
            context: context
        ))
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                if isLoadingInitial {
                    loadingView
                } else if contextualService.needsResponseEmails.isEmpty {
                    emptyStateView
                } else {
                    emailsList
                }
            }
            .navigationTitle("Email da Rispondere")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(item: $selectedEmail) { emailWithContext in
                EmailChatResponseView(
                    emailWithContext: emailWithContext,
                    contextualService: contextualService
                )
            }
            .task {
                await loadEmailsAndAnalyze()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analisi email in corso...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Sto identificando le email che necessitano risposta\ne raccogliendo il contesto da eventi e registrazioni")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Tutto a Posto!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Non ci sono email che necessitano risposta al momento")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var emailsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Statistiche rapide
                statsCard
                
                // Email ordinate per priorità
                ForEach(contextualService.needsResponseEmails) { emailWithContext in
                    EmailContextCard(emailWithContext: emailWithContext)
                        .onTapGesture {
                            selectedEmail = emailWithContext
                        }
                }
            }
            .padding()
        }
    }
    
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Panoramica")
                .font(.headline)
            
            HStack(spacing: 20) {
                EmailResponseStatItem(
                    icon: "envelope.badge",
                    value: "\(contextualService.needsResponseEmails.count)",
                    label: "Da Rispondere",
                    color: .blue
                )
                
                EmailResponseStatItem(
                    icon: "calendar",
                    value: "\(contextualService.needsResponseEmails.filter { !$0.context.relatedEvents.isEmpty }.count)",
                    label: "Con Eventi",
                    color: .orange
                )
                
                EmailResponseStatItem(
                    icon: "mic.fill",
                    value: "\(contextualService.needsResponseEmails.filter { !$0.context.relatedRecordings.isEmpty }.count)",
                    label: "Con Registrazioni",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                await loadEmailsAndAnalyze()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(contextualService.isAnalyzing)
    }
    
    // MARK: - Methods
    
    private func loadEmailsAndAnalyze() async {
        isLoadingInitial = true
        
        // Carica email (solo se c'è un account configurato)
        if let account = emailService.currentAccount {
            await emailService.loadEmails(for: account)
        }
        
        // Carica eventi calendario
        await calendarManager.loadEvents()
        
        // Analizza email per trovare quelle che necessitano risposta
        await contextualService.analyzeEmailsForResponse(emailService.emails)
        
        // Genera risposte per tutte
        await contextualService.generateAllContextualResponses()
        
        isLoadingInitial = false
    }
}

// MARK: - Email Context Card

struct EmailContextCard: View {
    let emailWithContext: EmailWithContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header con priorità
            HStack {
                Label(emailWithContext.priority.displayName, systemImage: emailWithContext.priority.icon)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(emailWithContext.priority.color.opacity(0.2))
                    .foregroundColor(emailWithContext.priority.color)
                    .cornerRadius(8)
                
                Spacer()
                
                Text(emailWithContext.email.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Mittente e oggetto
            VStack(alignment: .leading, spacing: 4) {
                Text(emailWithContext.email.from)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(emailWithContext.email.subject)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Anteprima corpo
            Text(emailWithContext.email.body)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.top, 4)
            
            // Indicatori di contesto
            HStack(spacing: 12) {
                if !emailWithContext.context.relatedEvents.isEmpty {
                    ContextBadge(
                        icon: "calendar",
                        count: emailWithContext.context.relatedEvents.count,
                        label: "eventi",
                        color: .blue
                    )
                }
                
                if !emailWithContext.context.relatedRecordings.isEmpty {
                    ContextBadge(
                        icon: "mic.fill",
                        count: emailWithContext.context.relatedRecordings.count,
                        label: "registrazioni",
                        color: .red
                    )
                }
                
                if !emailWithContext.context.transcriptions.isEmpty {
                    ContextBadge(
                        icon: "doc.text",
                        count: emailWithContext.context.transcriptions.count,
                        label: "trascrizioni",
                        color: .green
                    )
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Supporting Views

struct EmailResponseStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ContextBadge: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count) \(label)")
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(6)
    }
}

// MARK: - Email Response Detail View

struct EmailResponseDetailView: View {
    let emailWithContext: EmailWithContext
    @ObservedObject var contextualService: EmailContextualResponseService
    @Environment(\.dismiss) private var dismiss
    
    @State private var responseText = ""
    @State private var isLoadingResponse = true
    @State private var showingContext = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Email originale
                    originalEmailSection
                    
                    // Contesto disponibile
                    if emailWithContext.context.hasRichContext {
                        contextSection
                    }
                    
                    // Risposta suggerita
                    suggestedResponseSection
                }
                .padding()
            }
            .navigationTitle("Risposta Suggerita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Invia") {
                        // TODO: Implementare invio email
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(responseText.isEmpty)
                }
            }
            .task {
                await loadResponse()
            }
        }
    }
    
    // MARK: - Sections
    
    private var originalEmailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Email Originale")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Da", value: emailWithContext.email.from)
                InfoRow(label: "Oggetto", value: emailWithContext.email.subject)
                InfoRow(label: "Data", value: formatDate(emailWithContext.email.date))
                
                Divider()
                
                Text(emailWithContext.email.body)
                    .font(.body)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Contesto Disponibile")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    withAnimation {
                        showingContext.toggle()
                    }
                } label: {
                    Image(systemName: showingContext ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            if showingContext {
                // Eventi
                if !emailWithContext.context.relatedEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Eventi Recenti", systemImage: "calendar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ForEach(emailWithContext.context.relatedEvents.prefix(3), id: \.id) { event in
                            EventContextRow(event: event)
                        }
                    }
                }
                
                // Registrazioni
                if !emailWithContext.context.relatedRecordings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Registrazioni", systemImage: "mic.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)
                        
                        ForEach(Array(emailWithContext.context.relatedRecordings.prefix(3).enumerated()), id: \.element.objectID) { index, recording in
                            RecordingContextRow(recording: recording)
                        }
                    }
                }
                
                // Trascrizioni disponibili
                if !emailWithContext.context.transcriptions.isEmpty {
                    Label("\(emailWithContext.context.transcriptions.count) trascrizioni disponibili", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var suggestedResponseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Risposta Suggerita")
                    .font(.headline)
                
                Spacer()
                
                if let suggestion = contextualService.contextualResponses[emailWithContext.email.id] {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                            .font(.caption)
                        Text("Confidenza: \(suggestion.confidencePercentage)%")
                            .font(.caption)
                    }
                    .foregroundColor(suggestion.confidence >= 0.7 ? .green : .orange)
                }
            }
            
            if isLoadingResponse {
                HStack {
                    ProgressView()
                    Text("Generazione risposta contestuale...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                TextEditor(text: $responseText)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                
                Text("Puoi modificare la risposta prima di inviarla")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Methods
    
    private func loadResponse() async {
        if let existingResponse = contextualService.contextualResponses[emailWithContext.email.id] {
            responseText = existingResponse.suggestedResponse
            isLoadingResponse = false
        } else {
            if let response = await contextualService.generateContextualResponse(for: emailWithContext) {
                responseText = response.suggestedResponse
            }
            isLoadingResponse = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Event Context Row

struct EventContextRow: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(formatDate(event.startDate)) • \(event.durationInMinutes) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let location = event.location {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Recording Context Row

struct RecordingContextRow: View {
    let recording: RegistrazioneAudio
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.titolo ?? "Registrazione")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let date = recording.dataCreazione {
                    Text("\(formatDate(date)) • \(Int(recording.durata / 60)) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}
#endif
