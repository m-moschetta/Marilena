import SwiftUI
import Combine
import CoreData

// MARK: - iOS 26 Enhanced Email List View
/// Vista principale email consolidata con Design System unificato
/// - Componenti condivisi da EmailComponents.swift
/// - UnifiedEmailViewer come unico viewer
/// - Navigazione nativa iOS perfetta

public struct EmailListView: View {
    @StateObject private var emailService = EmailService()
    @StateObject private var aiService = EmailAIService()
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    @State private var searchText = ""
    @State private var selectedCategory: EmailCategory? = nil
    @State private var showUncategorized: Bool = false
    @State private var showingComposeSheet = false
    @State private var showingEmailSettings = false
    
    // Cache per stati email (archiviato/eliminato) per evitare query in loop
    @State private var archivedEmailIds: Set<String> = []
    @State private var deletedEmailIds: Set<String> = []
    
    // Haptic
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Computed Properties
    
    private var filteredConversations: [EmailConversation] {
        var conversations = emailService.emailConversations
        
        // Filtra per categoria
        if let selectedCategory = selectedCategory {
            conversations = conversations.filter { conversation in
                conversation.messages.contains { $0.category == selectedCategory }
            }
        } else if showUncategorized {
            conversations = conversations.filter { conversation in
                conversation.messages.contains { $0.category == nil }
            }
        }
        
        // Filtra per ricerca
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            conversations = conversations.filter { conversation in
                conversation.subject.lowercased().contains(searchLower) ||
                conversation.participantsDisplay.lowercased().contains(searchLower) ||
                conversation.messages.contains { $0.body.lowercased().contains(searchLower) }
            }
        }
        
        return conversations.sorted { $0.lastActivity > $1.lastActivity }
    }
    
    private var filteredEmails: [EmailMessage] {
        var emails = emailService.emails
        
        // Escludi archiviate ed eliminate usando la cache (O(1) lookup)
        emails = emails.filter { email in
            !archivedEmailIds.contains(email.id) && !deletedEmailIds.contains(email.id)
        }
        
        // Filtra per categoria
        if let selectedCategory = selectedCategory {
            emails = emails.filter { $0.category == selectedCategory }
        } else if showUncategorized {
            emails = emails.filter { $0.category == nil }
        }
        
        // Filtra per ricerca
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            emails = emails.filter { email in
                email.subject.lowercased().contains(searchLower) ||
                email.from.lowercased().contains(searchLower) ||
                email.body.lowercased().contains(searchLower)
            }
        }
        
        return emails.sorted { $0.date > $1.date }
    }
    
    // MARK: - Cache Management
    
    private func refreshEmailStatusCache() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isArchived == YES OR isMarkedAsDeleted == YES")
        
        do {
            let cachedEmails = try context.fetch(fetchRequest)
            archivedEmailIds = Set(cachedEmails.filter { $0.isArchived }.compactMap { $0.id })
            deletedEmailIds = Set(cachedEmails.filter { $0.isMarkedAsDeleted }.compactMap { $0.id })
        } catch {
            print("❌ Errore caricamento cache stati email: \(error)")
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if emailService.isAuthenticated {
                    emailListContent
                } else {
                    loginContent
                }
            }
            .navigationTitle(emailService.currentAccount?.email ?? "Email")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Cerca email...")
            .toolbar {
                leadingToolbarItems
                trailingToolbarItems
            }
            .withEmailNavigation(emailService: emailService, aiService: aiService)
        }
        .refreshable {
            await refreshEmails()
        }
        .sheet(isPresented: $showingComposeSheet) {
            ModernComposeView()
        }
        .sheet(isPresented: $showingEmailSettings) {
            EmailSettingsView()
                .environmentObject(emailService)
        }
        .alert("Errore", isPresented: .constant(emailService.error != nil)) {
            Button("OK") { emailService.error = nil }
        } message: {
            Text(emailService.error ?? "")
        }
        .onAppear {
            refreshEmailStatusCache()
            Task {
                await emailService.restoreAuthentication()
            }
        }
        .onChange(of: emailService.emails) { _, _ in
            refreshEmailStatusCache()
        }
    }
    
    // MARK: - Toolbar Items
    
    @ToolbarContentBuilder
    private var leadingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                // Account Info
                Button("Account: \(emailService.currentAccount?.email ?? "Non connesso")") { }
                    .disabled(true)
                
                Divider()
                
                // Toggle Threading
                Button {
                    Task {
                        emailService.isThreadingEnabled.toggle()
                        await emailService.organizeEmailsIntoConversations()
                        hapticFeedback.impactOccurred()
                        accessibilityManager.announce(emailService.isThreadingEnabled ? "Conversazioni abilitate" : "Conversazioni disabilitate")
                    }
                } label: {
                    HStack {
                        Image(systemName: emailService.isThreadingEnabled ? "checkmark.square" : "square")
                        Text("🧵 Raggruppa conversazioni")
                    }
                }
                
                Divider()
                
                // Settings
                Button {
                    showingEmailSettings = true
                } label: {
                    Label("Impostazioni", systemImage: "gear")
                }
                
                // Disconnect
                Button(role: .destructive) {
                    emailService.disconnect()
                    accessibilityManager.announce("Account disconnesso")
                } label: {
                    Label("Disconnetti", systemImage: "rectangle.portrait.and.arrow.right")
                }
                
                #if DEBUG
                Divider()
                
                Button("🧪 Simula Nuova Email") {
                    Task {
                        await emailService.simulateNewEmail()
                        accessibilityManager.announce("Nuova email simulata")
                    }
                }
                .foregroundColor(.orange)
                #endif
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // Sync Status Indicators
                HStack(spacing: 6) {
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
                    }
                    
                    Circle()
                        .fill(emailService.isOnline ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    if case .syncing = emailService.syncStatus {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Compose Button
                Button {
                    showingComposeSheet = true
                    hapticFeedback.impactOccurred()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    // MARK: - Email List Content
    
    private var emailListContent: some View {
        List {
            // Category Filters
            Section {
                EmptyView()
            } header: {
                categoryFiltersView
            }
            
            // Email List
            if emailService.isThreadingEnabled {
                conversationRows
            } else {
                emailRows
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 60)
        .overlay {
            if emailService.isLoading {
                EmailLoadingView()
            }
            
            if filteredEmails.isEmpty && !emailService.isLoading {
                EmailEmptyStateView()
            }
        }
    }
    
    // MARK: - Conversation Rows
    
    private var conversationRows: some View {
        ForEach(filteredConversations) { conversation in
            NavigationLink(value: conversation) {
                ConversationRowView(conversation: conversation)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    Task {
                        await emailService.markConversationAsRead(conversation)
                        hapticFeedback.impactOccurred()
                    }
                } label: {
                    Label(
                        conversation.hasUnread ? "Letta" : "Non letta",
                        systemImage: conversation.hasUnread ? "envelope.open" : "envelope.badge"
                    )
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    // Delete conversation
                } label: {
                    Label("Elimina", systemImage: "trash.fill")
                }
            }
        }
    }
    
    // MARK: - Email Rows
    
    private var emailRows: some View {
        ForEach(filteredEmails) { email in
            NavigationLink(value: email) {
                EmailRowView(email: email)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                // Mark Read/Unread
                Button {
                    Task {
                        await emailService.markEmailAsRead(email.id)
                        hapticFeedback.impactOccurred()
                    }
                } label: {
                    Label(
                        email.isRead ? "Non letta" : "Letta",
                        systemImage: email.isRead ? "envelope.badge" : "envelope.open"
                    )
                }
                .tint(.blue)
                
                // Archive
                Button {
                    Task {
                        await emailService.archiveEmail(email.id)
                        hapticFeedback.impactOccurred()
                    }
                } label: {
                    Label("Archivia", systemImage: "archivebox.fill")
                }
                .tint(.green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                // Delete
                Button(role: .destructive) {
                    Task {
                        try? await emailService.deleteEmail(email.id)
                    }
                } label: {
                    Label("Elimina", systemImage: "trash.fill")
                }
            }
        }
    }
    
    // MARK: - Category Filters
    
    private var categoryFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Tutte
                EmailFilterChip(
                    title: "Tutte",
                    count: getAllEmailsCount(),
                    isSelected: selectedCategory == nil && !showUncategorized,
                    action: {
                        selectedCategory = nil
                        showUncategorized = false
                    }
                )
                
                // Uncategorized
                EmailFilterChip(
                    title: "Da categorizzare",
                    icon: "tray",
                    count: getUncategorizedCount(),
                    isSelected: showUncategorized,
                    action: {
                        selectedCategory = nil
                        showUncategorized = true
                    }
                )
                
                // Categories
                ForEach([EmailCategory.work, EmailCategory.personal, EmailCategory.notifications, EmailCategory.promotional], id: \.self) { category in
                    EmailFilterChip(
                        title: category.displayName,
                        icon: category.icon,
                        count: getCategoryCount(category),
                        isSelected: selectedCategory == category,
                        action: {
                            selectedCategory = category
                            showUncategorized = false
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Login Content
    
    private var loginContent: some View {
        VStack(spacing: 30) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.multicolor)
            
            VStack(spacing: 12) {
                Text("Accedi alla tua Email")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Connetti il tuo account email per iniziare")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                // Google
                Button {
                    Task { await emailService.authenticateWithGoogle() }
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
                
                // Microsoft
                Button {
                    Task { await emailService.authenticateWithMicrosoft() }
                } label: {
                    HStack {
                        Image(systemName: "envelope.badge")
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
    
    // MARK: - Helper Methods
    
    private func refreshEmails() async {
        if let account = emailService.currentAccount {
            await emailService.forceRefreshEmails(for: account)
            hapticFeedback.impactOccurred()
        }
    }
    
    private func getCategoryCount(_ category: EmailCategory) -> Int {
        if emailService.isThreadingEnabled {
            return emailService.emailConversations.filter { conversation in
                conversation.messages.contains { $0.category == category }
            }.count
        } else {
            return emailService.emails.filter { $0.category == category }.count
        }
    }
    
    private func getAllEmailsCount() -> Int {
        if emailService.isThreadingEnabled {
            return emailService.emailConversations.count
        } else {
            return emailService.emails.count
        }
    }
    
    private func getUncategorizedCount() -> Int {
        if emailService.isThreadingEnabled {
            return emailService.emailConversations.filter { conversation in
                conversation.messages.contains { $0.category == nil }
            }.count
        } else {
            return emailService.emails.filter { $0.category == nil }.count
        }
    }
}

// MARK: - Conversation Row View

private struct ConversationRowView: View {
    let conversation: EmailConversation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            EmailAvatarView(
                email: conversation.participants.first ?? "?",
                size: 40
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.subject)
                        .font(.subheadline)
                        .fontWeight(conversation.hasUnread ? .semibold : .medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
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
                        .lineLimit(1)
                }
            }
            
            if conversation.hasUnread {
                UnreadIndicator()
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

// MARK: - Navigation Extensions

extension EmailMessage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: EmailMessage, rhs: EmailMessage) -> Bool {
        lhs.id == rhs.id
    }
}

extension EmailConversation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: EmailConversation, rhs: EmailConversation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        EmailListView()
    }
}
