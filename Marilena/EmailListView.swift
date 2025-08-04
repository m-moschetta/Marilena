import SwiftUI
import Combine
import CoreData

// MARK: - iOS 26 Enhanced Email List View
// Vista principale modernizzata per iOS 26 con Liquid Glass e SwipeActions native

public struct EmailListView: View {
    @StateObject private var emailService = EmailService()
    @StateObject private var aiService = EmailAIService()
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    @State private var selectedEmail: EmailMessage?
    @State private var showingEmailDetail = false
    @State private var showingLogin = false
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedCategory: EmailCategory? = nil // Filtro AI attivo

    @State private var useAppleMailStyle = true
    @State private var showingEmailSettings = false
    
    // iOS 26 States
    @State private var showingComposeSheet = false
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Helper Functions
    private func destinationView(for email: EmailMessage) -> some View {
        Group {
            if useAppleMailStyle {
                AppleMailDetailView(
                    email: email,
                    emailService: emailService,
                    aiService: aiService
                )
            } else {
                EmailDetailView(
                    email: email,
                    aiService: aiService
                )
            }
        }
    }
    
    /// Crea la vista di destinazione per una conversazione
    private func destinationViewForConversation(_ conversation: EmailConversation) -> some View {
        // Temporaneamente usa la prima email della conversazione per compatibilità
        Group {
            if let firstEmail = conversation.messages.first {
                destinationView(for: firstEmail)
            } else {
                Text("Conversazione vuota")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // NUOVO: Conversazioni filtrate per il threading
    private var filteredConversations: [EmailConversation] {
        var conversations = emailService.emailConversations
        
        // Filtra per categoria AI
        if let selectedCategory = selectedCategory {
            conversations = conversations.filter { conversation in
                conversation.messages.contains { message in
                    message.category == selectedCategory
                }
            }
        }
        
        // Filtra per ricerca testuale
        if !searchText.isEmpty {
            conversations = conversations.filter { conversation in
                conversation.subject.localizedCaseInsensitiveContains(searchText) ||
                conversation.participantsDisplay.localizedCaseInsensitiveContains(searchText) ||
                conversation.messages.contains { message in
                    message.body.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        return conversations.sorted { $0.lastActivity > $1.lastActivity }
    }
    
    private var filteredEmails: [EmailMessage] {
        var emails = emailService.emails
        
        // Escludi email archiviate e eliminate
        emails = emails.filter { email in
            // Controlla nella cache CoreData se l'email è archiviata o eliminata
            let context = PersistenceController.shared.container.viewContext
            let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", email.id)
            
            do {
                let cachedEmails = try context.fetch(fetchRequest)
                if let cachedEmail = cachedEmails.first {
                    return !(cachedEmail.isArchived || cachedEmail.isMarkedAsDeleted)
                }
            } catch {
                print("❌ EmailListView: Errore controllo stato email: \(error)")
            }
            
            return true // Se non trovata nella cache, mostra l'email
        }
        
        // Filtra per categoria AI
        if let selectedCategory = selectedCategory {
            emails = emails.filter { email in
                email.category == selectedCategory
            }
        }
        
        // Filtra per ricerca testuale
        if !searchText.isEmpty {
            emails = emails.filter { email in
                email.subject.localizedCaseInsensitiveContains(searchText) ||
                email.from.localizedCaseInsensitiveContains(searchText) ||
                email.body.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return emails.sorted { $0.date > $1.date }
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if emailService.isAuthenticated {
                    modernEmailListContent
                } else {
                    loginContent
                }
            }
            .navigationTitle(emailService.currentAccount?.email ?? "Email")
            .navigationBarTitleDisplayMode(.large)
            .headerAccessibility(
                label: "Email principale di \(emailService.currentAccount?.email ?? "nessun account")",
                hint: "Schermata principale delle email"
            )
            .searchable(text: $searchText, prompt: "Cerca email...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Account: \(emailService.currentAccount?.email ?? "Non connesso")") { }
                            .standardAccessibility(
                                label: "Account corrente: \(emailService.currentAccount?.email ?? "Non connesso")",
                                hint: "Informazioni account email"
                            )
                        
                        Button("Disconnetti") {
                            emailService.disconnect()
                            accessibilityManager.announce("Account disconnesso")
                        }
                        .buttonAccessibility(
                            label: "Disconnetti account",
                            hint: "Esci dall'account email corrente"
                        )
                        
                        Divider()
                        
                        // NUOVO: Toggle Threading
                        Button {
                            Task {
                                emailService.isThreadingEnabled.toggle()
                                await emailService.organizeEmailsIntoConversations()
                                hapticFeedback.impactOccurred()
                                
                                let status = emailService.isThreadingEnabled ? "abilitato" : "disabilitato"
                                accessibilityManager.announce("Raggruppamento conversazioni \(status)")
                            }
                        } label: {
                            HStack {
                                Image(systemName: emailService.isThreadingEnabled ? "checkmark.square" : "square")
                                Text("🧵 Conversazioni")
                            }
                        }
                        .buttonAccessibility(
                            label: emailService.isThreadingEnabled ? "Disabilita conversazioni" : "Abilita conversazioni",
                            hint: "Attiva o disattiva il raggruppamento delle email in conversazioni"
                        )
                        
                        Divider()
                        
                        Button("🧪 Test: Simula Nuova Email") {
                            Task {
                                await emailService.simulateNewEmail()
                                accessibilityManager.announce("Nuova email simulata aggiunta")
                            }
                        }
                        .foregroundStyle(.orange)
                        .buttonAccessibility(
                            label: "Simula nuova email",
                            hint: "Funzione di test per aggiungere email fittizia"
                        )
                    } label: {
                        Image(systemName: "gear.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonAccessibility(
                        label: "Menu impostazioni",
                        hint: "Apri menu per gestire account e impostazioni"
                    )
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // NUOVO: Indicatori stato offline/sync
                        HStack(spacing: 6) {
                            // Indicatore operazioni pending
                            if emailService.pendingOperationsCount > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption2)
                                    Text("\(emailService.pendingOperationsCount)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                                .standardAccessibility(
                                    label: "\(emailService.pendingOperationsCount) operazioni in attesa",
                                    hint: "Email in coda per invio quando torni online"
                                )
                            }
                            
                            // Indicatore stato connessione
                            Circle()
                                .fill(emailService.isOnline ? .green : .red)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 1)
                                )
                                .standardAccessibility(
                                    label: emailService.isOnline ? "Online" : "Offline",
                                    hint: emailService.isOnline ? "Connesso a internet" : "Nessuna connessione internet"
                                )
                            
                            // Indicatore sync status
                            if case .syncing = emailService.syncStatus {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 12, height: 12)
                                    .standardAccessibility(
                                        label: "Sincronizzazione in corso",
                                        hint: "Le email si stanno aggiornando"
                                    )
                            }
                        }
                        
                        // Pulsante compose
                        Button(action: {
                            showingComposeSheet = true
                            hapticFeedback.impactOccurred()
                            accessibilityManager.announce("Apertura composizione nuova email")
                        }) {
                            Image(systemName: "square.and.pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .symbolRenderingMode(.hierarchical)
                                .symbolEffect(.bounce, value: false)
                        }
                        .buttonAccessibility(
                            label: "Componi email",
                            hint: "Crea una nuova email"
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingComposeSheet) {
            ComposeEmailView()
        }
        .sheet(isPresented: $showingEmailSettings) {
            EmailSettingsView()
        }
        .alert("Errore", isPresented: .constant(emailService.error != nil)) {
            Button("OK") {
                emailService.error = nil
            }
        } message: {
            Text(emailService.error ?? "")
        }
        .onAppear {
            // Ripristina l'autenticazione all'avvio
            Task {
                await emailService.restoreAuthentication()
            }
        }
    }
    
    // MARK: - Modern Email List Content (iOS 26)
    
    private var modernEmailListContent: some View {
        List {
            // Filtri AI per categoria
            Section {
                // Spazio vuoto per i filtri
            } header: {
                aiCategoryFiltersView
            }
            
            if emailService.isThreadingEnabled {
                // NUOVO: Vista conversazioni
                ForEach(filteredConversations) { conversation in
                    NavigationLink(destination: destinationViewForConversation(conversation)) {
                        ConversationRowView(conversation: conversation)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    // Swipe actions per conversazioni
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task {
                                await emailService.markConversationAsRead(conversation)
                                hapticFeedback.impactOccurred()
                            }
                        } label: {
                            Label(
                                conversation.hasUnread ? "Segna come letta" : "Segna come non letta",
                                systemImage: conversation.hasUnread ? "envelope.open" : "envelope.badge"
                            )
                        }
                        .tint(.blue)
                    }
                }
            } else {
                // Vista email singole (esistente)
                ForEach(filteredEmails) { email in
                    NavigationLink(destination: destinationView(for: email)) {
                        ModernEmailRowView(email: email)
                    }
                    .standardAccessibility(
                        label: "Email da \(senderDisplayName(email.from)). Oggetto: \(email.subject). \(email.isRead ? "Letta" : "Non letta"). Data: \(formatRelativeDate(email.date))",
                        hint: "Tocca per aprire l'email. Scorri per altre azioni"
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                // iOS 26 SwipeActions
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    // Mark as Read/Unread
                    Button {
                        Task {
                            await toggleReadStatus(for: email)
                            let status = email.isRead ? "non letta" : "letta"
                            accessibilityManager.announce("Email marcata come \(status)")
                        }
                    } label: {
                        Label(
                            email.isRead ? "Non letta" : "Letta", 
                            systemImage: email.isRead ? "envelope.badge" : "envelope.open"
                        )
                    }
                    .tint(.blue)
                    .buttonAccessibility(
                        label: email.isRead ? "Segna come non letta" : "Segna come letta",
                        hint: "Cambia lo stato di lettura dell'email"
                    )
                    
                    // Pin Email
                    Button {
                        pinEmail(email)
                        accessibilityManager.announce("Email aggiunta ai preferiti")
                    } label: {
                        Label("Pin", systemImage: "pin.fill")
                    }
                    .tint(.orange)
                    .buttonAccessibility(
                        label: "Aggiungi ai preferiti",
                        hint: "Contrassegna l'email come importante"
                    )
                    
                    // Archive
                    Button {
                        Task {
                            await archiveEmail(email)
                            accessibilityManager.announce("Email archiviata")
                        }
                    } label: {
                        Label("Archivia", systemImage: "archivebox.fill")
                    }
                    .tint(.green)
                    .buttonAccessibility(
                        label: "Archivia email",
                        hint: "Sposta l'email nell'archivio"
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Delete
                    Button(role: .destructive) {
                        Task {
                            await deleteEmail(email)
                            accessibilityManager.announce("Email eliminata")
                        }
                    } label: {
                        Label("Elimina", systemImage: "trash.fill")
                    }
                    .buttonAccessibility(
                        label: "Elimina email",
                        hint: "Cancella definitivamente l'email"
                    )
                    
                    // Forward
                    Button {
                        forwardEmail(email)
                        accessibilityManager.announce("Apertura inoltro email")
                    } label: {
                        Label("Inoltra", systemImage: "arrowshape.turn.up.right.fill")
                    }
                    .tint(.indigo)
                    .buttonAccessibility(
                        label: "Inoltra email",
                        hint: "Invia questa email a qualcun altro"
                    )
                    
                    // Reply
                    Button {
                        replyToEmail(email)
                        accessibilityManager.announce("Apertura risposta email")
                    } label: {
                        Label("Rispondi", systemImage: "arrowshape.turn.up.left.fill")
                    }
                    .tint(.blue)
                    .buttonAccessibility(
                        label: "Rispondi",
                        hint: "Rispondi al mittente dell'email"
                    )
                }
            }
            } // Fine else (email singole)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 60)
        .refreshable {
            // MIGLIORATO: Usa refresh forzato per pull-to-refresh
            await emailService.forceRefresh()
        }
        .overlay {
            if emailService.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .foregroundStyle(.blue)
                    Text("Caricamento email...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
            
            if filteredEmails.isEmpty && !emailService.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Nessuna email trovata")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("Le tue email appariranno qui")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .searchable(text: $searchText, prompt: "Cerca email...")
    }
    
    // MARK: - AI Category Filters View
    
    private var aiCategoryFiltersView: some View {
        VStack(spacing: 8) {
            // Filtri per categoria AI
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Filtro "Tutte"
                    AICategoryFilterChip(
                        category: nil,
                        isSelected: selectedCategory == nil,
                        count: getAllEmailsCount()
                    ) {
                        selectedCategory = nil
                    }
                    
                    // Filtri per ogni categoria AI
                    ForEach([EmailCategory.work, EmailCategory.personal, EmailCategory.notifications, EmailCategory.promotional], id: \.self) { category in
                        AICategoryFilterChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            count: getCategoryCount(category)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Conta email per categoria AI
    private func getCategoryCount(_ category: EmailCategory) -> Int {
        if emailService.isThreadingEnabled {
            return emailService.emailConversations.filter { conversation in
                conversation.messages.contains { message in
                    message.category == category
                }
            }.count
        } else {
            return emailService.emails.filter { $0.category == category }.count
        }
    }
    
    // Conta tutte le email/conversazioni
    private func getAllEmailsCount() -> Int {
        if emailService.isThreadingEnabled {
            return emailService.emailConversations.count
        } else {
            return emailService.emails.count
        }
    }
    
    // MARK: - Helper Functions for Accessibility
    
    /// Formattazione data relativa (stile Apple Mail)
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Ieri"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "E" // Giorno della settimana abbreviato
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    /// Nome del mittente formattato
    private func senderDisplayName(_ from: String) -> String {
        // Estrae il nome se è nel formato "Nome <email@domain.com>"
        if let nameRange = from.range(of: " <") {
            return String(from[..<nameRange.lowerBound])
        }
        return from
    }
    
    // MARK: - SwipeAction Functions
    
    private func toggleReadStatus(for email: EmailMessage) async {
        hapticFeedback.impactOccurred()
        await emailService.markEmailAsRead(email.id)
    }
    
    private func pinEmail(_ email: EmailMessage) {
        hapticFeedback.impactOccurred()
        // TODO: Implementare pin functionality
        print("📌 Pin email: \(email.subject)")
    }
    
    private func archiveEmail(_ email: EmailMessage) async {
        hapticFeedback.impactOccurred()
        // TODO: Implementare archive functionality
        print("📦 Archive email: \(email.subject)")
        await emailService.archiveEmail(email.id)
    }
    
    private func deleteEmail(_ email: EmailMessage) async {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        do {
            try await emailService.deleteEmail(email.id)
        } catch {
            print("❌ Error deleting email: \(error)")
        }
    }
    
    private func forwardEmail(_ email: EmailMessage) {
        hapticFeedback.impactOccurred()
        // TODO: Show compose sheet with forward data
        print("↪️ Forward email: \(email.subject)")
    }
    
    private func replyToEmail(_ email: EmailMessage) {
        hapticFeedback.impactOccurred()
        // TODO: Show compose sheet with reply data
        print("↩️ Reply to email: \(email.subject)")
    }
    
    // MARK: - Login Content
    
    private var loginContent: some View {
        VStack(spacing: 30) {
            // Icon iOS 26 style
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.multicolor)
            
            VStack(spacing: 12) {
                Text("Accedi alla tua Email")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Connetti il tuo account email per iniziare")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                // Google Login - iOS 26 style
                Button {
                    Task {
                        await emailService.authenticateWithGoogle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.circle")
                            .font(.title2)
                        Text("Accedi con Google")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                }
                
                // Microsoft Login - iOS 26 style
                Button {
                    Task {
                        await emailService.authenticateWithMicrosoft()
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.circle")
                            .font(.title2)
                        Text("Accedi con Microsoft")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

// MARK: - Apple Mail Standard Email Row
private struct ModernEmailRowView: View {
    let email: EmailMessage
    
    var body: some View {
        HStack(spacing: 12) {
            // NUOVO: Avatar del mittente (stile Apple Mail)
            AvatarView(email: email)
            
            VStack(alignment: .leading, spacing: 2) {
                // NUOVO: Prima riga - Mittente + Data + Indicatore non letto
                HStack {
                    Text(senderDisplayName(email.from))
                        .font(.subheadline)
                        .fontWeight(email.isRead ? .regular : .semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text(formatRelativeDate(email.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // NUOVO: Indicatore non letto più grande (stile Apple Mail)
                        if !email.isRead {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                // NUOVO: Seconda riga - Oggetto
                Text(email.subject)
                    .font(.subheadline)
                    .foregroundStyle(email.isRead ? .secondary : .primary)
                    .fontWeight(email.isRead ? .regular : .medium)
                    .lineLimit(1)
                
                // NUOVO: Terza riga - Preview body
                Text(email.body.stripHTML())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // NUOVO: Indicatori aggiuntivi (allegati, etc.)
                HStack(spacing: 8) {
                    if email.hasAttachments {
                        Label("", systemImage: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .labelStyle(.iconOnly)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.clear)
        .contentShape(Rectangle())
    }
    
    // NUOVO: Formattazione data relativa (stile Apple Mail)
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Ieri"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "E" // Giorno della settimana abbreviato
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    // NUOVO: Nome del mittente formattato  
    private func senderDisplayName(_ from: String) -> String {
        // Estrae il nome se è nel formato "Nome <email@domain.com>"
        if let nameRange = from.range(of: " <") {
            return String(from[..<nameRange.lowerBound])
        }
        return from
    }
}

// MARK: - Avatar View (Apple Mail Style)
private struct AvatarView: View {
    let email: EmailMessage
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.blue.gradient)
                .frame(width: 40, height: 40)
            
            // Initials
            Text(avatarInitials(from: email.from))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
    }
    
    private func avatarInitials(from: String) -> String {
        let name = senderDisplayName(from)
        let components = name.components(separatedBy: " ")
        
        if components.count >= 2 {
            // Nome e cognome
            let firstInitial = String(components[0].prefix(1)).uppercased()
            let lastInitial = String(components[1].prefix(1)).uppercased()
            return firstInitial + lastInitial
        } else if !name.isEmpty {
            // Solo nome o email
            return String(name.prefix(2)).uppercased()
        } else {
            return "?"
        }
    }
    
    private func senderDisplayName(_ from: String) -> String {
        // Estrae il nome se è nel formato "Nome <email@domain.com>"
        if let nameRange = from.range(of: " <") {
            return String(from[..<nameRange.lowerBound])
        }
        return from
    }

}

// MARK: - Conversation Row View

private struct ConversationRowView: View {
    let conversation: EmailConversation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar del partecipante principale
            Circle()
                .fill(.blue.gradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(conversation.participants.first?.prefix(1).uppercased() ?? "?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.subject)
                        .font(.subheadline)
                        .fontWeight(conversation.hasUnread ? .semibold : .medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Numero messaggi
                    if conversation.messageCount > 1 {
                        Text("\(conversation.messageCount)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                    
                    Text(formatRelativeDate(conversation.lastActivity))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(conversation.participantsDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if let latestMessage = conversation.latestMessage {
                    Text(latestMessage.body.stripHTML())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Indicatore non letto
            if conversation.hasUnread {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Ieri"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Conversation Detail View

private struct ConversationDetailView: View {
    let conversation: EmailConversation
    let emailService: EmailService
    
    var body: some View {
        List {
            ForEach(conversation.messages.sorted { $0.date < $1.date }) { message in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(message.from)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(message.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(message.body.stripHTML())
                        .font(.body)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle(conversation.subject)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - AI Category Filter Chip
struct AICategoryFilterChip: View {
    let category: EmailCategory?
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    private var title: String {
        if let category = category {
            return category.displayName
        } else {
            return "Tutte"
        }
    }
    
    private var icon: String {
        if let category = category {
            return category.icon
        } else {
            return "envelope"
        }
    }
    
    private var color: Color {
        if let category = category {
            return category.color
        } else {
            return .blue
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.secondary.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - String Extension for HTML Stripping
extension String {
    func stripHTML() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
} 