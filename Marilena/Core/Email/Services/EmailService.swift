import Foundation
import Combine
import SwiftUI

/// EmailService refactored - Orchestra i servizi specializzati
/// Responsabilità: coordinamento e gestione dello stato dell'app
@MainActor
public final class EmailService: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var emailsByAccount: [String: [EmailMessage]] = [:]
    @Published public private(set) var emailConversations: [EmailConversation] = []
    @Published public var isThreadingEnabled = true
    @Published public private(set) var isLoading = false
    @Published public var error: String?

    // Unified emails from all accounts (sorted by date) - Published for UI binding
    @Published public private(set) var emails: [EmailMessage] = []

    private func updateUnifiedEmails() {
        emails = emailsByAccount.values.flatMap { $0 }.sorted { $0.date > $1.date }
    }

    // Offline support
    @Published public private(set) var isOnline = true
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var pendingOperationsCount = 0

    // Multi-account support
    public var accounts: [EmailAccount] { EmailAccountManager.shared.accounts }
    public var currentAccount: EmailAccount? { EmailAccountManager.shared.currentAccount }
    public var isAuthenticated: Bool { !accounts.isEmpty }

    // MARK: - Services
    private let authService: EmailAuthService
    private let networkService: EmailNetworkService
    private let cacheManager: EmailCacheManager
    private let categorizationService: EmailCategorizationService
    private let threadingManager: EmailThreadingManager
    private let offlineSyncService: OfflineSyncService

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadTime: Date?
    private let minimumLoadInterval: TimeInterval = 30.0
    private var isCurrentlyLoading = false

    // MARK: - Initialization

    public init(
        authService: EmailAuthService? = nil,
        networkService: EmailNetworkService? = nil,
        cacheManager: EmailCacheManager? = nil,
        categorizationService: EmailCategorizationService? = nil,
        threadingManager: EmailThreadingManager? = nil,
        offlineSyncService: OfflineSyncService? = nil
    ) {
        self.authService = authService ?? EmailAuthService()
        self.networkService = networkService ?? EmailNetworkService()
        self.cacheManager = cacheManager ?? .shared
        self.categorizationService = categorizationService ?? EmailCategorizationService()
        self.threadingManager = threadingManager ?? EmailThreadingManager()
        self.offlineSyncService = offlineSyncService ?? .shared

        setupBindings()
        loadCachedEmails()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind offline status
        offlineSyncService.$isOnline
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOnline)

        offlineSyncService.$syncStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncStatus)

        offlineSyncService.$pendingOperationsCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingOperationsCount)

        // Bind auth changes
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                if isAuth {
                    Task { @MainActor in
                        await self?.loadEmails()
                    }
                } else {
                    self?.clearEmails()
                }
            }
            .store(in: &cancellables)

        // Watch for threading toggle
        $isThreadingEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.organizeEmailsIntoConversations()
                }
            }
            .store(in: &cancellables)

        // Link service to offline sync
        // Note: OfflineSyncService expects EmailService, but we're using EmailService
        // For now, skip this until OfflineSyncService is refactored to use protocol
        // offlineSyncService.setEmailService(self)
    }

    private func loadCachedEmails() {
        let cached = cacheManager.getAllEmails()
        if !cached.isEmpty {
            // Organizza per account
            emailsByAccount = Dictionary(grouping: cached, by: { $0.accountId })
            updateUnifiedEmails()
            Task {
                await organizeEmailsIntoConversations()
            }
        }
    }

    // MARK: - Authentication (Delegated)

    public func restoreAuthentication() async {
        await authService.restoreGoogleSignIn()
    }

    public func authenticateWithGoogle() async {
        do {
            _ = try await authService.authenticateWithGoogle()
        } catch {
            self.error = "Errore autenticazione Google: \(error.localizedDescription)"
        }
    }

    public func authenticateWithMicrosoft() async {
        do {
            _ = try await authService.authenticateWithMicrosoft()
        } catch {
            self.error = "Errore autenticazione Microsoft: \(error.localizedDescription)"
        }
    }

    public func disconnect() {
        authService.disconnect()
        cacheManager.invalidateCache(for: currentAccount?.email ?? "")
        clearEmails()
    }

    // MARK: - Email Loading

    /// Carica email da tutti gli account con parallelizzazione
    public func loadEmails(forceRefresh: Bool = false) async {
        // Prevent concurrent loads
        guard !isCurrentlyLoading else {
            print("⚠️ EmailService: Load already in progress")
            return
        }

        // Check debouncing
        if !forceRefresh, let lastLoad = lastLoadTime {
            let elapsed = Date().timeIntervalSince(lastLoad)
            if elapsed < minimumLoadInterval {
                print("⏱️ EmailService: Debouncing - wait \(minimumLoadInterval - elapsed)s")
                return
            }
        }

        guard !accounts.isEmpty else {
            print("⚠️ EmailService: No accounts")
            return
        }

        isCurrentlyLoading = true
        isLoading = true
        defer {
            isCurrentlyLoading = false
            isLoading = false
        }

        // Load from all accounts in parallel using TaskGroup
        await withTaskGroup(of: (String, [EmailMessage]).self) { group in
            for account in accounts {
                group.addTask {
                    do {
                        // Refresh token if needed
                        let validAccount = try await self.authService.refreshTokenIfNeeded(for: account)

                        // Fetch from network
                        let newEmails: [EmailMessage]
                        switch validAccount.provider {
                        case .google:
                            newEmails = try await self.networkService.fetchEmailsFromGmail(
                                accessToken: validAccount.accessToken,
                                accountId: account.id,
                                maxResults: 100
                            )
                        case .microsoft:
                            newEmails = try await self.networkService.fetchEmailsFromMicrosoft(
                                accessToken: validAccount.accessToken,
                                accountId: account.id,
                                maxResults: 100
                            )
                        }

                        // Categorize emails
                        let categorizedEmails = await self.categorizationService.categorizeEmails(newEmails)

                        print("✅ Loaded \(categorizedEmails.count) emails for account: \(account.email)")
                        return (account.id, categorizedEmails)

                    } catch {
                        print("❌ Error loading emails for \(account.email): \(error)")
                        return (account.id, [])
                    }
                }
            }

            // Collect results from all accounts
            for await (accountId, emails) in group {
                // Merge with cache (evita duplicati)
                let merged = self.cacheManager.mergeEmails(emails)
                self.emailsByAccount[accountId] = merged.filter { $0.accountId == accountId }
            }
        }

        // Update unified view
        updateUnifiedEmails()

        // Organize into conversations if enabled
        if isThreadingEnabled {
            await organizeEmailsIntoConversations()
        }

        lastLoadTime = Date()
        print("✅ EmailService: Loaded \(emails.count) total emails from \(accounts.count) accounts")
    }

    /// Force refresh ignorando debouncing
    public func forceRefresh() async {
        lastLoadTime = nil
        await loadEmails(forceRefresh: true)
    }

    /// Force refresh per un account specifico
    public func forceRefreshEmails(for account: EmailAccount) async {
        lastLoadTime = nil
        await loadEmails(forceRefresh: true)
    }

    // MARK: - Email Operations

    /// Marca email come letta
    public func markEmailAsRead(_ emailId: String) async {
        // Find email in all accounts
        guard let email = emails.first(where: { $0.id == emailId }) else { return }
        guard let account = accounts.first(where: { $0.id == email.accountId }) else { return }

        // Update locale immediato (EmailMessage è immutable, creiamo una nuova istanza)
        let updatedEmail = EmailMessage(
            id: email.id,
            accountId: email.accountId,
            from: email.from,
            to: email.to,
            subject: email.subject,
            body: email.body,
            date: email.date,
            isRead: true,
            hasAttachments: email.hasAttachments,
            emailType: email.emailType,
            category: email.category
        )

        // Update in emailsByAccount
        if var accountEmails = emailsByAccount[email.accountId],
           let index = accountEmails.firstIndex(where: { $0.id == emailId }) {
            accountEmails[index] = updatedEmail
            emailsByAccount[email.accountId] = accountEmails
            updateUnifiedEmails()
        }

        cacheManager.saveEmail(updatedEmail)

        // Sincronizza con server (offline-safe)
        if isOnline {
            do {
                switch account.provider {
                case .google:
                    try await networkService.markAsReadGmail(emailId: emailId, account: account)
                case .microsoft:
                    try await networkService.markAsReadMicrosoft(emailId: emailId, account: account)
                }
            } catch {
                print("❌ EmailService: Error marking as read: \(error)")
                // TODO: Queue per offline sync (requires OfflineOperation refactoring)
                // await offlineSyncService.queueOperation(.markAsRead(emailId: emailId))
            }
        } else {
            // TODO: Queue per offline sync (requires OfflineOperation refactoring)
            // await offlineSyncService.queueOperation(.markAsRead(emailId: emailId))
        }
    }

    /// Elimina email
    public func deleteEmail(_ emailId: String) async throws {
        // Find email to get account
        guard let email = emails.first(where: { $0.id == emailId }) else {
            throw EmailError.emailNotFound
        }
        guard let account = accounts.first(where: { $0.id == email.accountId }) else {
            throw EmailError.notAuthenticated
        }

        // Remove from emailsByAccount
        if var accountEmails = emailsByAccount[email.accountId] {
            accountEmails.removeAll { $0.id == emailId }
            emailsByAccount[email.accountId] = accountEmails
            updateUnifiedEmails()
        }

        cacheManager.deleteEmail(id: emailId)

        // Sincronizza con server
        if isOnline {
            do {
                switch account.provider {
                case .google:
                    try await networkService.deleteFromGmail(emailId: emailId, account: account)
                case .microsoft:
                    try await networkService.deleteFromMicrosoft(emailId: emailId, account: account)
                }
            } catch {
                print("❌ EmailService: Error deleting: \(error)")
                // TODO: Queue per offline sync
                // await offlineSyncService.queueOperation(.delete(emailId: emailId))
            }
        } else {
            // TODO: Queue per offline sync
            // await offlineSyncService.queueOperation(.delete(emailId: emailId))
        }
    }

    /// Archivia email
    public func archiveEmail(_ emailId: String) async {
        // Find email to get account
        guard let email = emails.first(where: { $0.id == emailId }) else { return }

        // Remove from emailsByAccount
        if var accountEmails = emailsByAccount[email.accountId] {
            accountEmails.removeAll { $0.id == emailId }
            emailsByAccount[email.accountId] = accountEmails
            updateUnifiedEmails()
        }

        cacheManager.archiveEmail(id: emailId)

        if isOnline {
            // TODO: Implement archive API call
            print("📦 EmailService: Archive \(emailId)")
        } else {
            // TODO: Queue per offline sync
            // await offlineSyncService.queueOperation(.archive(emailId: emailId))
        }
    }

    /// Invia email
    public func sendEmail(to: String, subject: String, body: String) async throws {
        guard let account = currentAccount else {
            throw EmailError.notAuthenticated
        }

        if isOnline {
            let validAccount = try await authService.refreshTokenIfNeeded(for: account)

            switch validAccount.provider {
            case .google:
                try await networkService.sendEmailViaGmail(
                    to: to,
                    subject: subject,
                    body: body,
                    account: validAccount
                )
            case .microsoft:
                try await networkService.sendEmailViaMicrosoft(
                    to: to,
                    subject: subject,
                    body: body,
                    account: validAccount
                )
            }
        } else {
            // TODO: Queue per offline sync
            // await offlineSyncService.queueOperation(.send(to: to, subject: subject, body: body))
            throw EmailError.networkError("Offline sending not implemented yet")
        }
    }

    // MARK: - Threading

    /// Organizza email in conversazioni
    public func organizeEmailsIntoConversations() async {
        guard isThreadingEnabled else {
            emailConversations = []
            return
        }

        emailConversations = threadingManager.organizeIntoConversations(emails)
        print("🧵 EmailService: Organized \(emailConversations.count) conversations")
    }

    /// Marca conversazione come letta
    public func markConversationAsRead(_ conversation: EmailConversation) async {
        for message in conversation.messages where !message.isRead {
            await markEmailAsRead(message.id)
        }
    }

    // MARK: - Testing

    /// Simula nuova email per testing
    public func simulateNewEmail() async {
        guard let account = currentAccount else { return }

        let testEmail = EmailMessage(
            id: UUID().uuidString,
            accountId: account.id,
            from: "test@example.com",
            to: [account.email],
            subject: "Test Email \(Date())",
            body: "This is a test email created at \(Date())",
            date: Date(),
            isRead: false,
            hasAttachments: false,
            emailType: .received,
            category: .personal
        )

        // Insert into emailsByAccount
        if var accountEmails = emailsByAccount[account.id] {
            accountEmails.insert(testEmail, at: 0)
            emailsByAccount[account.id] = accountEmails
        } else {
            emailsByAccount[account.id] = [testEmail]
        }
        updateUnifiedEmails()

        cacheManager.saveEmail(testEmail)

        if isThreadingEnabled {
            await organizeEmailsIntoConversations()
        }
    }

    // MARK: - Helpers

    private func clearEmails() {
        emailsByAccount = [:]
        emails = []
        emailConversations = []
    }

    /// Accesso pubblico per OfflineSyncService
    internal func getNetworkService() -> EmailNetworkService {
        return networkService
    }

    // MARK: - Forward Email

    /// Prepara subject e body per un forward
    public func prepareForwardEmail(_ email: EmailMessage) -> (subject: String, body: String) {
        let forwardSubject = "Fwd: \(email.subject)"

        let forwardBody = """
        <br><br>
        ---------- Messaggio inoltrato ----------<br>
        Da: \(email.from)<br>
        Data: \(formatDate(email.date))<br>
        Oggetto: \(email.subject)<br>
        A: \(email.to.joined(separator: ", "))<br>
        <br>
        \(email.body)
        """

        return (subject: forwardSubject, body: forwardBody)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Categorization

    /// Ricategorizza tutte le email
    public func forceCategorizeAllEmails() async {
        guard !emails.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let categorizedEmails = await categorizationService.categorizeEmails(emails)

        // Merge results back
        var updated = emails
        for categorized in categorizedEmails {
            if let index = updated.firstIndex(where: { $0.id == categorized.id }) {
                updated[index] = categorized
            }
        }

        // Update per-account and unified
        emailsByAccount = Dictionary(grouping: updated, by: { $0.accountId })
        updateUnifiedEmails()

        await organizeEmailsIntoConversations()
    }

    /// Filtra email per categoria
    public func emailsForCategory(_ category: EmailCategory) -> [EmailMessage] {
        return emails.filter { $0.category == category }
    }

    /// Conteggio email per categoria
    public func getCategoryCounts() -> [EmailCategory: Int] {
        var counts: [EmailCategory: Int] = [:]
        for category in EmailCategory.allCases {
            counts[category] = emails.filter { $0.category == category }.count
        }
        return counts
    }

    // MARK: - Compatibility

    /// Carica email per un account specifico (compatibilità con OfflineSyncService)
    public func loadEmails(for account: EmailAccount) async {
        await loadEmails(forceRefresh: false)
    }
}

// Note: SyncStatus is defined in OfflineSyncService.swift
