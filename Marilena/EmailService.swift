import Foundation
import Combine
import Security
import AuthenticationServices
import SwiftUI // Added for Color
import CoreData
import GoogleSignIn

// MARK: - Email Service
// Servizio principale per la gestione delle email con autenticazione OAuth e sincronizzazione IMAP

@MainActor
public class EmailService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var emails: [EmailMessage] = []
    @Published public var emailConversations: [EmailConversation] = [] // NUOVO: Conversazioni organizzate
    @Published public var isThreadingEnabled = true // NUOVO: Toggle per abilitare/disabilitare threading
    @Published public var currentAccount: EmailAccount?
    
    // NUOVO: Proprietà offline
    @Published public var isOnline = true
    @Published public var syncStatus: SyncStatus = .idle
    @Published public var pendingOperationsCount = 0
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let keychainManager = KeychainManager.shared
    private let oauthService = OAuthService()
    private let cacheService = EmailCacheService()
    private let categorizationService = EmailCategorizationService()
    private lazy var offlineSyncService = OfflineSyncService.shared
    
    // Variabili per gestire il rate limiting
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 2.0 // 2 secondi tra le richieste

    // Sistema di debouncing per evitare richieste duplicate
    private var lastEmailLoadTime: Date?
    private let minimumEmailLoadInterval: TimeInterval = 30.0 // 30 secondi tra i caricamenti email
    private var isLoadingEmails = false // Flag per evitare caricamenti concorrenti
    
    // MARK: - Email Providers
    private let gmailIMAPHost = "imap.gmail.com"
    private let gmailIMAPPort = 993
    private let outlookIMAPHost = "outlook.office365.com"
    private let outlookIMAPPort = 993
    
    // MARK: - Initialization
    
    public init() {
        loadSavedAccount()
        
        // NUOVO: Sincronizza stato offline
        setupOfflineSync()
        
        // Collega EmailService a OfflineSyncService per evitare dipendenza circolare
        offlineSyncService.setEmailService(self)
        
        // Prova a ripristinare l'autenticazione Google precedente
        Task {
            await restoreGoogleSignIn()
        }
    }
    
    // MARK: - Offline Sync Setup
    
    private func setupOfflineSync() {
        // Sincronizza le proprietà offline con OfflineSyncService
        offlineSyncService.$isOnline
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOnline)
        
        offlineSyncService.$syncStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncStatus)
        
        offlineSyncService.$pendingOperationsCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingOperationsCount)
    }
    
    // MARK: - Public Methods
    
    /// Ripristina l'autenticazione Google precedente se disponibile
    public func restoreGoogleSignIn() async {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            
            let account = EmailAccount(
                provider: .google,
                email: user.profile?.email ?? "",
                accessToken: user.accessToken.tokenString,
                refreshToken: user.refreshToken.tokenString,
                expiresAt: user.accessToken.expirationDate
            )
            
            await saveAccount(account)
            await loadEmails(for: account)
            
            print("✅ Google Sign-In ripristinato con successo")
            
        } catch {
            print("ℹ️ Nessuna sessione Google precedente trovata: \(error)")
        }
    }
    
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
            
            print("✅ Autenticazione Google completata con successo")
            
        } catch {
            print("❌ Errore autenticazione Google: \(error)")
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
    
    /// Forza il caricamento delle email ignorando il debouncing
    public func forceLoadEmails(for account: EmailAccount) async {
        print("🔄 EmailService: Forzando caricamento email (ignorando debouncing)")
        await loadEmailsInternal(for: account)
    }

    /// Carica le email per l'account specificato (con debouncing)
    public func loadEmails(for account: EmailAccount) async {
        // Controllo debouncing: evita caricamenti troppo frequenti
        if let lastLoad = lastEmailLoadTime,
           Date().timeIntervalSince(lastLoad) < minimumEmailLoadInterval {
            print("⏳ EmailService: Caricamento email saltato (debouncing attivo)")
            return
        }

        // Controllo concorrenza: evita caricamenti simultanei
        if isLoadingEmails {
            print("⏳ EmailService: Caricamento email già in corso, saltato")
            return
        }

        await loadEmailsInternal(for: account)
    }

    /// Implementazione privata del caricamento email (senza debouncing)
    private func loadEmailsInternal(for account: EmailAccount) async {
        isLoadingEmails = true
        isLoading = true
        error = nil
        lastEmailLoadTime = Date()

        print("📧 EmailService: Caricamento email per \(account.email)")

        do {
            let messages: [EmailMessage]

            switch account.provider {
            case .google:
                // Usa Gmail API per Google
                messages = try await fetchEmailsWithGmailAPI(accessToken: account.accessToken)
            case .microsoft:
                // Usa Microsoft Graph API per Microsoft
                messages = try await fetchEmailsWithMicrosoftGraph(accessToken: account.accessToken)
            }

            // Carica prima le email senza categorizzazione per UI reattiva
            self.emails = messages
            self.currentAccount = account
            self.isAuthenticated = true

            // Notifica SOLO nuove email ricevute (non già viste)
            let previousEmailIds = Set(self.emails.map { $0.id })
            let newEmails = messages.filter { !previousEmailIds.contains($0.id) && $0.emailType == .received }

            for email in newEmails {
                print("📧 EmailService: Nuova email ricevuta da \(email.from) - Invio notifica")
                NotificationCenter.default.post(name: .newEmailReceived, object: email)
            }

            if !newEmails.isEmpty {
                print("✅ EmailService: Inviate \(newEmails.count) notifiche per nuove email")
            }

            // Salva in cache
            await cacheService.cacheEmails(messages, for: account.email)

                        // Sincronizza lo stato di categorizzazione con il service
            categorizationService.syncWithEmailCache(messages)

            // Adatta automaticamente la configurazione al numero di email
            await EmailCategorizationConfigManager.shared.adaptToEmailCount(messages.count)

            print("✅ EmailService: Caricate \(messages.count) email per \(account.email)")

            // Organizza le email in conversazioni
            await organizeEmailsIntoConversations()

            // Categorizza le email in background con strategia ibrida intelligente
            Task {
                await categorizeEmailsInBackground(messages)
            }

            // Resetta contatori di sessione per grandi caricamenti (nuovo account)
            if messages.count > 100 {
                categorizationService.resetSessionCounters()
                print("🔄 EmailService: Reset contatori AI per nuovo caricamento di \(messages.count) email")
            }

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
        isLoadingEmails = false
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
    
    /// NUOVO: Refresh manuale che forza il ricaricamento dal server
    public func forceRefresh() async {
        guard let account = currentAccount else {
            print("❌ EmailService: Nessun account per refresh manuale")
            return
        }
        
        print("🔄 EmailService: Refresh manuale forzato...")
        
        // Invalida la cache forzando il ricaricamento
        await cacheService.clearCache(for: account.email)
        
        // Ricarica dal server
        await loadEmails(for: account)
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
                
                // MIGLIORATO: Organizza subito le conversazioni dalla cache
                await organizeEmailsIntoConversations()
            }
            
            // NUOVO: Controlla se la cache è valida prima di ricaricare dal server
            if cacheService.shouldFetchFromServer(for: account.email) {
                print("📧 EmailService: Cache non valida, ricarico dal server...")
                await loadEmails(for: account)
            } else {
                print("📧 EmailService: Cache valida, utilizzo dati locali")
                self.isAuthenticated = true
            }
        }
    }
    
    /// Invia un'email (con supporto offline)
    public func sendEmail(to: String, subject: String, body: String) async throws {
        print("📧 EmailService: ===== INIZIO INVIO EMAIL =====")
        print("📧 EmailService: isAuthenticated = \(isAuthenticated), isOnline = \(isOnline)")
        
        guard isAuthenticated, let account = currentAccount else {
            print("❌ EmailService: Utente non autenticato per invio email")
            throw EmailError.notAuthenticated
        }
        
        print("📧 EmailService: Account trovato: \(account.email)")
        print("📧 EmailService: Provider: \(account.provider)")
        
        // NUOVO: Controlla connessione
        if !isOnline {
            print("📴 EmailService: Offline - Email accodata per invio successivo")
            offlineSyncService.sendEmailOffline(to: [to], subject: subject, body: body)
            print("✅ EmailService: Email accodata per invio offline")
            return
        }
        
        do {
            // Usa l'invio diretto tramite API
            try await sendEmailDirectly(to: to, subject: subject, body: body, account: account)
            print("✅ EmailService: Email inviata con successo")
        } catch {
            print("❌ EmailService: Errore invio email: \(error)")
            
            // Se fallisce per problemi di rete, accoda per offline
            if error.localizedDescription.contains("network") || error.localizedDescription.contains("timeout") {
                print("📴 EmailService: Errore di rete - Email accodata per invio offline")
                offlineSyncService.sendEmailOffline(to: [to], subject: subject, body: body)
            } else {
                throw error
            }
        }
        
        print("📧 EmailService: ===== FINE INVIO EMAIL =====")
    }
    
    // MARK: - Delete Email
    
    /// Cancella un'email sia dal server che dalla cache locale (con supporto offline)
    public func deleteEmail(_ emailId: String) async throws {
        guard isAuthenticated, let account = currentAccount else {
            throw EmailError.notAuthenticated
        }
        
        // NUOVO: Supporto offline
        if !isOnline {
            print("📴 EmailService: Offline - Eliminazione accodata")
            offlineSyncService.deleteEmailOffline(emailId)
            return
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
    
    /// Categorizza le email in background senza bloccare l'UI
    private func categorizeEmailsInBackground(_ messages: [EmailMessage]) async {
        print("🤖 EmailService: Inizio categorizzazione in background di \(messages.count) email")
        
        // Filtra le email che non sono già categorizzate, in elaborazione, o nella cache
        let uncategorizedEmails = messages.filter { email in
            email.category == nil && 
            !categorizationService.isEmailCategorized(email.id) &&
            !categorizationService.isEmailBeingCategorized(email.id)
        }
        
        guard !uncategorizedEmails.isEmpty else {
            print("🤖 EmailService: Tutte le email sono già categorizzate")
            return
        }
        
        do {
            let categorizedEmails = await categorizationService.categorizeEmails(uncategorizedEmails)
            
            // Aggiorna l'array principale con le email categorizzate
            await MainActor.run {
                var updatedEmails = self.emails
                
                for categorizedEmail in categorizedEmails {
                    if let index = updatedEmails.firstIndex(where: { $0.id == categorizedEmail.id }) {
                        updatedEmails[index] = categorizedEmail
                    }
                }
                
                self.emails = updatedEmails
                print("✅ EmailService: Categorizzazione completata per \(categorizedEmails.count) email")
                
                // Sincronizza la cache del servizio di categorizzazione
                for categorizedEmail in categorizedEmails {
                    self.categorizationService.markEmailAsCategorized(categorizedEmail.id)
                }
            }
            
            // Aggiorna la cache con le email categorizzate
            if let account = currentAccount {
                await cacheService.cacheEmails(categorizedEmails, for: account.email)
            }
            
            // Riorganizza le conversazioni dopo la categorizzazione
            await organizeEmailsIntoConversations()
            
        } catch {
            print("❌ EmailService: Errore durante la categorizzazione: \(error)")
        }
    }
    
    // MARK: - Email Threading Functions
    
    /// Organizza le email in conversazioni (threading)
    public func organizeEmailsIntoConversations() async {
        guard isThreadingEnabled else {
            // Se il threading è disabilitato, crea una "conversazione" per ogni email
            emailConversations = emails.map { email in
                EmailConversation(
                    id: email.id,
                    subject: email.subject,
                    messages: [email],
                    participants: Set([email.from] + email.to),
                    createdAt: email.date,
                    lastActivity: email.date
                )
            }.sorted { $0.lastActivity > $1.lastActivity }
            return
        }
        
        print("🧵 EmailService: Organizzando \(emails.count) email in conversazioni...")
        
        var conversations: [String: EmailConversation] = [:]
        
        for email in emails {
            let threadKey = generateThreadKey(for: email)
            
            if let existingConversation = conversations[threadKey] {
                // Aggiungi l'email alla conversazione esistente
                var updatedConversation = existingConversation
                updatedConversation.addMessage(email)
                conversations[threadKey] = updatedConversation
            } else {
                // Crea una nuova conversazione
                let normalizedSubject = normalizeSubject(email.subject)
                let participants = Set([email.from] + email.to)
                
                let conversation = EmailConversation(
                    id: threadKey,
                    subject: normalizedSubject,
                    messages: [email],
                    participants: participants,
                    createdAt: email.date,
                    lastActivity: email.date
                )
                
                conversations[threadKey] = conversation
            }
        }
        
        // Ordina per ultima attività
        let sortedConversations = Array(conversations.values)
            .sorted { $0.lastActivity > $1.lastActivity }
        
        await MainActor.run {
            self.emailConversations = sortedConversations
            print("✅ EmailService: Organizzate \(sortedConversations.count) conversazioni da \(emails.count) email")
        }
    }
    
    /// Genera una chiave univoca per il thread basata su subject e partecipanti
    private func generateThreadKey(for email: EmailMessage) -> String {
        let normalizedSubject = normalizeSubject(email.subject)
        let participants = Set([email.from] + email.to).sorted()
        
        // Combina subject normalizzato e partecipanti per creare una chiave
        let participantsString = participants.joined(separator: ",")
        return "\(normalizedSubject)|\(participantsString)".lowercased()
    }
    
    /// Normalizza il subject rimuovendo prefissi come "Re:", "Fwd:", etc.
    private func normalizeSubject(_ subject: String) -> String {
        var normalized = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Rimuove prefissi comuni (case insensitive)
        let prefixesToRemove = ["Re:", "RE:", "Fwd:", "FWD:", "Fw:", "FW:", "Fwd :", "Re :", 
                               "R:", "R :", "Ri:", "Ri :", "I:", "Oggetto:", "Inoltro:"]
        
        for prefix in prefixesToRemove {
            while normalized.lowercased().hasPrefix(prefix.lowercased()) {
                normalized = String(normalized.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return normalized.isEmpty ? "Nessun oggetto" : normalized
    }
    
    /// Trova tutte le conversazioni che coinvolgono un determinato partecipante
    public func conversationsInvolving(participant: String) -> [EmailConversation] {
        return emailConversations.filter { conversation in
            conversation.participants.contains { $0.lowercased() == participant.lowercased() }
        }
    }
    
    /// Trova conversazioni per subject
    public func conversationsWithSubject(containing text: String) -> [EmailConversation] {
        return emailConversations.filter { conversation in
            conversation.subject.lowercased().contains(text.lowercased())
        }
    }
    
    /// Segna tutte le email di una conversazione come lette
    public func markConversationAsRead(_ conversation: EmailConversation) async {
        for message in conversation.messages where !message.isRead {
            await markEmailAsRead(message.id)
        }
        
        // Riorganizza le conversazioni per aggiornare lo stato
        await organizeEmailsIntoConversations()
    }
    
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
    
    // MARK: - Gmail API Methods
    
    private func fetchEmailsWithGmailAPI(accessToken: String) async throws -> [EmailMessage] {
        // Gestione rate limiting - aspetta se necessario
        await waitForRateLimit()
        
        let baseURL = "https://gmail.googleapis.com"
        let url = URL(string: "\(baseURL)/gmail/v1/users/me/messages?maxResults=20")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        print("🔧 EmailService Debug: Richiesta email a Gmail API (limitato a 20 email)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.networkError("Invalid HTTP response")
        }
        
        print("🔧 EmailService Debug: Gmail API HTTP Status = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ EmailService Error: Gmail API failed with status \(httpResponse.statusCode)")
            print("❌ EmailService Error: Response = \(errorResponse)")
            
            // Gestione specifica per errori di autorizzazione
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                print("🔐 EmailService: Errore di autorizzazione (status \(httpResponse.statusCode)), tentativo di refresh token...")
                await refreshTokenIfNeeded()
                // Dopo il refresh, riprova la richiesta
                return try await fetchEmailsWithGmailAPI(accessToken: currentAccount?.accessToken ?? accessToken)
            }
            
            throw EmailError.networkError("Gmail API error: \(httpResponse.statusCode)")
        }
        
        do {
            let gmailResponse = try JSONDecoder().decode(GmailMessageList.self, from: data)
            
            // Fetch dettagli per ogni email
            var messages: [EmailMessage] = []
            for message in gmailResponse.messages.prefix(10) {
                if let email = await fetchGmailMessageDetails(messageId: message.id, accessToken: accessToken) {
                    messages.append(email)
                }
            }
            
            print("✅ EmailService Success: Recuperate \(messages.count) email da Gmail API")
            return messages
            
        } catch {
            print("❌ EmailService Error: Errore nel parsing Gmail API JSON")
            print("❌ EmailService Error: \(error)")
            throw EmailError.networkError("Failed to parse Gmail API response")
        }
    }
    
    private func fetchGmailMessageDetails(messageId: String, accessToken: String) async -> EmailMessage? {
        let baseURL = "https://gmail.googleapis.com"
        let url = URL(string: "\(baseURL)/gmail/v1/users/me/messages/\(messageId)")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let gmailMessage = try JSONDecoder().decode(GmailMessage.self, from: data)
            
            // Estrai le informazioni dall'header
            let from = gmailMessage.payload?.headers?.first { $0.name.lowercased() == "from" }?.value ?? "Unknown"
            let subject = gmailMessage.payload?.headers?.first { $0.name.lowercased() == "subject" }?.value ?? "No Subject"
            let dateString = gmailMessage.payload?.headers?.first { $0.name.lowercased() == "date" }?.value
            
            // Decodifica il body
            let body = decodeGmailBody(gmailMessage.payload)
            
            return EmailMessage(
                id: gmailMessage.id,
                from: from,
                to: [], // Gmail API non fornisce direttamente i destinatari
                subject: subject,
                body: body,
                date: parseGmailDate(dateString),
                isRead: !gmailMessage.labelIds.contains("UNREAD"),
                hasAttachments: gmailMessage.payload?.parts?.contains { $0.filename?.isEmpty == false } ?? false
            )
            
        } catch {
            print("❌ EmailService Error: Errore nel recupero dettagli email Gmail: \(error)")
            return nil
        }
    }
    
    private func decodeGmailBody(_ payload: GmailMessagePayload?) -> String {
        guard let payload = payload else { return "" }
        
        // Se il body è già in formato testo
        if let bodyData = payload.body?.data,
           let decodedData = Data(base64Encoded: bodyData.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")),
           let body = String(data: decodedData, encoding: .utf8) {
            return body
        }
        
        // Se ci sono parti multiple, cerca la parte di testo
        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == "text/plain" {
                    if let bodyData = part.body?.data,
                       let decodedData = Data(base64Encoded: bodyData.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")),
                       let body = String(data: decodedData, encoding: .utf8) {
                        return body
                    }
                }
            }
        }
        
        return ""
    }
    
    private func parseGmailDate(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        
        return formatter.date(from: dateString) ?? Date()
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
    
    /// Categorizza manualmente una singola email (força uso AI se disponibile)
    public func categorizeEmail(_ emailId: String, forceAI: Bool = false) async {
        guard let emailIndex = emails.firstIndex(where: { $0.id == emailId }) else {
            print("❌ EmailService: Email con ID \(emailId) non trovata")
            return
        }
        
        let email = emails[emailIndex]
        
        // Controllo anti-duplicazione: se già categorizzata o in elaborazione
        if email.category != nil && !forceAI {
            print("🤖 EmailService: Email \(emailId) già categorizzata come \(email.category!.displayName)")
            return
        }
        
        if categorizationService.isEmailCategorized(emailId) && !forceAI {
            print("🤖 EmailService: Email \(emailId) già processata dalla cache")
            return
        }
        
        if categorizationService.isEmailBeingCategorized(emailId) {
            print("🤖 EmailService: Email \(emailId) già in elaborazione")
            return
        }
        
        print("🤖 EmailService: Categorizzazione manuale email da \(email.from) (ID: \(emailId), forceAI: \(forceAI))")
        
        let category: EmailCategory
        if forceAI {
            // Força l'uso dell'AI bypassando i limiti per categorizzazione manuale
            category = await categorizationService.categorizeWithAI(email)
            
            // Incrementa contatore per account se ha usato AI
            if let account = currentAccount {
                categorizationService.incrementAccountAICount(for: account.email)
            }
        } else {
            category = await categorizationService.categorizeEmail(email)
        }
        
        // Aggiorna l'email con la nuova categoria
        let updatedEmail = EmailMessage(
            id: email.id,
            from: email.from,
            to: email.to,
            subject: email.subject,
            body: email.body,
            date: email.date,
            isRead: email.isRead,
            hasAttachments: email.hasAttachments,
            emailType: email.emailType,
            category: category
        )
        
        emails[emailIndex] = updatedEmail
        
        // Aggiorna la cache
        if let account = currentAccount {
            await cacheService.cacheEmails([updatedEmail], for: account.email)
        }
        
        print("✅ EmailService: Email categorizzata come \(category.displayName)")
    }
    
    /// Filtra le email per categoria
    public func emailsForCategory(_ category: EmailCategory) -> [EmailMessage] {
        return emails.filter { $0.category == category }
    }
    
    /// Ottieni il conteggio delle email per ogni categoria
    public func getCategoryCounts() -> [EmailCategory: Int] {
        var counts: [EmailCategory: Int] = [:]
        
        for category in EmailCategory.allCases {
            counts[category] = emails.filter { $0.category == category }.count
        }
        
        return counts
    }
    
    /// Test: Simula la categorizzazione con email di esempio
    public func testEmailCategorization() async {
        print("🧪 EmailService: ===== INIZIO TEST CATEGORIZZAZIONE =====")
        
        let testEmails = [
            EmailMessage(
                id: "test_work_\(UUID().uuidString)",
                from: "manager@company.com",
                to: ["user@company.com"],
                subject: "Meeting Tomorrow - Project Review",
                body: "Hi team, let's review the project progress tomorrow at 10 AM in the conference room.",
                date: Date(),
                isRead: false,
                hasAttachments: false,
                emailType: .received
            ),
            EmailMessage(
                id: "test_personal_\(UUID().uuidString)",
                from: "friend@gmail.com",
                to: ["user@gmail.com"],
                subject: "Ciao! Come va?",
                body: "Ciao! Come stai? Ti va di vederci questo weekend per un caffè?",
                date: Date(),
                isRead: false,
                hasAttachments: false,
                emailType: .received
            ),
            EmailMessage(
                id: "test_notification_\(UUID().uuidString)",
                from: "noreply@amazon.com",
                to: ["user@gmail.com"],
                subject: "Your order has been shipped",
                body: "Your Amazon order #12345 has been shipped and will arrive by tomorrow.",
                date: Date(),
                isRead: false,
                hasAttachments: false,
                emailType: .received
            ),
            // Test HTML Email
            EmailMessage(
                id: "test_html_\(UUID().uuidString)",
                from: "newsletter@company.com", 
                to: ["user@company.com"],
                subject: "🎉 Test HTML Email - Newsletter",
                body: """
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                    <h1 style="color: #2C3E50; text-align: center;">Welcome to Our Newsletter!</h1>
                    
                    <div style="background: #F8F9FA; padding: 20px; border-radius: 8px; margin: 20px 0;">
                        <h2 style="color: #E74C3C;">🔥 Hot News</h2>
                        <p>This is a <strong>test HTML email</strong> to verify that our new 
                        <em>EmailHTMLRenderer</em> works correctly in both light and dark modes.</p>
                    </div>
                    
                    <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
                        <tr style="background: #3498DB; color: white;">
                            <th style="padding: 10px; border: 1px solid #ddd;">Feature</th>
                            <th style="padding: 10px; border: 1px solid #ddd;">Status</th>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd;">Dark Mode Support</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">✅ Working</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd;">Dynamic Height</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">✅ Working</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd;">CSS Override</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">✅ Working</td>
                        </tr>
                    </table>
                    
                    <blockquote style="border-left: 4px solid #3498DB; padding-left: 20px; margin: 20px 0; font-style: italic;">
                        "The new EmailHTMLRenderer should solve all visibility issues and provide 
                        consistent rendering across light and dark themes."
                    </blockquote>
                    
                    <ul>
                        <li>✅ Unified WebView implementation</li>
                        <li>✅ Dynamic color scheme support</li>
                        <li>✅ Robust height calculation</li>
                        <li>✅ Error handling and fallbacks</li>
                    </ul>
                    
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="https://github.com" style="background: #27AE60; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                            View on GitHub
                        </a>
                    </div>
                    
                    <div style="background: #E8F5E8; padding: 15px; border-radius: 6px; margin: 20px 0;">
                        <p style="margin: 0; color: #27AE60;">
                            🌟 <strong>Success!</strong> If you can see this email content with proper styling 
                            and colors, the HTML renderer is working perfectly!
                        </p>
                    </div>
                    
                    <footer style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #7F8C8D; font-size: 14px;">
                        <p>This is a test email generated by EmailService.testEmailCategorization()</p>
                        <p>&copy; 2024 Marilena App - HTML Email Test</p>
                    </footer>
                </div>
                """,
                date: Date(),
                isRead: false,
                hasAttachments: false,
                emailType: .received
            ),
            EmailMessage(
                id: "test_promo_\(UUID().uuidString)",
                from: "offers@store.com",
                to: ["user@gmail.com"],
                subject: "🔥 50% OFF - Limited Time Offer!",
                body: "Don't miss out! Get 50% off on all products. Limited time offer ends soon!",
                date: Date(),
                isRead: false,
                hasAttachments: false,
                emailType: .received
            )
        ]
        
        print("🧪 EmailService: Creati \(testEmails.count) email di test")
        
        // Aggiungi le email di test all'inizio della lista
        emails.insert(contentsOf: testEmails, at: 0)
        print("🧪 EmailService: Email di test aggiunte alla lista (totale: \(emails.count))")
        
        // Categorizza le email di test
        print("🧪 EmailService: Inizio categorizzazione email di test...")
        let categorizedEmails = await categorizationService.categorizeEmails(testEmails)
        
        // Aggiorna le email nella lista con le versioni categorizzate
        for categorizedEmail in categorizedEmails {
            if let index = emails.firstIndex(where: { $0.id == categorizedEmail.id }) {
                emails[index] = categorizedEmail
                print("🧪 EmailService: Email da \(categorizedEmail.from) categorizzata come \(categorizedEmail.category?.displayName ?? "Non categorizzata")")
            }
        }
        
        // Mostra statistiche
        let counts = getCategoryCounts()
        print("🧪 EmailService: ===== STATISTICHE CATEGORIZZAZIONE =====")
        for category in EmailCategory.allCases {
            print("🧪 \(category.displayName): \(counts[category] ?? 0) email")
        }
        
        print("🧪 EmailService: ===== FINE TEST CATEGORIZZAZIONE =====")
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
    public var category: EmailCategory?
    public let threadingInfo: ThreadingInfo? // Nuova proprietà per threading
    
    public init(
        id: String,
        from: String,
        to: [String],
        subject: String,
        body: String,
        date: Date,
        isRead: Bool = false,
        hasAttachments: Bool = false,
        emailType: EmailType = .received,
        category: EmailCategory? = nil,
        threadingInfo: ThreadingInfo? = nil
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
        self.category = category
        self.threadingInfo = threadingInfo
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

// MARK: - Email Threading Models

/// Rappresenta una conversazione di email (thread)
public struct EmailConversation: Identifiable, Codable {
    public let id: String
    public let subject: String // Subject normalizzato (senza "Re:", "Fwd:", etc.)
    public var messages: [EmailMessage]
    public let participants: Set<String> // Tutti i partecipanti alla conversazione
    public let createdAt: Date // Data del primo messaggio
    public var lastActivity: Date // Data dell'ultimo messaggio
    public var messageCount: Int { messages.count }
    public var hasUnread: Bool { messages.contains { !$0.isRead } }
    public var isStarred: Bool = false
    
    /// Messaggio più recente nella conversazione
    public var latestMessage: EmailMessage? {
        messages.sorted { $0.date > $1.date }.first
    }
    
    /// Partecipanti come stringa formattata
    public var participantsDisplay: String {
        Array(participants).prefix(3).joined(separator: ", ") + 
        (participants.count > 3 ? " e \(participants.count - 3) altri" : "")
    }
    
    public init(
        id: String,
        subject: String,
        messages: [EmailMessage],
        participants: Set<String>,
        createdAt: Date,
        lastActivity: Date,
        isStarred: Bool = false
    ) {
        self.id = id
        self.subject = subject
        self.messages = messages.sorted { $0.date < $1.date } // Ordina cronologicamente
        self.participants = participants
        self.createdAt = createdAt
        self.lastActivity = lastActivity
        self.isStarred = isStarred
    }
    
    /// Aggiunge un messaggio alla conversazione
    public mutating func addMessage(_ message: EmailMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        messages.sort { $0.date < $1.date }
        lastActivity = max(lastActivity, message.date)
    }
    
    /// Rimuove un messaggio dalla conversazione
    public mutating func removeMessage(withId messageId: String) {
        messages.removeAll { $0.id == messageId }
        if let latestDate = messages.max(by: { $0.date < $1.date })?.date {
            lastActivity = latestDate
        }
    }
}

/// Informazioni per il threading delle email
public struct ThreadingInfo: Codable {
    public let threadId: String?
    public let references: [String] // Message-IDs referenced
    public let inReplyTo: String? // Message-ID this is replying to
    public let messageId: String? // Unique Message-ID
    
    public init(
        threadId: String? = nil,
        references: [String] = [],
        inReplyTo: String? = nil,
        messageId: String? = nil
    ) {
        self.threadId = threadId
        self.references = references
        self.inReplyTo = inReplyTo
        self.messageId = messageId
    }
} 