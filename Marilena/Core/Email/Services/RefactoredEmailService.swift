import Foundation
import Combine
import SwiftUI

/// EmailService refactored - Orchestra i servizi specializzati
/// Responsabilità: coordinamento e gestione dello stato dell'app
@MainActor
public final class RefactoredEmailService: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var emails: [EmailMessage] = []
    @Published public private(set) var emailConversations: [EmailConversation] = []
    @Published public var isThreadingEnabled = true
    @Published public private(set) var isLoading = false
    @Published public var error: String?

    // Offline support
    @Published public private(set) var isOnline = true
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var pendingOperationsCount = 0

    // Authentication state (delegated to AuthService)
    public var isAuthenticated: Bool { authService.isAuthenticated }
    public var currentAccount: EmailAccount? { authService.currentAccount }

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
        // Note: OfflineSyncService expects EmailService, but we're using RefactoredEmailService
        // For now, skip this until OfflineSyncService is refactored to use protocol
        // offlineSyncService.setEmailService(self)
    }

    private func loadCachedEmails() {
        let cached = cacheManager.getAllEmails()
        if !cached.isEmpty {
            emails = cached
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

    /// Carica email con debouncing e cache intelligente
    public func loadEmails(forceRefresh: Bool = false) async {
        // Prevent concurrent loads
        guard !isCurrentlyLoading else {
            print("⚠️ RefactoredEmailService: Load already in progress")
            return
        }

        // Check debouncing
        if !forceRefresh, let lastLoad = lastLoadTime {
            let elapsed = Date().timeIntervalSince(lastLoad)
            if elapsed < minimumLoadInterval {
                print("⏱️ RefactoredEmailService: Debouncing - wait \(minimumLoadInterval - elapsed)s")
                return
            }
        }

        guard let account = currentAccount else {
            print("⚠️ RefactoredEmailService: No account")
            return
        }

        isCurrentlyLoading = true
        isLoading = true
        defer {
            isCurrentlyLoading = false
            isLoading = false
        }

        do {
            // Refresh token if needed
            let validAccount = try await authService.refreshTokenIfNeeded(for: account)

            // Fetch from network
            let newEmails: [EmailMessage]
            switch validAccount.provider {
            case .google:
                newEmails = try await networkService.fetchEmailsFromGmail(
                    accessToken: validAccount.accessToken,
                    maxResults: 50
                )
            case .microsoft:
                newEmails = try await networkService.fetchEmailsFromMicrosoft(
                    accessToken: validAccount.accessToken,
                    maxResults: 50
                )
            }

            // Categorize emails
            let categorizedEmails = await categorizationService.categorizeEmails(newEmails)

            // Merge with cache (evita duplicati)
            emails = cacheManager.mergeEmails(categorizedEmails)

            // Organize into conversations if enabled
            if isThreadingEnabled {
                await organizeEmailsIntoConversations()
            }

            lastLoadTime = Date()
            print("✅ RefactoredEmailService: Loaded \(emails.count) emails")

        } catch {
            self.error = "Errore caricamento email: \(error.localizedDescription)"
            print("❌ RefactoredEmailService: \(error)")

            // Fallback to cache on error
            if emails.isEmpty {
                emails = cacheManager.getAllEmails()
            }
        }
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
        guard let account = currentAccount else { return }

        // Update locale immediato (EmailMessage è immutable, creiamo una nuova istanza)
        if let index = emails.firstIndex(where: { $0.id == emailId }) {
            let oldEmail = emails[index]
            let updatedEmail = EmailMessage(
                id: oldEmail.id,
                from: oldEmail.from,
                to: oldEmail.to,
                subject: oldEmail.subject,
                body: oldEmail.body,
                date: oldEmail.date,
                isRead: true,
                hasAttachments: oldEmail.hasAttachments,
                category: oldEmail.category
            )
            emails[index] = updatedEmail
            cacheManager.saveEmail(updatedEmail)
        }

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
                print("❌ RefactoredEmailService: Error marking as read: \(error)")
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
        guard let account = currentAccount else {
            throw EmailError.notAuthenticated
        }

        // Remove locale immediato
        emails.removeAll { $0.id == emailId }
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
                print("❌ RefactoredEmailService: Error deleting: \(error)")
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
        emails.removeAll { $0.id == emailId }
        cacheManager.archiveEmail(id: emailId)

        if isOnline {
            // TODO: Implement archive API call
            print("📦 RefactoredEmailService: Archive \(emailId)")
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
        print("🧵 RefactoredEmailService: Organized \(emailConversations.count) conversations")
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
        let testEmail = EmailMessage(
            id: UUID().uuidString,
            from: "test@example.com",
            to: [currentAccount?.email ?? ""],
            subject: "Test Email \(Date())",
            body: "This is a test email created at \(Date())",
            date: Date(),
            isRead: false,
            hasAttachments: false,
            category: .personal
        )

        emails.insert(testEmail, at: 0)
        cacheManager.saveEmail(testEmail)

        if isThreadingEnabled {
            await organizeEmailsIntoConversations()
        }
    }

    // MARK: - Helpers

    private func clearEmails() {
        emails = []
        emailConversations = []
    }

    /// Accesso pubblico per OfflineSyncService
    internal func getNetworkService() -> EmailNetworkService {
        return networkService
    }
}

// Note: SyncStatus is defined in OfflineSyncService.swift
