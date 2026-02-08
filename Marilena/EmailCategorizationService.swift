import Foundation

/// Servizio per la categorizzazione automatica delle email tramite modelli AI configurabili
@MainActor
public class EmailCategorizationService {

    // MARK: - Properties

    private let openAIService = OpenAIService.shared
    private let appleService = AppleIntelligenceService.shared
    private let groqService = GroqService.shared
    private let anthropicService = AnthropicService.shared
    private let deepSeekService = DeepSeekService()

    // Modello e provider configurabili
    private var selectedModel: AIModelConfiguration {
        getSelectedModel()
    }
    private var selectedProvider: AIModelProvider {
        selectedModel.provider
    }
    
    // MARK: - Configuration
    
    /// Configurazione dinamica per il sistema ibrido (lazy per evitare deadlock)
    private lazy var configManager = EmailCategorizationConfigManager.shared
    
    /// Configurazione corrente (shortcut)
    private var config: EmailCategorizationConfig {
        return configManager.currentConfig
    }
    
    /// Monitor delle performance (opzionale)
    private weak var monitor: EmailCategorizationMonitor?

    // Set per tracciare le email in elaborazione (evita duplicati)
    private var emailsBeingCategorized = Set<String>()

    // MARK: - Model Selection Methods

    /// Ottiene il modello selezionato per la categorizzazione email
    private func getSelectedModel() -> AIModelConfiguration {
        // Prima cerca nelle preferenze utente
        if let savedModelId = UserDefaults.standard.string(forKey: "emailCategorizationModel") {
            if let model = AIModelConfiguration.allModels.first(where: { $0.id == savedModelId }) {
                return model
            }
        }

        // Fallback: modelli economici raccomandati per email
        let recommendedModels = AIModelConfiguration.emailRecommended.filter { model in
            // Priorità ai modelli economici e veloci
            model.pricing.inputTokens.price < 1.0 && // Meno di $1 per 1M tokens
            model.contextWindow >= 32000 && // Contesto sufficiente per email
            model.capabilities.contains(.reasoning)
        }

        // Ordina per prezzo (più economico prima) e performance
        let sortedModels = recommendedModels.sorted { (model1, model2) -> Bool in
            let price1 = model1.pricing.inputTokens.price
            let price2 = model2.pricing.inputTokens.price
            if price1 != price2 {
                return price1 < price2 // Più economico vince
            }
            // Se stesso prezzo, preferisci performance più alta
            return (model1.benchmarks.overallScore ?? 0) > (model2.benchmarks.overallScore ?? 0)
        }

        let appleDefaultId = "foundation-medium"

        // Default: Apple Foundation Medium (on-device, privacy-first)
        // Fallback chain sicuro che evita crash se l'array è vuoto
        if let model = sortedModels.first(where: { $0.id == appleDefaultId }) {
            return model
        }
        if let model = sortedModels.first(where: { $0.provider == .apple }) {
            return model
        }
        if let model = sortedModels.first {
            return model
        }
        if let model = AIModelConfiguration.allModels.first(where: { $0.id == appleDefaultId }) {
            return model
        }
        if let model = AIModelConfiguration.allModels.first {
            return model
        }
        
        // Ultimo fallback: crea un modello minimale compatibile con il catalogo corrente
        print("⚠️ EmailCategorizationService: Nessun modello disponibile, uso fallback sicuro")
        return AIModelConfiguration(
            id: "fallback-model",
            name: "Fallback Model",
            provider: .openai,
            version: "1.0",
            releaseDate: Date(timeIntervalSince1970: 0),
            description: "Fallback model for email categorization when catalog is unavailable",
            contextWindow: 4096,
            maxOutputTokens: 1024,
            supportedModalities: [.text],
            capabilities: [.reasoning, .analysis],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0),
                outputTokens: PricingTier(price: 0)
            ),
            benchmarks: AIBenchmarks(),
            availability: AIAvailability(
                regions: ["global"],
                accessTiers: [.api],
                status: .available
            ),
            isExperimental: false,
            requiresSpecialAccess: false,
            tags: ["fallback", "email-categorization"]
        )
    }

    /// Salva il modello selezionato per la categorizzazione email
    public func setSelectedModel(_ model: AIModelConfiguration) {
        UserDefaults.standard.set(model.id, forKey: "emailCategorizationModel")
        UserDefaults.standard.synchronize()
        print("🤖 EmailCategorizationService: Modello selezionato: \(model.name) (\(model.provider.displayName))")
    }

    /// Ottiene tutti i modelli disponibili per la categorizzazione email
    public func getAvailableModels() -> [AIModelConfiguration] {
        AIModelConfiguration.allModels.filter { model in
            model.capabilities.contains(.reasoning) &&
            !model.isExperimental &&
            model.availability.status == .available
        }.sorted { (model1, model2) -> Bool in
            // Prima economici, poi per performance
            let price1 = model1.pricing.inputTokens.price
            let price2 = model2.pricing.inputTokens.price
            if price1 != price2 {
                return price1 < price2
            }
            return (model1.benchmarks.overallScore ?? 0) > (model2.benchmarks.overallScore ?? 0)
        }
    }
    
    // Set per tracciare le email già categorizzate completamente
    private var categorizedEmailIds = Set<String>()
    
    // Chiavi per salvare lo stato di categorizzazione in UserDefaults
    private let categorizedEmailsKey = "categorized_email_ids"
    private let aiCategorizedCountKey = "ai_categorized_count_"
    private let sessionAICountKey = "session_ai_count"
    
    // Contatori per limiti AI
    private var sessionAICount = 0
    private var accountAICounts: [String: Int] = [:]
    
    // MARK: - Initialization
    
    public init() {
        // Ripristina lo stato delle email categorizzate da UserDefaults
        loadCategorizedEmailsFromStorage()
        loadAICountsFromStorage()
    }
    
    // MARK: - Public Methods
    
    /// Categorizza una singola email utilizzando OpenAI
    public func categorizeEmail(_ email: EmailMessage) async -> EmailCategory {
        // Controllo anti-duplicazione: se già categorizzata o in elaborazione
        if categorizedEmailIds.contains(email.id) {
            print("📧 EmailCategorizationService: Email \(email.id) già categorizzata, skip")
            return email.category ?? .notifications
        }
        
        if emailsBeingCategorized.contains(email.id) {
            print("📧 EmailCategorizationService: Email \(email.id) già in elaborazione, skip")
            return email.category ?? .notifications
        }
        
        // Se l'email ha già una categoria, non ricategorizzare
        if let existingCategory = email.category {
            print("📧 EmailCategorizationService: Email \(email.id) ha già categoria \(existingCategory.displayName)")
            categorizedEmailIds.insert(email.id)
            return existingCategory
        }
        
        // Segna come in elaborazione
        emailsBeingCategorized.insert(email.id)
        print("📧 EmailCategorizationService: Categorizzazione email da \(email.from) (ID: \(email.id))")
        
        // Determina il metodo di categorizzazione (AI vs tradizionale)
        let shouldUseAI = shouldUseAICategorization(for: email)
        
        defer {
            // Rimuovi dall'elaborazione al termine
            emailsBeingCategorized.remove(email.id)
        }
        
        if shouldUseAI {
            return await categorizeWithAI(email)
        } else {
            return categorizeWithTraditionalMethods(email)
        }
    }
    
    /// Categorizza un array di email in batch con strategia ibrida intelligente
    public func categorizeEmails(_ emails: [EmailMessage]) async -> [EmailMessage] {
        // Filtra le email che non sono già categorizzate o in elaborazione
        let uncategorizedEmails = emails.filter { email in
            // Skip se già categorizzata o in elaborazione
            !categorizedEmailIds.contains(email.id) && 
            !emailsBeingCategorized.contains(email.id) &&
            email.category == nil
        }
        
        print("📧 EmailCategorizationService: Categorizzazione intelligente di \(uncategorizedEmails.count)/\(emails.count) email")
        
        var categorizedEmails: [EmailMessage] = []
        
        // Aggiungi le email già categorizzate senza riprocessarle
        for email in emails {
            if email.category != nil || categorizedEmailIds.contains(email.id) {
                categorizedEmails.append(email)
            }
        }
        
        // Se non ci sono email da categorizzare, ritorna subito
        guard !uncategorizedEmails.isEmpty else {
            print("✅ EmailCategorizationService: Tutte le email sono già categorizzate")
            return categorizedEmails
        }
        
        // STRATEGIA IBRIDA: Separa email per metodo di categorizzazione
        let emailsForAI = uncategorizedEmails.filter { shouldUseAICategorization(for: $0) }
        let emailsForTraditional = uncategorizedEmails.filter { !shouldUseAICategorization(for: $0) }
        
        print("🤖 EmailCategorizationService: AI per \(emailsForAI.count) email, Tradizionale per \(emailsForTraditional.count) email")
        
        // 1. CATEGORIZZAZIONE TRADIZIONALE (istantanea)
        for email in emailsForTraditional {
            let category = categorizeWithTraditionalMethods(email)
            let categorizedEmail = EmailMessage(
                id: email.id,
                accountId: email.accountId,
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
            categorizedEmails.append(categorizedEmail)
        }
        
        // 2. CATEGORIZZAZIONE AI (con batch rate limiting)
        if !emailsForAI.isEmpty {
            let aiBatchSize = config.aiBatchSize
            let aiBatches = emailsForAI.chunked(into: aiBatchSize)
            
            for (index, batch) in aiBatches.enumerated() {
                print("🤖 EmailCategorizationService: Processando batch AI \(index + 1)/\(aiBatches.count)")
                
                // Processa il batch AI corrente
                let batchResults = await withTaskGroup(of: EmailMessage.self) { group in
                    // Limita a max 3 task simultanei per evitare sovraccarico
                    let maxConcurrentTasks = min(batch.count, 3)

                    for i in 0..<maxConcurrentTasks {
                        let email = batch[i]
                        group.addTask {
                            let category = await self.categorizeWithAI(email)
                            return await MainActor.run {
                                EmailMessage(
                                    id: email.id,
                                    accountId: email.accountId,
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
                            }
                        }
                    }

                    // Processa gli altri email in sequenza dopo i primi 3
                    var results: [EmailMessage] = []
                    for await result in group {
                        results.append(result)
                    }

                    // Processa gli email rimanenti sequenzialmente
                    for i in maxConcurrentTasks..<batch.count {
                        let email = batch[i]
                        let category = await self.categorizeWithAI(email)
                        let result = await MainActor.run {
                            EmailMessage(
                                id: email.id,
                                accountId: email.accountId,
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
                        }
                        results.append(result)
                    }

                    return results
                }
                
                categorizedEmails.append(contentsOf: batchResults)
                
                // Pausa configurabile per AI (rispetto rate limit)
                if index < aiBatches.count - 1 {
                    let delayNanoseconds = UInt64(config.aiBatchDelay * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNanoseconds)
                }
            }
        }
        
        print("✅ EmailCategorizationService: Categorizzazione completata per \(categorizedEmails.count) email")
        return categorizedEmails
    }
    
    // MARK: - Private Methods
    
    /// Crea il prompt system per guidare la categorizzazione
    private func getSystemPrompt() -> String {
        return """
        Sei un esperto AI nella categorizzazione automatica delle email italiane. Analizza con precisione mittente, oggetto e contenuto per classificare correttamente.

        CATEGORIE DISPONIBILI:

        🔷 LAVORO
        • Email aziendali/professionali da colleghi, capi, clienti
        • Riunioni, progetti, deadlines, documenti lavorativi
        • Comunicazioni HR, buste paga, benefit aziendali
        • Fornitori, partner commerciali, fatture B2B
        • Domini: @azienda.it, @company.com, indirizzi corporate
        • Parole chiave: riunione, progetto, cliente, fattura, contratto, deadline, scadenza

        👤 PERSONALE  
        • Email da amici, familiari, parenti
        • Comunicazioni personali, sociali, private
        • Inviti eventi privati, compleanni, cene
        • Comunicazioni mediche/sanitarie personali
        • Domini: @gmail.com, @yahoo.it, @libero.it (da persone)
        • Parole chiave: ciao, famiglia, amico, festa, compleanno, vacanza

        🔔 NOTIFICHE
        • Newsletter, aggiornamenti automatici servizi
        • Conferme ordini, spedizioni, prenotazioni
        • Notifiche social network, app, piattaforme
        • Estratti conto, comunicazioni bancarie automatiche
        • Aggiornamenti software, sicurezza, policy
        • Domini: noreply@, no-reply@, automated@, notifiche@
        • Parole chiave: conferma, aggiornamento, newsletter, notifica, estratto

        📢 PROMO
        • Email marketing, pubblicità, promozioni commerciali
        • Offerte, sconti, deals, coupon
        • Spam, phishing, truffe
        • Email commerciali non richieste
        • Link sospetti, richieste dati sensibili
        • Parole chiave: offerta, sconto, gratis, promozione, limited time, click here

        REGOLE DI PRIORITÀ:
        1. Domini aziendali conosciuti → LAVORO
        2. Mittenti noreply/automated → NOTIFICHE  
        3. Parole marketing/vendita → PROMO
        4. Nomi persone + domini consumer → PERSONALE
        5. In caso di dubbio → NOTIFICHE

        ANALISI RICHIESTA:
        • Dominio del mittente (priorità alta)
        • Parole chiave nell'oggetto (priorità alta)  
        • Contesto del contenuto (priorità media)
        • Pattern spam/marketing (priorità alta)

        RISPOSTA: Rispondi ESCLUSIVAMENTE con una sola parola: LAVORO, PERSONALE, NOTIFICHE, o PROMO
        """
    }
    
    /// Crea il prompt per categorizzare una specifica email
    private func createCategorizationPrompt(from: String, subject: String, preview: String) -> String {
        // Analizza il dominio del mittente per dare più contesto
        let domain = extractDomain(from: from)
        let domainType = analyzeDomainType(domain: domain)
        
        return """
        ANALISI EMAIL:
        
        📧 MITTENTE: \(from)
        🏢 DOMINIO: \(domain) (\(domainType))
        📝 OGGETTO: \(subject)
        📄 CONTENUTO: \(preview)
        
        Istruzioni:
        1. Analizza il dominio del mittente come indicatore primario
        2. Cerca parole chiave specifiche nell'oggetto
        3. Valuta il tono e contenuto dell'anteprima
        4. Applica le regole di priorità definite
        5. Considera il contesto italiano
        
        CATEGORIA:
        """
    }
    
    /// Estrae un'anteprima pulita del contenuto dell'email (primi 250 caratteri)
    private func getEmailPreview(_ body: String) -> String {
        var cleanBody = body
        
        // Rimuovi tag HTML
        cleanBody = cleanBody.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Rimuovi entità HTML comuni
        cleanBody = cleanBody.replacingOccurrences(of: "&nbsp;", with: " ")
        cleanBody = cleanBody.replacingOccurrences(of: "&amp;", with: "&")
        cleanBody = cleanBody.replacingOccurrences(of: "&lt;", with: "<")
        cleanBody = cleanBody.replacingOccurrences(of: "&gt;", with: ">")
        cleanBody = cleanBody.replacingOccurrences(of: "&quot;", with: "\"")
        cleanBody = cleanBody.replacingOccurrences(of: "&#[0-9]+;", with: "", options: .regularExpression)
        
        // Rimuovi URL per ridurre rumore
        cleanBody = cleanBody.replacingOccurrences(of: "https?://[^\\s]+", with: "[URL]", options: .regularExpression)
        
        // Rimuovi eccesso di spazi e newline
        cleanBody = cleanBody.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleanBody = cleanBody.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limita a 250 caratteri per GPT-4.1 nano
        let preview = String(cleanBody.prefix(250))
        
        return preview.isEmpty ? "[contenuto vuoto]" : preview
    }
    
    /// Estrae il dominio dall'indirizzo email
    private func extractDomain(from email: String) -> String {
        if let atIndex = email.lastIndex(of: "@") {
            let domain = String(email[email.index(after: atIndex)...])
            return domain.lowercased()
        }
        return email.lowercased()
    }
    
    /// Analizza il tipo di dominio per fornire contesto
    private func analyzeDomainType(domain: String) -> String {
        // Domini aziendali/corporate comuni
        let corporateDomains = [
            ".com", ".it", ".eu", ".org", ".net", ".biz", 
            "company.com", "azienda.it", "srl.it", "spa.it"
        ]
        
        // Domini consumer/personali
        let consumerDomains = [
            "gmail.com", "yahoo.it", "yahoo.com", "libero.it", 
            "hotmail.com", "outlook.com", "icloud.com", "alice.it",
            "virgilio.it", "tin.it", "fastwebnet.it", "tiscali.it"
        ]
        
        // Domini automatici/notifiche
        let automatedPatterns = [
            "noreply", "no-reply", "automated", "notifiche", "notifications",
            "info", "support", "help", "admin", "system"
        ]
        
        // Controlla pattern automatici prima
        for pattern in automatedPatterns {
            if domain.contains(pattern) {
                return "automatico"
            }
        }
        
        // Controlla domini consumer
        for consumer in consumerDomains {
            if domain.contains(consumer) {
                return "personale"
            }
        }
        
        // Controlla domini corporate
        for corporate in corporateDomains {
            if domain.contains(corporate) {
                return "aziendale"
            }
        }
        
        return "sconosciuto"
    }
    
    /// Converte la risposta di OpenAI in una categoria con parsing robusto
    private func parseCategory(from response: String) -> EmailCategory {
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Rimuovi punteggiatura e caratteri extra
        let sanitized = cleanResponse.replacingOccurrences(of: "[^A-Z]", with: "", options: .regularExpression)
        
        // Mapping prioritizzato per parole chiave
        let categoryMappings: [(keywords: [String], category: EmailCategory)] = [
            // LAVORO - alta priorità
            (["LAVORO", "WORK", "BUSINESS", "PROFESSIONAL", "AZIENDALE", "UFFICIO"], .work),
            
            // PROMO - alta priorità (prima di notifiche per evitare false positive)
            (["PROMO", "PROMOTIONAL", "MARKETING", "SPAM", "PUBBLICITA", "OFFERTA", "COMMERCIALE"], .promotional),
            
            // PERSONALE - media priorità
            (["PERSONALE", "PERSONAL", "PRIVATO", "PRIVATE", "FAMIGLIA", "AMICI"], .personal),
            
            // NOTIFICHE - bassa priorità (catch-all)
            (["NOTIFICHE", "NOTIFICATIONS", "NOTIFICA", "AUTOMATED", "AUTOMATICO", "SISTEMA"], .notifications)
        ]
        
        // Cerca corrispondenze esatte prima
        for mapping in categoryMappings {
            for keyword in mapping.keywords {
                if sanitized == keyword {
                    print("🎯 EmailCategorizationService: Match esatto '\(keyword)' → \(mapping.category.displayName)")
                    return mapping.category
                }
            }
        }
        
        // Cerca corrispondenze parziali con priorità
        for mapping in categoryMappings {
            for keyword in mapping.keywords {
                if cleanResponse.contains(keyword) {
                    print("🎯 EmailCategorizationService: Match parziale '\(keyword)' → \(mapping.category.displayName)")
                    return mapping.category
                }
            }
        }
        
        // Fallback intelligente in base alla lunghezza della risposta
        if cleanResponse.count > 50 {
            // Risposta lunga potrebbe essere spam/promo
            print("⚠️ EmailCategorizationService: Risposta lunga → PROMO (fallback)")
            return .promotional
        }
        
        // Default conservativo
        print("⚠️ EmailCategorizationService: Risposta non riconosciuta '\(cleanResponse)' → NOTIFICHE (default)")
        return .notifications
    }
    
    // MARK: - Public Management Methods
    
    /// Resetta la cache di categorizzazione (utile per testing o reset)
    public func resetCategorizationCache() {
        emailsBeingCategorized.removeAll()
        categorizedEmailIds.removeAll()
        saveCategorizedEmailsToStorage()
        print("🔄 EmailCategorizationService: Cache categorizzazione resettata")
    }
    
    /// Marca un'email come già categorizzata (per sincronizzazione con cache)
    public func markEmailAsCategorized(_ emailId: String) {
        categorizedEmailIds.insert(emailId)
        saveCategorizedEmailsToStorage()
    }
    
    /// Verifica se un'email è già stata categorizzata
    public func isEmailCategorized(_ emailId: String) -> Bool {
        return categorizedEmailIds.contains(emailId)
    }
    
    /// Verifica se un'email è attualmente in elaborazione
    public func isEmailBeingCategorized(_ emailId: String) -> Bool {
        return emailsBeingCategorized.contains(emailId)
    }
    
    // MARK: - Private Storage Methods
    
    /// Carica lo stato delle email categorizzate da UserDefaults
    private func loadCategorizedEmailsFromStorage() {
        if let data = UserDefaults.standard.data(forKey: categorizedEmailsKey),
           let emailIds = try? JSONDecoder().decode(Set<String>.self, from: data) {
            categorizedEmailIds = emailIds
            print("📧 EmailCategorizationService: Caricate \(emailIds.count) email già categorizzate dalla cache")
        }
    }
    
    /// Salva lo stato delle email categorizzate in UserDefaults
    private func saveCategorizedEmailsToStorage() {
        if let data = try? JSONEncoder().encode(categorizedEmailIds) {
            UserDefaults.standard.set(data, forKey: categorizedEmailsKey)
            print("💾 EmailCategorizationService: Salvate \(categorizedEmailIds.count) email categorizzate nella cache")
        }
    }
    
    /// Sincronizza con la cache delle email (chiamato quando si caricano email dalla cache)
    public func syncWithEmailCache(_ emails: [EmailMessage]) {
        var needsSync = false
        
        for email in emails {
            if email.category != nil, !categorizedEmailIds.contains(email.id) {
                categorizedEmailIds.insert(email.id)
                needsSync = true
            }
        }
        
        if needsSync {
            saveCategorizedEmailsToStorage()
            print("🔄 EmailCategorizationService: Sincronizzate \(categorizedEmailIds.count) email con cache")
        }
    }
    
    // MARK: - Categorization Strategy Methods
    
    /// Determina se usare AI o metodi tradizionali per la categorizzazione
    private func shouldUseAICategorization(for email: EmailMessage, accountId: String? = nil) -> Bool {
        // 1. Controlla limiti sessione
        if sessionAICount >= config.maxAICategorizationPerSession {
            print("📧 EmailCategorizationService: Limite sessione AI raggiunto (\(sessionAICount)/\(config.maxAICategorizationPerSession))")
            return false
        }
        
        // 2. Controlla limiti per account
        if let accountId = accountId {
            let accountCount = accountAICounts[accountId] ?? 0
            if accountCount >= config.maxAICategorizationPerAccount {
                print("📧 EmailCategorizationService: Limite account AI raggiunto per \(accountId) (\(accountCount)/\(config.maxAICategorizationPerAccount))")
                return false
            }
        }
        
        // 3. Priorità per email recenti
        let daysSinceEmail = Calendar.current.dateComponents([.day], from: email.date, to: Date()).day ?? 0
        if daysSinceEmail <= config.recentEmailDaysThreshold {
            print("📧 EmailCategorizationService: Email recente (\(daysSinceEmail) giorni) - usa AI")
            return true
        }
        
        // 4. Priorità per mittenti importanti o sconosciuti
        if isHighPriorityEmail(email) {
            print("📧 EmailCategorizationService: Email alta priorità - usa AI")
            return true
        }
        
        // 5. Se metodi tradizionali non sono sicuri, usa AI
        let traditionalConfidence = getTraditionalCategorizationConfidence(email)
        if traditionalConfidence < config.traditionalConfidenceThreshold {
            print("📧 EmailCategorizationService: Confidence tradizionale bassa (\(traditionalConfidence)) - usa AI")
            return true
        }
        
        print("📧 EmailCategorizationService: Usa metodi tradizionali per \(email.from)")
        return false
    }
    
    /// Categorizza un'email usando AI (multi-provider) - Può essere chiamata pubblicamente per uso forzato
    public func categorizeWithAI(_ email: EmailMessage) async -> EmailCategory {
        print("🤖 EmailCategorizationService: Categorizzazione AI per \(email.from) usando \(selectedModel.name) (\(selectedProvider.displayName))")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Incrementa contatori
        sessionAICount += 1

        // Crea il prompt per la categorizzazione
        let prompt = createCategorizationPrompt(
            from: email.from,
            subject: email.subject,
            preview: getEmailPreview(email.body)
        )

        // Timeout di 30 secondi per evitare blocchi
        let timeoutTask = Task<String, Error> {
            try await Task.sleep(nanoseconds: 30_000_000_000) // 30 secondi
            throw NSError(domain: "AICategorizationTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout categorizzazione AI"])
        }

        let categorizationTask = Task<String, Error> {
            // Scegli il servizio appropriato in base al provider
            let response = try await sendAIMessage(systemPrompt: getSystemPrompt(), userPrompt: prompt)
            return response
        }

        // Scegli il servizio appropriato in base al provider
        do {
            // Aspetta il primo che completa (categorizzazione o timeout)
            let response = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await categorizationTask.value
                }
                group.addTask {
                    try await timeoutTask.value
                }

                // Prendi il primo risultato disponibile
                guard let result = try await group.next() else {
                    throw NSError(domain: "NoResultError", code: -1, userInfo: nil)
                }
                group.cancelAll() // Cancella gli altri task
                return result
            }
            let category = self.parseCategory(from: response)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("✅ EmailCategorizationService: Email \(email.id) categorizzata AI come \(category.displayName) in \(String(format: "%.2f", duration))s usando \(selectedModel.name)")

            // Registra nel monitor
            self.monitor?.recordAICategorization(duration: duration, category: category)

            // Segna come completamente categorizzata
            self.categorizedEmailIds.insert(email.id)
            self.saveCategorizedEmailsToStorage()
            self.saveAICountsToStorage()
            return category

        } catch {
            // Cancella i task pendenti
            timeoutTask.cancel()
            categorizationTask.cancel()

            print("❌ EmailCategorizationService: Errore AI - \(error.localizedDescription) con modello \(selectedModel.name)")
            // Fallback ai metodi tradizionali
            let fallbackCategory = self.categorizeWithTraditionalMethods(email)
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            // Registra fallback come categorizzazione tradizionale
            let confidence = self.getTraditionalCategorizationConfidence(email)
            self.monitor?.recordTraditionalCategorization(duration: duration, category: fallbackCategory, confidence: confidence)

            return fallbackCategory
        }
    }

    /// Invia messaggio AI al provider selezionato
    private func sendAIMessage(systemPrompt: String, userPrompt: String) async throws -> String {
        switch selectedProvider {
        case .apple:
            return try await sendAppleMessage(systemPrompt: systemPrompt, userPrompt: userPrompt)
        case .openai:
            return try await sendOpenAIMessage(systemPrompt: systemPrompt, userPrompt: userPrompt)
        case .openrouter:
            return try await sendOpenRouterMessage(systemPrompt: systemPrompt, userPrompt: userPrompt)

        case .groq:
            return try await sendGroqMessage(systemPrompt: systemPrompt, userPrompt: userPrompt)

        case .anthropic:
            return try await sendAnthropicMessage(systemPrompt: systemPrompt, userPrompt: userPrompt)

        case .deepseek:
            return try await sendDeepSeekMessage(systemPrompt: systemPrompt, userPrompt: userPrompt)

        default:
            // Fallback a OpenAI per provider non supportati
            print("⚠️ EmailCategorizationService: Provider \(selectedProvider.displayName) non supportato, uso fallback OpenAI")
            return try await sendOpenAIMessage(systemPrompt: systemPrompt, userPrompt: userPrompt)
        }
    }

    /// Invia messaggio a OpenAI
    private func sendOpenAIMessage(systemPrompt: String, userPrompt: String) async throws -> String {
        let aiMessages = [
            AIMessage(role: "system", content: systemPrompt),
            AIMessage(role: "user", content: userPrompt)
        ]

        if let streamingClient = AIProviderManager.shared.streamingClient(for: .openai),
           UserDefaults.standard.bool(forKey: "use_responses_api") {
            let request = AIStreamingRequest(
                messages: aiMessages,
                model: selectedModel.id,
                maxTokens: selectedModel.maxOutputTokens,
                temperature: 0.2,
                provider: .openai
            )
            let completion = try await streamingClient.complete(for: request)
            return completion.text
        }

        let legacyMessages = aiMessages.map { OpenAIMessage(role: $0.role, content: $0.content) }
        return try await withCheckedThrowingContinuation { continuation in
            openAIService.sendMessage(messages: legacyMessages, model: selectedModel.id) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Invia messaggio a OpenRouter (compatibile OpenAI)
    private func sendOpenRouterMessage(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey = KeychainManager.shared.getAPIKey(for: "openrouter"),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "OpenRouterMissingKey",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "API key OpenRouter non configurata"]
            )
        }

        struct OpenRouterRequest: Codable {
            let model: String
            let messages: [OpenAIMessage]
            let max_tokens: Int
            let temperature: Double
        }

        struct OpenRouterResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://marilena.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Marilena", forHTTPHeaderField: "X-Title")

        let payload = OpenRouterRequest(
            model: selectedModel.id,
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: userPrompt)
            ],
            max_tokens: min(selectedModel.maxOutputTokens, 1000),
            temperature: 0.2
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw NSError(
                domain: "OpenRouterHTTPError",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: "OpenRouter errore HTTP: \(body)"]
            )
        }

        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw NSError(
                domain: "OpenRouterEmptyResponse",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "OpenRouter ha restituito una risposta vuota"]
            )
        }
        return text
    }

    /// Invia messaggio a Groq
    private func sendGroqMessage(systemPrompt: String, userPrompt: String) async throws -> String {
        let messages = [
            OpenAIMessage(role: "system", content: systemPrompt),
            OpenAIMessage(role: "user", content: userPrompt)
        ]

        // GroqService usa async throws direttamente
        return try await groqService.sendMessage(messages: messages, model: selectedModel.id)
    }

    /// Invia messaggio ad Apple Intelligence
    private func sendAppleMessage(systemPrompt: String, userPrompt: String) async throws -> String {
        guard appleService.isAvailable else {
            throw AppleIntelligenceError.frameworkUnavailable
        }

        let messages = [
            AppleChatMessage(role: .system, content: systemPrompt),
            AppleChatMessage(role: .user, content: userPrompt)
        ]

        let maxTokens = min(1024, selectedModel.maxOutputTokens)
        let config = AppleGenerationConfiguration(
            instructions: nil,
            temperature: 0.2,
            maxOutputTokens: maxTokens
        )
        return try await appleService.sendMessage(
            messages: messages,
            model: selectedModel.id,
            configuration: config
        )
    }

    /// Invia messaggio a Anthropic
    private func sendAnthropicMessage(systemPrompt: String, userPrompt: String) async throws -> String {
        // Anthropic usa un formato diverso per i messaggi
        let content = [
            AnthropicContent(type: "text", text: systemPrompt + "\n\n" + userPrompt)
        ]
        let messages = [
            AnthropicMessage(role: "user", content: content)
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let temperature = UserDefaults.standard.double(forKey: "temperature") != 0 ? UserDefaults.standard.double(forKey: "temperature") : 0.7
            let maxTokens = Int(UserDefaults.standard.double(forKey: "max_tokens") != 0 ? UserDefaults.standard.double(forKey: "max_tokens") : 1000)
            anthropicService.sendMessage(messages: messages, model: selectedModel.id, maxTokens: min(maxTokens, 1000), temperature: temperature) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Invia messaggio a DeepSeek
    private func sendDeepSeekMessage(systemPrompt: String, userPrompt: String) async throws -> String {
        let messages = [
            OpenAIMessage(role: "system", content: systemPrompt),
            OpenAIMessage(role: "user", content: userPrompt)
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let temperature = UserDefaults.standard.double(forKey: "temperature") != 0 ? UserDefaults.standard.double(forKey: "temperature") : 0.7
            let maxTokens = Int(UserDefaults.standard.double(forKey: "max_tokens") != 0 ? UserDefaults.standard.double(forKey: "max_tokens") : 1000)
            deepSeekService.sendMessage(messages: messages, model: selectedModel.id, maxTokens: min(maxTokens, 1000), temperature: temperature) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Categorizza un'email usando metodi tradizionali (pattern matching)
    private func categorizeWithTraditionalMethods(_ email: EmailMessage) -> EmailCategory {
        print("🔧 EmailCategorizationService: Categorizzazione tradizionale per \(email.from)")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Categorizzazione basata su dominio
        if let domainCategory = categorizeByDomain(email.from) {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let confidence = 0.9 // Alta confidence per match dominio
            print("✅ EmailCategorizationService: Categorizzata per dominio: \(domainCategory.displayName) in \(String(format: "%.3f", duration))s")
            
            // Registra nel monitor
            monitor?.recordTraditionalCategorization(duration: duration, category: domainCategory, confidence: confidence)
            
            categorizedEmailIds.insert(email.id)
            saveCategorizedEmailsToStorage()
            return domainCategory
        }
        
        // 2. Categorizzazione basata su parole chiave nell'oggetto
        if let subjectCategory = categorizeBySubjectKeywords(email.subject) {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let confidence = 0.8 // Buona confidence per match oggetto
            print("✅ EmailCategorizationService: Categorizzata per oggetto: \(subjectCategory.displayName) in \(String(format: "%.3f", duration))s")
            
            // Registra nel monitor
            monitor?.recordTraditionalCategorization(duration: duration, category: subjectCategory, confidence: confidence)
            
            categorizedEmailIds.insert(email.id)
            saveCategorizedEmailsToStorage()
            return subjectCategory
        }
        
        // 3. Categorizzazione basata su pattern nel contenuto
        if let contentCategory = categorizeByContentPatterns(email.body) {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let confidence = 0.7 // Media confidence per match contenuto
            print("✅ EmailCategorizationService: Categorizzata per contenuto: \(contentCategory.displayName) in \(String(format: "%.3f", duration))s")
            
            // Registra nel monitor
            monitor?.recordTraditionalCategorization(duration: duration, category: contentCategory, confidence: confidence)
            
            categorizedEmailIds.insert(email.id)
            saveCategorizedEmailsToStorage()
            return contentCategory
        }
        
        // 4. Default: analisi mittente
        let defaultCategory = categorizeByEmailPattern(email.from)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let confidence = 0.5 // Bassa confidence per fallback
        print("✅ EmailCategorizationService: Categorizzata default: \(defaultCategory.displayName) in \(String(format: "%.3f", duration))s")
        
        // Registra nel monitor
        monitor?.recordTraditionalCategorization(duration: duration, category: defaultCategory, confidence: confidence)
        
        categorizedEmailIds.insert(email.id)
        saveCategorizedEmailsToStorage()
        return defaultCategory
    }
    
    // MARK: - Traditional Categorization Methods
    
    /// Categorizza basandosi sul dominio del mittente
    private func categorizeByDomain(_ emailAddress: String) -> EmailCategory? {
        let domain = emailAddress.components(separatedBy: "@").last?.lowercased() ?? ""
        
        // Domini business/lavoro
        let businessDomains = [
            "company.com", "corp.com", "enterprise.com", "business.com",
            "consulting.com", "llp.com", "inc.com", "ltd.com", "spa.it",
            "srl.it", "office.com", "work.com", "professional.com"
        ]
        
        // Domini notifiche/servizi
        let notificationDomains = [
            "noreply", "no-reply", "notifications", "alerts", "updates",
            "newsletter", "automated", "system", "admin", "support",
            "banking", "paypal.com", "amazon.com", "ebay.com", "stripe.com",
            "github.com", "gitlab.com", "atlassian.com", "slack.com"
        ]
        
        // Domini promozionali/marketing
        let promotionalDomains = [
            "marketing", "promo", "offers", "deals", "sales",
            "unsubscribe", "campaign", "mailchimp", "constantcontact"
        ]
        
        // Check exact domain matches
        if businessDomains.contains(domain) || domain.contains("business") || domain.contains("corp") {
            return .work
        }
        
        if notificationDomains.contains(where: { domain.contains($0) }) {
            return .notifications
        }
        
        if promotionalDomains.contains(where: { domain.contains($0) }) {
            return .promotional
        }
        
        // Domini consumer popolari (personale)
        let consumerDomains = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "icloud.com", "libero.it", "alice.it", "tin.it"]
        if consumerDomains.contains(domain) {
            return .personal
        }
        
        return nil
    }
    
    /// Categorizza basandosi su parole chiave nell'oggetto
    private func categorizeBySubjectKeywords(_ subject: String) -> EmailCategory? {
        let lowercaseSubject = subject.lowercased()
        
        // Parole chiave lavoro
        let workKeywords = [
            "meeting", "riunione", "progetto", "project", "deadline", "scadenza",
            "cliente", "client", "fattura", "invoice", "contratto", "contract",
            "business", "conferenza", "conference", "training", "formazione"
        ]
        
        // Parole chiave notifiche
        let notificationKeywords = [
            "conferma", "confirmation", "aggiornamento", "update", "notifica",
            "notification", "estratto", "statement", "ricevuta", "receipt",
            "prenotazione", "booking", "ordine", "order", "spedizione", "shipping"
        ]
        
        // Parole chiave promozionali
        let promotionalKeywords = [
            "offerta", "offer", "sconto", "discount", "sale", "promo",
            "coupon", "deal", "black friday", "cyber monday", "gratis", "free"
        ]
        
        if workKeywords.contains(where: { lowercaseSubject.contains($0) }) {
            return .work
        }
        
        if notificationKeywords.contains(where: { lowercaseSubject.contains($0) }) {
            return .notifications
        }
        
        if promotionalKeywords.contains(where: { lowercaseSubject.contains($0) }) {
            return .promotional
        }
        
        return nil
    }
    
    /// Categorizza basandosi su pattern nel contenuto
    private func categorizeByContentPatterns(_ body: String) -> EmailCategory? {
        let lowercaseBody = body.lowercased()
        
        // Pattern promozionali
        if lowercaseBody.contains("unsubscribe") || 
           lowercaseBody.contains("disiscrivi") ||
           lowercaseBody.contains("marketing") ||
           lowercaseBody.contains("pubblicità") {
            return .promotional
        }
        
        // Pattern notifiche automatiche
        if lowercaseBody.contains("questo è un messaggio automatico") ||
           lowercaseBody.contains("this is an automated message") ||
           lowercaseBody.contains("do not reply") ||
           lowercaseBody.contains("non rispondere") {
            return .notifications
        }
        
        return nil
    }
    
    /// Categorizza basandosi sul pattern dell'indirizzo email
    private func categorizeByEmailPattern(_ emailAddress: String) -> EmailCategory {
        // Se contiene numeri o caratteri strani, probabilmente è automatica
        let hasNumbers = emailAddress.rangeOfCharacter(from: .decimalDigits) != nil
        let hasNoReply = emailAddress.lowercased().contains("noreply") || 
                        emailAddress.lowercased().contains("no-reply")
        
        if hasNoReply {
            return .notifications
        }
        
        if hasNumbers && emailAddress.contains("@") {
            let domain = emailAddress.components(separatedBy: "@").last?.lowercased() ?? ""
            if !["gmail.com", "yahoo.com", "hotmail.com", "outlook.com"].contains(domain) {
                return .notifications
            }
        }
        
        // Default conservativo
        return .personal
    }
    
    /// Determina se un'email è alta priorità (merita AI)
    private func isHighPriorityEmail(_ email: EmailMessage) -> Bool {
        let lowercaseSubject = email.subject.lowercased()
        let lowercaseBody = email.body.lowercased()
        
        // Parole chiave urgenti
        let urgentKeywords = [
            "urgent", "urgente", "importante", "important", "asap",
            "immediato", "immediate", "critico", "critical", "emergency"
        ]
        
        // Check subject and body for urgent keywords
        let hasUrgentKeywords = urgentKeywords.contains { keyword in
            lowercaseSubject.contains(keyword) || lowercaseBody.contains(keyword)
        }
        
        // Domini VIP/importanti
        let vipDomains = [
            "ceo", "president", "director", "manager", "amministratore",
            "board", "executive", "partner"
        ]
        
        let hasVIPSender = vipDomains.contains { vip in
            email.from.lowercased().contains(vip)
        }
        
        // Email molto corte spesso sono personali/importanti
        let isShortEmail = email.body.count < 500
        
        return hasUrgentKeywords || hasVIPSender || isShortEmail
    }
    
    /// Calcola la confidence dei metodi tradizionali
    private func getTraditionalCategorizationConfidence(_ email: EmailMessage) -> Double {
        var confidence = 0.0
        
        // Domain matching
        if categorizeByDomain(email.from) != nil {
            confidence += 0.4
        }
        
        // Subject keywords
        if categorizeBySubjectKeywords(email.subject) != nil {
            confidence += 0.3
        }
        
        // Content patterns
        if categorizeByContentPatterns(email.body) != nil {
            confidence += 0.3
        }
        
        return confidence
    }
    
    // MARK: - AI Count Management
    
    /// Carica i contatori AI da UserDefaults
    private func loadAICountsFromStorage() {
        sessionAICount = UserDefaults.standard.integer(forKey: sessionAICountKey)
        
        // Carica contatori per account
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix(aiCategorizedCountKey) {
                let accountId = String(key.dropFirst(aiCategorizedCountKey.count))
                accountAICounts[accountId] = UserDefaults.standard.integer(forKey: key)
            }
        }
        
        print("📊 EmailCategorizationService: Caricati contatori AI - Sessione: \(sessionAICount)")
    }
    
    // MARK: - Monitor Integration
    
    /// Imposta il monitor per le statistiche
    public func setMonitor(_ monitor: EmailCategorizationMonitor?) {
        self.monitor = monitor
        print("📊 EmailCategorizationService: Monitor \(monitor != nil ? "collegato" : "scollegato")")
    }
    
    /// Salva i contatori AI in UserDefaults
    private func saveAICountsToStorage() {
        UserDefaults.standard.set(sessionAICount, forKey: sessionAICountKey)
        
        for (accountId, count) in accountAICounts {
            UserDefaults.standard.set(count, forKey: aiCategorizedCountKey + accountId)
        }
        
        print("💾 EmailCategorizationService: Salvati contatori AI - Sessione: \(sessionAICount)")
    }
    
    /// Incrementa il contatore per un account specifico
    public func incrementAccountAICount(for accountId: String) {
        accountAICounts[accountId] = (accountAICounts[accountId] ?? 0) + 1
        saveAICountsToStorage()
    }
    
    /// Resetta i contatori di sessione (chiamato a nuovo avvio app)
    public func resetSessionCounters() {
        sessionAICount = 0
        saveAICountsToStorage()
        print("🔄 EmailCategorizationService: Contatori sessione resettati")
    }
    
    /// Ottieni statistiche utilizzo AI
    public func getAIUsageStats() -> (sessionCount: Int, accountCounts: [String: Int], maxSession: Int, maxPerAccount: Int) {
        return (
            sessionCount: sessionAICount,
            accountCounts: accountAICounts,
            maxSession: config.maxAICategorizationPerSession,
            maxPerAccount: config.maxAICategorizationPerAccount
        )
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
