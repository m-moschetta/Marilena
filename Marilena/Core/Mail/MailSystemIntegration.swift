import Foundation
import SwiftUI
import Combine

/// Punto di ingresso principale per il nuovo sistema email
/// Fornisce un'interfaccia unificata per l'integrazione con l'app esistente
public class MailSystemIntegration {
    public static let shared = MailSystemIntegration()

    // MARK: - Services
    private let mailService = MailService.shared
    private let chatBridgeService = MailChatBridgeService.shared

    // MARK: - Published Properties (for SwiftUI)
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var unreadCount = 0

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupBindings()
    }

    // MARK: - Authentication Integration

    /// Inizializza il sistema email con un account esistente
    public func initializeWithExistingAccount(
        email: String,
        accessToken: String,
        refreshToken: String? = nil,
        provider: String = "gmail"
    ) async throws {
        print("🚀 MailSystemIntegration: Inizializzazione sistema email")

        // Converti il provider stringa in enum
        let providerType = MailProviderType(rawValue: provider) ?? .gmail

        // Crea l'account
        let account = MailAccount(
            email: email,
            provider: providerType,
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientId: "", // Sarà gestito dal sistema esistente
            clientSecret: "" // Sarà gestito dal sistema esistente
        )

        // Autentica con il nuovo sistema
        try await mailService.authenticate(account: account)

        print("✅ MailSystemIntegration: Sistema email inizializzato")
    }

    /// Sincronizza con il sistema email esistente
    public func syncWithExistingSystem(_ existingService: EmailService) {
        print("🔄 MailSystemIntegration: Sincronizzazione con sistema esistente")

        // Sincronizza lo stato di autenticazione
        existingService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)

        // Sincronizza gli errori
        existingService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &cancellables)

        // Sincronizza il conteggio non letti
        existingService.$emails
            .receive(on: DispatchQueue.main)
            .map { emails in
                emails.filter { !$0.isRead }.count
            }
            .assign(to: &$unreadCount)

        print("✅ MailSystemIntegration: Sincronizzazione completata")
    }

    // MARK: - UI Integration

    /// Crea una vista SwiftUI per il nuovo sistema email
    public func createMailView() -> some View {
        return MailInboxView()
    }

    /// Crea una vista per comporre email assistita
    public func createComposeView(
        draft: MailDraft? = nil,
        replyTo: MailMessage? = nil,
        context: ReplyContext? = nil
    ) -> some View {
        return MailComposeView(
            initialDraft: draft,
            replyTo: replyTo,
            context: context
        )
    }

    /// Crea una vista per la chat con integrazione email
    public func createChatWithMailIntegration(chatId: String) -> some View {
        return ChatWithMailView(chatId: chatId)
    }

    // MARK: - API Integration

    /// Invia email tramite il nuovo sistema
    public func sendEmail(
        to: String,
        subject: String,
        body: String,
        isHtml: Bool = false
    ) async throws -> String {
        let draft = MailDraft(
            to: [to],
            subject: subject,
            body: body,
            isHtml: isHtml
        )

        return try await mailService.sendMessage(draft)
    }

    /// Crea bozza di risposta assistita
    public func createReplyDraft(
        for message: MailMessage,
        tone: ReplyTone = .professional,
        includeQuote: Bool = true
    ) async throws -> MailDraft {
        let preferences = UserPreferences(
            name: "Nome Utente", // Sarà configurato dall'utente
            email: mailService.currentAccount?.email ?? ""
        )

        let context = ReplyContext(
            tone: tone,
            includeOriginalQuote: includeQuote,
            userPreferences: preferences
        )

        return try await chatBridgeService.createReplyDraft(for: message, context: context)
    }

    // MARK: - Statistics and Monitoring

    /// Ottiene statistiche del sistema email
    public func getSystemStatistics() -> MailSystemStatistics {
        let mailStats = mailService.getStatistics()
        let categorizationStats = MailCategorizationService.shared.getCategorizationStats()

        return MailSystemStatistics(
            mailStats: mailStats,
            categorizationStats: categorizationStats,
            isOnline: mailService.isOnline,
            syncStatus: mailService.syncStatus
        )
    }

    /// Verifica integrità del sistema
    public func performHealthCheck() async -> MailSystemHealth {
        var issues: [String] = []

        // Verifica autenticazione
        if !mailService.isAuthenticated {
            issues.append("Sistema non autenticato")
        }

        // Verifica connessione
        if !mailService.isOnline {
            issues.append("Sistema offline")
        }

        // Verifica sincronizzazione
        if case .failed = mailService.syncStatus {
            issues.append("Sincronizzazione fallita")
        }

        let health: HealthStatus = issues.isEmpty ? .healthy : .degraded

        return MailSystemHealth(
            status: health,
            issues: issues,
            lastCheck: Date()
        )
    }

    // MARK: - Migration Support

    /// Migra dati dal sistema esistente al nuovo
    public func migrateFromExistingSystem(_ existingEmails: [EmailMessage]) async throws {
        print("🔄 MailSystemIntegration: Inizio migrazione dati")

        var migratedCount = 0

        for email in existingEmails {
            let mailMessage = convertEmailMessageToMailMessage(email)

            do {
                try await mailService.storageService.saveMessage(mailMessage)
                migratedCount += 1
            } catch {
                print("❌ Migrazione fallita per email \(email.id): \(error)")
            }
        }

        print("✅ MailSystemIntegration: Migrate \(migratedCount)/\(existingEmails.count) email")
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Sincronizza le proprietà del mail service
        mailService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthenticated)

        mailService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        mailService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }

    private func convertEmailMessageToMailMessage(_ email: EmailMessage) -> MailMessage {
        let from = MailParticipant(email: email.from, name: nil)
        let to = email.to.map { MailParticipant(email: $0, name: nil) }

        let flags = MailMessageFlags(
            isRead: email.isRead,
            isStarred: false, // Non disponibile nel vecchio modello
            isDeleted: false,
            isDraft: false,
            isAnswered: false,
            isForwarded: false
        )

        return MailMessage(
            id: email.id,
            subject: email.subject,
            bodyPlain: email.body,
            snippet: String(email.body.prefix(100)),
            from: from,
            to: to,
            date: email.date,
            flags: flags,
            providerId: "gmail", // Default
            size: email.body.utf8.count
        )
    }
}

// MARK: - SwiftUI Views (Placeholders)

/// Vista principale della inbox
public struct MailInboxView: View {
    @StateObject private var mailService = MailService.shared

    public var body: some View {
        NavigationView {
            List(mailService.messages) { message in
                MailMessageRow(message: message)
            }
            .navigationTitle("Email")
            .navigationBarItems(trailing: Button(action: {
                Task {
                    try? await mailService.refreshData()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            })
        }
    }
}

/// Riga per messaggio email
public struct MailMessageRow: View {
    let message: MailMessage

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(message.from.displayName)
                    .font(.headline)
                Spacer()
                Text(formatDate(message.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(message.subject)
                .font(.subheadline)
                .lineLimit(1)

            Text(message.snippet)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Vista composizione email
public struct MailComposeView: View {
    let initialDraft: MailDraft?
    let replyTo: MailMessage?
    let context: ReplyContext?

    @State private var to = ""
    @State private var subject = ""
    @State private var body = ""
    @StateObject private var mailService = MailService.shared

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Destinatario")) {
                    TextField("A", text: $to)
                }

                Section(header: Text("Oggetto")) {
                    TextField("Oggetto", text: $subject)
                }

                Section(header: Text("Messaggio")) {
                    TextEditor(text: $body)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("Componi Email")
            .navigationBarItems(
                leading: Button("Annulla") {
                    // Chiudi vista
                },
                trailing: Button("Invia") {
                    Task {
                        let draft = MailDraft(
                            to: [to],
                            subject: subject,
                            body: body
                        )
                        try? await mailService.sendMessage(draft)
                    }
                }
            )
        }
    }
}

/// Vista chat con integrazione email
public struct ChatWithMailView: View {
    let chatId: String

    public var body: some View {
        Text("Chat con integrazione email - ID: \(chatId)")
            .navigationTitle("Chat + Email")
    }
}

// MARK: - Supporting Types

/// Statistiche complete del sistema email
public struct MailSystemStatistics {
    public let mailStats: MailStatistics
    public let categorizationStats: MailCategorizationStats
    public let isOnline: Bool
    public let syncStatus: MailSyncStatus
}

/// Stato di salute del sistema
public struct MailSystemHealth {
    public let status: HealthStatus
    public let issues: [String]
    public let lastCheck: Date
}

/// Stato di salute
public enum HealthStatus {
    case healthy
    case degraded
    case unhealthy
}

// MARK: - Extensions for Existing Types

extension EmailMessage {
    /// Converte EmailMessage esistente in MailMessage nuovo
    func toMailMessage() -> MailMessage {
        let from = MailParticipant(email: self.from, name: nil)
        let to = self.to.map { MailParticipant(email: $0, name: nil) }

        let flags = MailMessageFlags(
            isRead: self.isRead,
            isStarred: false,
            isDeleted: false,
            isDraft: false,
            isAnswered: false,
            isForwarded: false
        )

        return MailMessage(
            id: self.id,
            subject: self.subject,
            bodyPlain: self.body,
            snippet: String(self.body.prefix(100)),
            from: from,
            to: to,
            date: self.date,
            flags: flags,
            providerId: "gmail",
            size: self.body.utf8.count
        )
    }
}

extension EmailService {
    /// Integrazione con il nuovo sistema email
    func integrateWithNewSystem() {
        Task {
            let integration = MailSystemIntegration.shared
            await integration.syncWithExistingSystem(self)

            // Migra email esistenti se necessario
            if !self.emails.isEmpty {
                try? await integration.migrateFromExistingSystem(self.emails)
            }
        }
    }
}
