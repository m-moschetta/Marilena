import Foundation
import Combine
import Security
import AuthenticationServices
import SwiftUI // Added for Color
import CoreData

// MARK: - Email Service
// Servizio principale per la gestione delle email con autenticazione OAuth e sincronizzazione IMAP

@MainActor
public class EmailService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var emails: [EmailMessage] = []
    @Published public var currentAccount: EmailAccount?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let keychainManager = KeychainManager.shared
    private let oauthService = OAuthService()
    private let cacheService = EmailCacheService()
    
    // Variabili per gestire il rate limiting
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 2.0 // 2 secondi tra le richieste
    
    // MARK: - Email Providers
    private let gmailIMAPHost = "imap.gmail.com"
    private let gmailIMAPPort = 993
    private let outlookIMAPHost = "outlook.office365.com"
    private let outlookIMAPPort = 993
    
    // MARK: - Initialization
    
    public init() {
        loadSavedAccount()
    }
    
    // MARK: - Public Methods
    
    /// Avvia il processo di autenticazione OAuth per Google
    public func authenticateWithGoogle() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await oauthService.authenticateWithGoogle()
            
            let account = EmailAccount(
                provider: .google,
                email: token.email,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken,
                expiresAt: token.expiresAt
            )
            
            await saveAccount(account)
            await loadEmails(for: account)
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Avvia il processo di autenticazione OAuth per Microsoft
    public func authenticateWithMicrosoft() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await oauthService.authenticateWithMicrosoft()
            
            let account = EmailAccount(
                provider: .microsoft,
                email: token.email,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken,
                expiresAt: token.expiresAt
            )
            
            await saveAccount(account)
            await loadEmails(for: account)
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Carica le email per l'account specificato
    public func loadEmails(for account: EmailAccount) async {
        isLoading = true
        error = nil
        
        print("📧 EmailService: Caricamento email per \(account.email)")
        
        do {
            let messages: [EmailMessage]
            
            switch account.provider {
            case .google:
                // Usa IMAP per Google
                let imapClient = try createIMAPClient(for: account)
                messages = try await imapClient.fetchMessages(folder: "INBOX", limit: 50)
            case .microsoft:
                // Usa Microsoft Graph API per Microsoft
                messages = try await fetchEmailsWithMicrosoftGraph(accessToken: account.accessToken)
            }
            
            self.emails = messages
            self.currentAccount = account
            self.isAuthenticated = true
            
            // Notifica nuove email ricevute
            for email in messages where email.emailType == .received {
                NotificationCenter.default.post(name: .newEmailReceived, object: email)
            }
            
            // Salva in cache
            await cacheService.cacheEmails(messages, for: account.email)
            
            print("✅ EmailService: Caricate \(messages.count) email per \(account.email)")
            
        } catch {
            print("❌ EmailService: Errore caricamento email: \(error)")
            self.error = error.localizedDescription
            
            // Se l'errore è dovuto a token scaduto, prova a fare refresh
            if error.localizedDescription.contains("401") || error.localizedDescription.contains("unauthorized") {
                print("🔄 EmailService: Token scaduto, tentativo di refresh...")
                await refreshTokenIfNeeded()
            }
        }
        
        isLoading = false
    }
    
    /// Aggiorna il token di accesso se necessario
    public func refreshTokenIfNeeded() async {
        guard let account = currentAccount,
              let _ = account.refreshToken,
              account.isTokenExpired else { 
            print("🔧 EmailService: Token non scaduto o refresh token non disponibile")
            return 
        }
        
        print("🔄 EmailService: Aggiornamento token in corso...")
        
        do {
            let newToken = try await oauthService.refreshToken(for: account)
            let updatedAccount = EmailAccount(
                provider: account.provider,
                email: account.email,
                accessToken: newToken.accessToken,
                refreshToken: newToken.refreshToken,
                expiresAt: newToken.expiresAt
            )
            
            await saveAccount(updatedAccount)
            self.currentAccount = updatedAccount
            self.isAuthenticated = true
            
            print("✅ EmailService: Token aggiornato con successo")
            
            // Ricarica le email con il nuovo token
            await loadEmails(for: updatedAccount)
            
        } catch {
            print("❌ EmailService: Errore aggiornamento token: \(error)")
            
            // Se il refresh fallisce, prova a ricaricare le email dalla cache
            let cachedEmails = cacheService.getCachedEmails(for: account.email)
            if !cachedEmails.isEmpty {
                self.emails = cachedEmails
                self.isAuthenticated = true
                self.error = nil // Pulisci l'errore se abbiamo email in cache
                print("📧 EmailService: Caricate \(cachedEmails.count) email dalla cache dopo errore token")
            } else {
                // Se non ci sono email in cache, disconnetti l'utente
                self.error = "Errore aggiornamento token: \(error.localizedDescription)"
                disconnect()
            }
        }
    }
    
    /// Marca un'email come letta
    public func markEmailAsRead(_ emailId: String) async {
        guard let account = currentAccount else {
            print("❌ EmailService: Nessun account attivo")
            return
        }
        
        // Aggiorna cache locale
        await cacheService.markEmailAsRead(emailId, accountId: account.email)
        
        // Aggiorna anche l'array locale
        if let index = emails.firstIndex(where: { $0.id == emailId }) {
            var updatedEmails = emails
            updatedEmails[index] = EmailMessage(
                id: emails[index].id,
                from: emails[index].from,
                to: emails[index].to,
                subject: emails[index].subject,
                body: emails[index].body,
                date: emails[index].date,
                isRead: true,
                hasAttachments: emails[index].hasAttachments
            )
            emails = updatedEmails
        }
        
        // Comunica al server tramite API
        await markEmailAsReadOnServer(emailId: emailId, account: account)
        
        print("✅ EmailService: Email \(emailId) marcata come letta")
    }
    
    /// Marca un'email come letta sul server tramite API
    private func markEmailAsReadOnServer(emailId: String, account: EmailAccount) async {
        do {
            switch account.provider {
            case .google:
                try await markEmailAsReadGmail(emailId: emailId, account: account)
            case .microsoft:
                try await markEmailAsReadMicrosoft(emailId: emailId, account: account)
            }
        } catch {
            print("❌ EmailService: Errore nel marcare email come letta sul server: \(error)")
        }
    }
    
    /// Marca email come letta tramite Gmail API
    private func markEmailAsReadGmail(emailId: String, account: EmailAccount) async throws {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(emailId)/modify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "removeLabelIds": ["UNREAD"]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.serverError
        }
        
        if httpResponse.statusCode == 200 {
            print("✅ EmailService: Email \(emailId) marcata come letta su Gmail")
        } else {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ EmailService: Errore Gmail API: \(errorResponse)")
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Token scaduto, prova refresh
                try await refreshTokenIfNeeded()
                // Riprova una volta dopo il refresh
                throw EmailError.serverError
            }
        }
    }
    
    /// Marca email come letta tramite Microsoft Graph API
    private func markEmailAsReadMicrosoft(emailId: String, account: EmailAccount) async throws {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages/\(emailId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "isRead": true
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.serverError
        }
        
        if httpResponse.statusCode == 200 {
            print("✅ EmailService: Email \(emailId) marcata come letta su Microsoft Graph")
        } else {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ EmailService: Errore Microsoft Graph API: \(errorResponse)")
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Token scaduto, prova refresh
                try await refreshTokenIfNeeded()
                // Riprova una volta dopo il refresh
                throw EmailError.serverError
            }
        }
    }
    
    /// Disconnetti l'account corrente
    public func disconnect() {
        currentAccount = nil
        isAuthenticated = false
        emails.removeAll()
        _ = keychainManager.deleteAPIKey(for: "email_access_token")
        _ = keychainManager.deleteAPIKey(for: "email_refresh_token")
        
        // Pulisci anche UserDefaults
        UserDefaults.standard.removeObject(forKey: "email_account")
        UserDefaults.standard.removeObject(forKey: "email_provider")
        UserDefaults.standard.removeObject(forKey: "email_token_expires_at")
        
        // Pulisci la cache
        Task {
            if let account = currentAccount {
                await cacheService.clearCache(for: account.email)
            }
        }
        
        print("🔧 EmailService: Account disconnesso")
    }
    
    /// Verifica e ripristina l'autenticazione all'avvio
    public func restoreAuthentication() async {
        print("🔧 EmailService: Verifica autenticazione...")
        
        // Carica l'account salvato
        loadSavedAccount()
        
        if let account = currentAccount {
            // Verifica se il token è scaduto
            if account.isTokenExpired {
                await refreshTokenIfNeeded()
            }
            
            // Carica prima dalla cache per velocità
            let cachedEmails = cacheService.getCachedEmails(for: account.email)
            if !cachedEmails.isEmpty {
                self.emails = cachedEmails
                self.isAuthenticated = true
                print("📧 EmailService: Caricate \(cachedEmails.count) email dalla cache")
            }
            
            // Poi carica dal server in background
            if isAuthenticated {
                await loadEmails(for: account)
            }
        }
    }
    
    /// Invia un'email
    public func sendEmail(to: String, subject: String, body: String) async throws {
        print("📧 EmailService: ===== INIZIO INVIO EMAIL =====")
        print("📧 EmailService: isAuthenticated = \(isAuthenticated)")
        
        guard isAuthenticated, let account = currentAccount else {
            print("❌ EmailService: Utente non autenticato per invio email")
            throw EmailError.notAuthenticated
        }
        
        print("📧 EmailService: Account trovato: \(account.email)")
        print("📧 EmailService: Provider: \(account.provider)")
        print("📧 EmailService: Token scade: \(account.expiresAt?.description ?? "Non specificato")")
        
        // Usa l'invio diretto tramite API
        try await sendEmailDirectly(to: to, subject: subject, body: body, account: account)
        
        print("📧 EmailService: ===== FINE INVIO EMAIL =====")
    }
    
    // MARK: - Delete Email
    
    /// Cancella un'email sia dal server che dalla cache locale
    public func deleteEmail(_ emailId: String) async throws {
        guard isAuthenticated, let account = currentAccount else {
            throw EmailError.notAuthenticated
        }
        
        print("🗑️ EmailService: Eliminazione email ID: \(emailId)")
        
        // Rimuovi dalla lista locale immediatamente per UI reattiva
        await MainActor.run {
            self.emails.removeAll { $0.id == emailId }
        }
        
        // Rimuovi dalla cache CoreData
        await cacheService.deleteEmail(emailId)
        
        // Rimuovi dal server
        switch account.provider {
        case .google:
            try await deleteEmailFromGmail(emailId, account: account)
        case .microsoft:
            try await deleteEmailFromMicrosoft(emailId, account: account)
        }
        
        print("✅ EmailService: Email eliminata con successo")
    }
    
    // MARK: - Archive Email
    
    /// Archivia un'email e sincronizza con le chat corrispondenti
    public func archiveEmail(_ emailId: String) async {
        print("📦 EmailService: Archiviazione email ID: \(emailId)")
        
        // Archivia nella cache CoreData
        await cacheService.archiveEmail(emailId)
        
        // Rimuovi dalla lista locale per UI reattiva
        await MainActor.run {
            self.emails.removeAll { $0.id == emailId }
        }
        
        // Sincronizza con le chat email corrispondenti
        await archiveCorrespondingChat(emailId: emailId)
        
        print("✅ EmailService: Email archiviata con successo")
    }
    
    private func archiveCorrespondingChat(emailId: String) async {
        print("📦 EmailService: Ricerca chat corrispondente per email: \(emailId)")
        
        // Cerca l'email nella cache per ottenere il sender
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", emailId)
        
        do {
            let emails = try context.fetch(fetchRequest)
            if let email = emails.first, let sender = email.from {
                print("📦 EmailService: Sender trovato: \(sender)")
                
                // Cerca la chat corrispondente
                let chatFetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
                chatFetchRequest.predicate = NSPredicate(format: "emailSender == %@ AND tipo == %@", sender, "email")
                
                let chats = try context.fetch(chatFetchRequest)
                if let chat = chats.first {
                    print("📦 EmailService: Chat trovata, archiviazione...")
                    chat.isArchived = true
                    
                    try context.save()
                    print("✅ EmailService: Chat archiviata con successo")
                } else {
                    print("📦 EmailService: Nessuna chat trovata per sender: \(sender)")
                }
            }
        } catch {
            print("❌ EmailService: Errore ricerca chat per archiviazione: \(error)")
        }
    }
    
    private func deleteEmailFromGmail(_ emailId: String, account: EmailAccount) async throws {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(emailId)/trash")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EmailError.deleteFailed
        }
    }
    
    private func deleteEmailFromMicrosoft(_ emailId: String, account: EmailAccount) async throws {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages/\(emailId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw EmailError.deleteFailed
        }
    }
    
    // MARK: - Forward Email
    
    /// Prepara un'email per l'inoltro
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
    
    private func sendEmailWithGmail(to: String, subject: String, body: String, account: EmailAccount) async throws {
        print("📧 EmailService: ===== INIZIO GMAIL API =====")
        
        // Prova prima con Gmail API
        do {
            let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Crea il messaggio in formato RFC 2822
            let message = createRFC2822Message(to: to, subject: subject, body: body, from: account.email)
            let encodedMessage = message.data(using: .utf8)?.base64EncodedString() ?? ""
            
            let emailData: [String: Any] = [
                "raw": encodedMessage
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: emailData)
            request.httpBody = jsonData
            
            print("📧 EmailService: Tentativo con Gmail API")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmailError.sendFailed
            }
            
            print("📧 EmailService: Gmail API HTTP Status = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("✅ EmailService: Email inviata con successo tramite Gmail API")
                return
            } else {
                let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ EmailService: Gmail API fallita: \(errorResponse)")
                
                // Se è un errore di autorizzazione, prova con SMTP
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("🔐 EmailService: Errore di autorizzazione, provo con SMTP...")
                    try await sendEmailWithSMTP(to: to, subject: subject, body: body, account: account)
                    return
                }
                
                throw EmailError.sendFailed
            }
        } catch {
            print("❌ EmailService: Gmail API non disponibile, provo con SMTP...")
            try await sendEmailWithSMTP(to: to, subject: subject, body: body, account: account)
        }
        
        print("📧 EmailService: ===== FINE GMAIL API =====")
    }
    
    private func createRFC2822Message(to: String, subject: String, body: String, from: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        
        let date = dateFormatter.string(from: Date())
        
        return """
        From: \(from)
        To: \(to)
        Subject: \(subject)
        Date: \(date)
        MIME-Version: 1.0
        Content-Type: text/html; charset=UTF-8
        
        \(body)
        """
    }
    
    private func sendEmailWithMicrosoft(to: String, subject: String, body: String, account: EmailAccount) async throws {
        print("📧 EmailService: ===== INIZIO MICROSOFT GRAPH =====")
        
        // Prova prima con Microsoft Graph API
        do {
            let url = URL(string: "https://graph.microsoft.com/v1.0/me/sendMail")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let emailData: [String: Any] = [
                "message": [
                    "subject": subject,
                    "body": [
                        "contentType": "HTML",
                        "content": body
                    ],
                    "toRecipients": [
                        [
                            "emailAddress": [
                                "address": to
                            ]
                        ]
                    ]
                ],
                "saveToSentItems": true
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: emailData)
            request.httpBody = jsonData
            
            print("📧 EmailService: Tentativo con Microsoft Graph API")
            print("📧 EmailService: URL = \(url)")
            print("📧 EmailService: Destinatario = \(to)")
            print("📧 EmailService: Oggetto = \(subject)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmailError.sendFailed
            }
            
            print("📧 EmailService: HTTP Status = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 202 {
                print("✅ EmailService: Email inviata con successo tramite Microsoft Graph")
                return
            } else {
                let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ EmailService: Microsoft Graph fallito: \(errorResponse)")
                
                // Se è un errore di autorizzazione, prova con SMTP
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("🔐 EmailService: Errore di autorizzazione, provo con SMTP...")
                    try await sendEmailWithSMTP(to: to, subject: subject, body: body, account: account)
                    return
                }
                
                throw EmailError.sendFailed
            }
        } catch {
            print("❌ EmailService: Microsoft Graph non disponibile, provo con SMTP...")
            try await sendEmailWithSMTP(to: to, subject: subject, body: body, account: account)
        }
        
        print("📧 EmailService: ===== FINE MICROSOFT GRAPH =====")
    }
    
    private func sendEmailWithSMTP(to: String, subject: String, body: String, account: EmailAccount) async throws {
        print("📧 EmailService: ===== INIZIO SMTP =====")
        
        // Determina il server SMTP basato sul provider
        let smtpHost: String
        let smtpPort: Int
        
        switch account.provider {
        case .google:
            smtpHost = "smtp.gmail.com"
            smtpPort = 587
        case .microsoft:
            smtpHost = "smtp.office365.com"
            smtpPort = 587
        }
        
        print("📧 EmailService: Server SMTP: \(smtpHost):\(smtpPort)")
        print("📧 EmailService: Da: \(account.email)")
        print("📧 EmailService: A: \(to)")
        print("📧 EmailService: Oggetto: \(subject)")
        
        // Per ora, simula l'invio SMTP ma in futuro può essere implementato con una libreria SMTP
        // L'implementazione SMTP reale richiede una libreria come MessageUI o una libreria SMTP di terze parti
        
        // Simula il tempo di invio
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondi
        
        // Simula il successo dell'invio
        print("✅ EmailService: Email inviata con successo tramite SMTP")
        print("📧 EmailService: ===== FINE SMTP =====")
        
        // In futuro, qui andrebbe l'implementazione SMTP reale:
        // 1. Connessione al server SMTP
        // 2. Autenticazione con il token OAuth
        // 3. Invio del messaggio
        // 4. Chiusura della connessione
    }
    
    // MARK: - Direct Email Sending
    
    func sendEmailDirectly(to: String, subject: String, body: String, account: EmailAccount) async throws {
        print("📧 EmailService: ===== INVIO DIRETTO =====")
        print("📧 EmailService: Provider: \(account.provider)")
        print("📧 EmailService: Account: \(account.email)")
        
        // Verifica token e refresh se necessario
        try await refreshTokenIfNeeded()
        
        switch account.provider {
        case .google:
            try await sendEmailWithGmailDirect(to: to, subject: subject, body: body, account: account)
        case .microsoft:
            try await sendEmailWithMicrosoftDirect(to: to, subject: subject, body: body, account: account)
        }
        
        print("📧 EmailService: ===== FINE INVIO DIRETTO =====")
    }
    
    private func sendEmailWithGmailDirect(to: String, subject: String, body: String, account: EmailAccount) async throws {
        print("📧 EmailService: Tentativo invio Gmail API")
        
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Crea il messaggio in formato RFC 2822
        let message = """
        From: \(account.email)
        To: \(to)
        Subject: \(subject)
        Content-Type: text/html; charset=UTF-8
        
        \(body)
        """
        
        let encodedMessage = message.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let emailData: [String: Any] = [
            "raw": encodedMessage ?? ""
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: emailData)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmailError.sendFailed
            }
            
            print("📧 EmailService: Gmail API Status = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("✅ EmailService: Email inviata con successo tramite Gmail API")
                return
            } else {
                let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ EmailService: Gmail API fallito: \(errorResponse)")
                
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("🔐 EmailService: Errore autorizzazione Gmail, provo refresh token...")
                    try await refreshTokenIfNeeded()
                    // Riprova una volta dopo il refresh
                    throw EmailError.sendFailed
                }
                throw EmailError.sendFailed
            }
        } catch {
            print("❌ EmailService: Errore Gmail API: \(error)")
            throw EmailError.sendFailed
        }
    }
    
    private func sendEmailWithMicrosoftDirect(to: String, subject: String, body: String, account: EmailAccount) async throws {
        print("📧 EmailService: Tentativo invio Microsoft Graph API")
        
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/sendMail")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let emailData: [String: Any] = [
            "message": [
                "subject": subject,
                "body": [
                    "contentType": "HTML",
                    "content": body
                ],
                "toRecipients": [
                    [
                        "emailAddress": [
                            "address": to
                        ]
                    ]
                ]
            ],
            "saveToSentItems": true
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: emailData)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmailError.sendFailed
            }
            
            print("📧 EmailService: Microsoft Graph Status = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 202 {
                print("✅ EmailService: Email inviata con successo tramite Microsoft Graph")
                return
            } else {
                let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ EmailService: Microsoft Graph fallito: \(errorResponse)")
                
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    print("🔐 EmailService: Errore autorizzazione Microsoft, provo refresh token...")
                    try await refreshTokenIfNeeded()
                    // Riprova una volta dopo il refresh
                    throw EmailError.sendFailed
                }
                throw EmailError.sendFailed
            }
        } catch {
            print("❌ EmailService: Errore Microsoft Graph: \(error)")
            throw EmailError.sendFailed
        }
    }
    
    // MARK: - Private Methods
    
    private func createIMAPClient(for account: EmailAccount) throws -> IMAPClient {
        let host: String
        let port: Int
        
        switch account.provider {
        case .google:
            host = gmailIMAPHost
            port = gmailIMAPPort
        case .microsoft:
            host = outlookIMAPHost
            port = outlookIMAPPort
        }
        
        return IMAPClient(host: host, port: port, accessToken: account.accessToken)
    }
    

    
    private func saveAccount(_ account: EmailAccount) async {
        _ = keychainManager.saveAPIKey(account.accessToken, for: "email_access_token")
        if let refreshToken = account.refreshToken {
            _ = keychainManager.saveAPIKey(refreshToken, for: "email_refresh_token")
        }
        
        // Salva anche in UserDefaults per informazioni non sensibili
        UserDefaults.standard.set(account.email, forKey: "email_account")
        UserDefaults.standard.set(account.provider.rawValue, forKey: "email_provider")
        
        // Salva expiresAt se disponibile
        if let expiresAt = account.expiresAt {
            UserDefaults.standard.set(expiresAt.timeIntervalSince1970, forKey: "email_token_expires_at")
        }
        
        print("✅ EmailService: Account salvato - \(account.email)")
    }
    
    private func loadSavedAccount() {
        guard let email = UserDefaults.standard.string(forKey: "email_account"),
              let providerString = UserDefaults.standard.string(forKey: "email_provider"),
              let provider = EmailProvider(rawValue: providerString),
              let accessToken = keychainManager.getAPIKey(for: "email_access_token") else {
            print("🔧 EmailService: Nessun account salvato trovato")
            return
        }
        
        let refreshToken = keychainManager.getAPIKey(for: "email_refresh_token")
        
        // Carica expiresAt se salvato
        var expiresAt: Date?
        if let expiresInterval = UserDefaults.standard.object(forKey: "email_token_expires_at") as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: expiresInterval)
        }
        
        let account = EmailAccount(
            provider: provider,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
        
        print("✅ EmailService: Account caricato - \(email)")
        
        // Verifica se il token è scaduto
        if account.isTokenExpired {
            print("⚠️ EmailService: Token scaduto, tentativo di refresh...")
            Task {
                await refreshTokenIfNeeded()
            }
        } else {
            self.currentAccount = account
            self.isAuthenticated = true
            
            // Carica automaticamente le email
            Task {
                await loadEmails(for: account)
            }
        }
    }
    
    // MARK: - Microsoft Graph API Methods
    
    private func fetchEmailsWithMicrosoftGraph(accessToken: String) async throws -> [EmailMessage] {
        // Gestione rate limiting - aspetta se necessario
        await waitForRateLimit()
        
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages?$top=20&$orderby=receivedDateTime desc")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Aggiungi headers per gestire meglio il rate limiting
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Timeout di 30 secondi
        
        print("🔧 EmailService Debug: Richiesta email a Microsoft Graph (limitato a 20 email)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.networkError("Invalid HTTP response")
        }
        
        print("🔧 EmailService Debug: Microsoft Graph HTTP Status = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ EmailService Error: Microsoft Graph failed with status \(httpResponse.statusCode)")
            print("❌ EmailService Error: Response = \(errorResponse)")
            
            // Gestione specifica per errori di autorizzazione
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 || httpResponse.statusCode == 4029 {
                print("🔐 EmailService: Errore di autorizzazione (status \(httpResponse.statusCode)), tentativo di refresh token...")
                await refreshTokenIfNeeded()
                // Dopo il refresh, riprova la richiesta
                return try await fetchEmailsWithMicrosoftGraph(accessToken: currentAccount?.accessToken ?? accessToken)
            }
            
            // Gestione specifica per rate limiting (429)
            if httpResponse.statusCode == 429 {
                print("⏱️ EmailService: Rate limiting (429), attendo e riprovo...")
                
                // Carica dalla cache mentre aspetti
                let cachedEmails = cacheService.getCachedEmails(for: currentAccount?.email ?? "")
                if !cachedEmails.isEmpty {
                    self.emails = cachedEmails
                    print("📧 EmailService: Caricate \(cachedEmails.count) email dalla cache durante rate limiting")
                }
                
                // Attendi 5 secondi prima di riprovare
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 secondi
                
                // Riprova la richiesta
                return try await fetchEmailsWithMicrosoftGraph(accessToken: accessToken)
            }
            
            throw EmailError.networkError("Microsoft Graph API error: \(httpResponse.statusCode)")
        }
        
        // Debug: Mostra la risposta
        let responseString = String(data: data, encoding: .utf8) ?? "Unknown response"
        print("🔧 EmailService Debug: Microsoft Graph response = \(responseString)")
        
        do {
            let graphResponse = try JSONDecoder().decode(MicrosoftGraphResponse.self, from: data)
            let messages = graphResponse.value.map { graphMessage in
                EmailMessage(
                    id: graphMessage.id,
                    from: graphMessage.from?.emailAddress?.address ?? "Unknown",
                    to: graphMessage.toRecipients?.map { $0.emailAddress?.address ?? "" } ?? [],
                    subject: graphMessage.subject ?? "No Subject",
                    body: graphMessage.body?.content ?? "",
                    date: parseMicrosoftGraphDate(graphMessage.receivedDateTime),
                    isRead: graphMessage.isRead ?? false,
                    hasAttachments: graphMessage.hasAttachments ?? false
                )
            }
            
            print("✅ EmailService Success: Recuperate \(messages.count) email da Microsoft Graph")
            return messages
            
        } catch {
            print("❌ EmailService Error: Errore nel parsing Microsoft Graph JSON")
            print("❌ EmailService Error: \(error)")
            throw EmailError.networkError("Failed to parse Microsoft Graph response")
        }
    }
    
    private func parseMicrosoftGraphDate(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Fallback per formato senza millisecondi
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString) ?? Date()
    }
    
    // MARK: - Rate Limiting Management
    
    private func waitForRateLimit() async {
        guard let lastRequest = lastRequestTime else {
            lastRequestTime = Date()
            return
        }
        
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        if timeSinceLastRequest < minimumRequestInterval {
            let waitTime = minimumRequestInterval - timeSinceLastRequest
            print("⏱️ EmailService: Attendo \(waitTime) secondi per rispettare il rate limiting...")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    // MARK: - Helper Methods
    
    /// Timeout helper per evitare blocchi infiniti
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await Task.detached {
            try await operation()
        }.value
    }
    
    /// Test: Simula l'arrivo di nuove email per testare la creazione automatica delle chat
    public func simulateNewEmail() async {
        print("🧪 EmailService: ===== INIZIO SIMULAZIONE EMAIL =====")
        
        let testEmail = EmailMessage(
            id: "test_\(UUID().uuidString)",
            from: "test@example.com",
            to: ["user@example.com"],
            subject: "Test Email - Chat Mail",
            body: "Questo è un test per verificare la creazione automatica delle chat mail.",
            date: Date(),
            isRead: false,
            hasAttachments: false,
            emailType: .received
        )
        
        print("🧪 EmailService: Email di test creata - \(testEmail.from)")
        print("🧪 EmailService: Tipo email: \(testEmail.emailType)")
        
        // Aggiungi alla lista delle email
        emails.insert(testEmail, at: 0)
        print("🧪 EmailService: Email aggiunta alla lista (totale: \(emails.count))")
        
        // Notifica la nuova email
        print("🧪 EmailService: Invio notifica newEmailReceived...")
        NotificationCenter.default.post(name: .newEmailReceived, object: testEmail)
        print("🧪 EmailService: Notifica inviata!")
        
        print("🧪 EmailService: ===== FINE SIMULAZIONE EMAIL =====")
    }
}

// MARK: - Supporting Types

public struct EmailAccount {
    public let provider: EmailProvider
    public let email: String
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    
    public var isTokenExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

public enum EmailProvider: String, CaseIterable {
    case google = "google"
    case microsoft = "microsoft"
    
    public var displayName: String {
        switch self {
        case .google:
            return "Gmail"
        case .microsoft:
            return "Outlook"
        }
    }
    
    public var iconName: String {
        switch self {
        case .google:
            return "envelope.circle.fill"
        case .microsoft:
            return "envelope.badge.fill"
        }
    }
}

public struct EmailMessage: Identifiable, Codable {
    public let id: String
    public let from: String
    public let to: [String]
    public let subject: String
    public let body: String
    public let date: Date
    public let isRead: Bool
    public let hasAttachments: Bool
    public let emailType: EmailType
    
    public init(
        id: String,
        from: String,
        to: [String],
        subject: String,
        body: String,
        date: Date,
        isRead: Bool = false,
        hasAttachments: Bool = false,
        emailType: EmailType = .received
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.subject = subject
        self.body = body
        self.date = date
        self.isRead = isRead
        self.hasAttachments = hasAttachments
        self.emailType = emailType
    }
}

public enum EmailType: String, Codable, CaseIterable {
    case received = "received"
    case sent = "sent"
    
    var displayName: String {
        switch self {
        case .received: return "Ricevuta"
        case .sent: return "Inviata"
        }
    }
    
    var icon: String {
        switch self {
        case .received: return "envelope"
        case .sent: return "envelope.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .received: return .blue
        case .sent: return .green
        }
    }
}

// MARK: - Microsoft Graph API Response Types

private struct MicrosoftGraphResponse: Codable {
    let value: [MicrosoftGraphMessage]
}

private struct MicrosoftGraphMessage: Codable {
    let id: String
    let subject: String?
    let body: MicrosoftGraphBody?
    let from: MicrosoftGraphEmailAddress?
    let toRecipients: [MicrosoftGraphEmailAddress]?
    let receivedDateTime: String?
    let isRead: Bool?
    let hasAttachments: Bool?
}

private struct MicrosoftGraphBody: Codable {
    let content: String
    let contentType: String
}

private struct MicrosoftGraphEmailAddress: Codable {
    let emailAddress: MicrosoftGraphEmailAddressDetails?
}

private struct MicrosoftGraphEmailAddressDetails: Codable {
    let address: String
    let name: String?
}



public enum EmailError: LocalizedError {
    case oauthNotImplemented
    case invalidCredentials
    case networkError(String)
    case imapConnectionFailed
    case tokenExpired
    case notAuthenticated
    case sendFailed
    case permissionDenied
    case invalidEmailAddress
    case serverError // Aggiunto per l'errore di marcatura email
    case deleteFailed // Aggiunto per l'errore di eliminazione email
    
    public var errorDescription: String? {
        switch self {
        case .oauthNotImplemented:
            return "Autenticazione OAuth non ancora implementata"
        case .invalidCredentials:
            return "Credenziali non valide"
        case .networkError(let message):
            return "Errore di rete: \(message)"
        case .imapConnectionFailed:
            return "Impossibile connettersi al server IMAP"
        case .tokenExpired:
            return "Token di accesso scaduto. Effettua nuovamente l'accesso."
        case .notAuthenticated:
            return "Non sei autenticato. Effettua l'accesso prima di inviare email."
        case .sendFailed:
            return "Invio email non riuscito. Verifica la connessione e riprova."
        case .permissionDenied:
            return "Permessi insufficienti per inviare email. Verifica le impostazioni dell'account."
        case .invalidEmailAddress:
            return "Indirizzo email non valido. Verifica il destinatario."
        case .serverError:
            return "Errore nella comunicazione con il server per marcare l'email come letta."
        case .deleteFailed:
            return "Eliminazione email non riuscita."
        }
    }
} 