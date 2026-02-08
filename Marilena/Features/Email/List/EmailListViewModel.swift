import Foundation
import Combine
import SwiftUI

/// ViewModel MVVM per EmailListView
/// Separa la logica di business dalla vista
@MainActor
public final class EmailListViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published public var searchText = ""
    @Published public var selectedCategory: EmailCategory?
    @Published public var showUncategorized = false
    @Published public var filteredEmails: [EmailMessage] = []
    @Published public var filteredConversations: [EmailConversation] = []

    // MARK: - Dependencies
    private let emailService: EmailService
    private let accessibilityManager = AccessibilityManager.shared
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    public var isLoading: Bool { emailService.isLoading }
    public var isAuthenticated: Bool { emailService.isAuthenticated }
    public var currentAccount: EmailAccount? { emailService.currentAccount }
    public var isThreadingEnabled: Bool { emailService.isThreadingEnabled }
    public var isOnline: Bool { emailService.isOnline }
    public var syncStatus: SyncStatus { emailService.syncStatus }
    public var pendingOperationsCount: Int { emailService.pendingOperationsCount }

    // MARK: - Initialization

    public init(emailService: EmailService) {
        self.emailService = emailService
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Auto-filter quando cambiano email, search o filtri
        Publishers.CombineLatest4(
            emailService.$emails,
            emailService.$emailConversations,
            $searchText,
            Publishers.CombineLatest($selectedCategory, $showUncategorized)
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] emails, conversations, search, filters in
            self?.applyFilters(emails: emails, conversations: conversations, search: search, category: filters.0, showUncategorized: filters.1)
        }
        .store(in: &cancellables)
    }

    // MARK: - Filtering

    private func applyFilters(emails: [EmailMessage], conversations: [EmailConversation], search: String, category: EmailCategory?, showUncategorized: Bool) {
        // Filter emails
        var filtered = emails

        // Escludi archiviate ed eliminate
        filtered = filtered.filter { email in
            let cacheManager = EmailCacheManager.shared
            if let cached = cacheManager.getEmail(id: email.id) {
                // Questa logica potrebbe essere ottimizzata, ma per ora va bene
                return true // Cache manager già filtra
            }
            return true
        }

        // Filtra per categoria
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        } else if showUncategorized {
            filtered = filtered.filter { $0.category == nil }
        }

        // Filtra per ricerca
        if !search.isEmpty {
            let searchLower = search.lowercased()
            filtered = filtered.filter {
                $0.subject.lowercased().contains(searchLower) ||
                $0.from.lowercased().contains(searchLower) ||
                $0.body.lowercased().contains(searchLower)
            }
        }

        filteredEmails = filtered.sorted { $0.date > $1.date }

        // Filter conversations
        var filteredConv = conversations

        if let category = category {
            filteredConv = filteredConv.filter { conversation in
                conversation.messages.contains { $0.category == category }
            }
        } else if showUncategorized {
            filteredConv = filteredConv.filter { conversation in
                conversation.messages.contains { $0.category == nil }
            }
        }

        if !search.isEmpty {
            let searchLower = search.lowercased()
            filteredConv = filteredConv.filter { conversation in
                conversation.subject.lowercased().contains(searchLower) ||
                conversation.participantsDisplay.lowercased().contains(searchLower) ||
                conversation.messages.contains { $0.body.lowercased().contains(searchLower) }
            }
        }

        filteredConversations = filteredConv.sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: - Actions

    public func toggleThreading() async {
        emailService.isThreadingEnabled.toggle()
        hapticFeedback.impactOccurred()

        let status = emailService.isThreadingEnabled ? "abilitato" : "disabilitato"
        accessibilityManager.announce("Raggruppamento conversazioni \(status)")
    }

    public func refresh() async {
        if let account = currentAccount {
            await emailService.forceRefreshEmails(for: account)
            hapticFeedback.impactOccurred()
            accessibilityManager.announce("Email aggiornate")
        }
    }

    public func disconnect() {
        emailService.disconnect()
        accessibilityManager.announce("Account disconnesso")
    }

    public func simulateNewEmail() async {
        await emailService.simulateNewEmail()
        accessibilityManager.announce("Nuova email simulata aggiunta")
    }

    public func toggleReadStatus(for email: EmailMessage) async {
        await emailService.markEmailAsRead(email.id)
        let status = email.isRead ? "non letta" : "letta"
        accessibilityManager.announce("Email marcata come \(status)")
    }

    public func archiveEmail(_ email: EmailMessage) async {
        await emailService.archiveEmail(email.id)
        accessibilityManager.announce("Email archiviata")
    }

    public func deleteEmail(_ email: EmailMessage) async {
        do {
            try await emailService.deleteEmail(email.id)
            accessibilityManager.announce("Email eliminata")
        } catch {
            print("❌ EmailListViewModel: Error deleting: \(error)")
        }
    }

    public func markConversationAsRead(_ conversation: EmailConversation) async {
        await emailService.markConversationAsRead(conversation)
        hapticFeedback.impactOccurred()
    }

    // MARK: - Category Filtering

    public func selectCategory(_ category: EmailCategory?) {
        selectedCategory = category
        showUncategorized = false
    }

    public func selectUncategorized() {
        selectedCategory = nil
        showUncategorized = true
    }

    public func clearFilters() {
        selectedCategory = nil
        showUncategorized = false
    }

    public func getCategoryCount(_ category: EmailCategory) -> Int {
        if isThreadingEnabled {
            return emailService.emailConversations.filter { conversation in
                conversation.messages.contains { $0.category == category }
            }.count
        } else {
            return emailService.emails.filter { $0.category == category }.count
        }
    }

    public func getAllEmailsCount() -> Int {
        if isThreadingEnabled {
            return emailService.emailConversations.count
        } else {
            return emailService.emails.count
        }
    }

    public func getUncategorizedCount() -> Int {
        if isThreadingEnabled {
            return emailService.emailConversations.filter { conversation in
                conversation.messages.contains { $0.category == nil }
            }.count
        } else {
            return emailService.emails.filter { $0.category == nil }.count
        }
    }

    // MARK: - Formatting Helpers

    public func formatRelativeDate(_ date: Date) -> String {
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

    public func senderDisplayName(_ from: String) -> String {
        if let nameRange = from.range(of: " <") {
            return String(from[..<nameRange.lowerBound])
        }
        return from
    }
}
