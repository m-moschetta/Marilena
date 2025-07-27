import Foundation
import Combine

// MARK: - Email AI Service
// Servizio AI per la generazione di bozze di risposta email

@MainActor
public class EmailAIService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isGenerating = false
    @Published public var error: String?
    @Published public var generatedDrafts: [EmailDraft] = []
    
    // MARK: - Private Properties
    private let openAIService = OpenAIService.shared
    private let anthropicService = AnthropicService.shared
    private let promptManager = PromptManager.shared
    
    // MARK: - Configuration
    private var selectedModel = "gpt-4o-mini"
    private var maxTokens = 1000
    private var temperature = 0.7
    
    // MARK: - Initialization
    
    public init() {
        loadConfiguration()
    }
    
    // MARK: - Public Methods
    
    /// Genera una bozza di risposta per un'email
    public func generateDraft(for email: EmailMessage, context: String = "") async -> EmailDraft? {
        isGenerating = true
        error = nil
        
        do {
            let prompt = createEmailPrompt(for: email, context: context)
            let response = try await sendToAI(prompt: prompt)
            
            let draft = EmailDraft(
                id: UUID(),
                originalEmail: email,
                content: response,
                generatedAt: Date(),
                context: context
            )
            
            generatedDrafts.append(draft)
            isGenerating = false
            
            return draft
            
        } catch {
            self.error = error.localizedDescription
            isGenerating = false
            return nil
        }
    }
    
    /// Genera multiple bozze alternative
    public func generateMultipleDrafts(for email: EmailMessage, count: Int = 3) async -> [EmailDraft] {
        var drafts: [EmailDraft] = []
        
        for i in 0..<count {
            let context = "Variante \(i + 1): "
            if let draft = await generateDraft(for: email, context: context) {
                drafts.append(draft)
            }
        }
        
        return drafts
    }
    
    /// Analizza il tono e il contenuto di un'email
    public func analyzeEmail(_ email: EmailMessage) async -> EmailAnalysis? {
        do {
            let prompt = createAnalysisPrompt(for: email)
            let response = try await sendToAI(prompt: prompt)
            
            return parseEmailAnalysis(response)
            
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
    
    /// Suggerisce una categoria per l'email
    public func categorizeEmail(_ email: EmailMessage) async -> EmailCategory? {
        do {
            let prompt = createCategorizationPrompt(for: email)
            let response = try await sendToAI(prompt: prompt)
            
            return parseEmailCategory(response)
            
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
    
    /// Genera un riassunto dell'email
    public func summarizeEmail(_ email: EmailMessage) async -> String? {
        do {
            let prompt = createSummaryPrompt(for: email)
            let response = try await sendToAI(prompt: prompt)
            
            return response
            
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
    
    /// Valuta l'urgenza dell'email
    public func assessUrgency(_ email: EmailMessage) async -> EmailUrgency {
        do {
            let prompt = createUrgencyPrompt(for: email)
            let response = try await sendToAI(prompt: prompt)
            
            return parseUrgency(response)
            
        } catch {
            return .normal
        }
    }
    
    // MARK: - Private Methods
    
    private func createEmailPrompt(for email: EmailMessage, context: String) -> String {
        return """
        Sei un assistente email professionale e conciso. Il tuo compito è scrivere una bozza di risposta a questa email. Rispondi in italiano.
        
        \(context)
        
        ---
        Email a cui rispondere:
        Da: \(email.from)
        Oggetto: \(email.subject)
        Data: \(formatDate(email.date))
        Corpo: \(email.body)
        ---
        
        ISTRUZIONI:
        1. Scrivi una risposta professionale e appropriata
        2. Mantieni un tono cordiale ma professionale
        3. Rispondi a tutti i punti sollevati nell'email originale
        4. Sii conciso ma completo
        5. Non includere saluti iniziali se non necessario
        6. Usa un linguaggio chiaro e diretto
        
        BOZZA DI RISPOSTA:
        """
    }
    
    private func createAnalysisPrompt(for email: EmailMessage) -> String {
        return """
        Analizza questa email e fornisci un'analisi dettagliata.
        
        EMAIL:
        Da: \(email.from)
        Oggetto: \(email.subject)
        Corpo: \(email.body)
        
        Fornisci un'analisi JSON con i seguenti campi:
        - tono: (formale, informale, amichevole, professionale, urgente)
        - sentiment: (positivo, negativo, neutro)
        - argomenti_principali: [lista degli argomenti principali]
        - richieste_esplicite: [eventuali richieste esplicite]
        - richieste_implicite: [eventuali richieste implicite]
        - urgenza: (bassa, media, alta)
        - complessità: (semplice, media, complessa)
        """
    }
    
    private func createCategorizationPrompt(for email: EmailMessage) -> String {
        return """
        Categorizza questa email in una delle seguenti categorie:
        
        - lavoro: email relative al lavoro
        - personale: email personali
        - commerciale: email commerciali/promozionali
        - tecnico: email tecniche/supporto
        - sociale: email sociali/inviti
        - spam: email non desiderate
        
        EMAIL:
        Da: \(email.from)
        Oggetto: \(email.subject)
        Corpo: \(email.body)
        
        Rispondi solo con la categoria.
        """
    }
    
    private func createSummaryPrompt(for email: EmailMessage) -> String {
        return """
        Crea un riassunto conciso di questa email in 2-3 frasi.
        
        EMAIL:
        Da: \(email.from)
        Oggetto: \(email.subject)
        Corpo: \(email.body)
        
        RIASSUNTO:
        """
    }
    
    private func createUrgencyPrompt(for email: EmailMessage) -> String {
        return """
        Valuta l'urgenza di questa email. Rispondi solo con: bassa, media, alta.
        
        EMAIL:
        Da: \(email.from)
        Oggetto: \(email.subject)
        Corpo: \(email.body)
        """
    }
    
    private func sendToAI(prompt: String) async throws -> String {
        // Usa il provider AI configurato
        let provider = AIProviderManager.shared.getBestChatProvider()
        
        switch provider?.provider {
        case .openai:
            return try await openAIService.sendMessage(prompt, model: selectedModel)
        case .anthropic:
            return try await anthropicService.sendMessage(prompt, model: "claude-3-5-sonnet-20240620")
        default:
            throw EmailAIError.noProviderConfigured
        }
    }
    
    private func parseEmailAnalysis(_ response: String) -> EmailAnalysis? {
        // Parsing semplificato - in produzione usare JSON parsing
        let lines = response.components(separatedBy: .newlines)
        
        var analysis = EmailAnalysis()
        
        for line in lines {
            if line.contains("tono:") {
                analysis.tone = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "neutro"
            } else if line.contains("sentiment:") {
                analysis.sentiment = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "neutro"
            } else if line.contains("urgenza:") {
                analysis.urgency = parseUrgency(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "media")
            }
        }
        
        return analysis
    }
    
    private func parseEmailCategory(_ response: String) -> EmailCategory? {
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch cleanResponse {
        case "lavoro":
            return .work
        case "personale":
            return .personal
        case "commerciale":
            return .commercial
        case "tecnico":
            return .technical
        case "sociale":
            return .social
        case "spam":
            return .spam
        default:
            return .other
        }
    }
    
    private func parseUrgency(_ response: String) -> EmailUrgency {
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch cleanResponse {
        case "alta":
            return .high
        case "media":
            return .medium
        case "bassa":
            return .low
        default:
            return .normal
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
    
    private func loadConfiguration() {
        selectedModel = UserDefaults.standard.string(forKey: "email_ai_model") ?? "gpt-4o-mini"
        maxTokens = UserDefaults.standard.integer(forKey: "email_ai_max_tokens")
        if maxTokens == 0 { maxTokens = 1000 }
        temperature = UserDefaults.standard.double(forKey: "email_ai_temperature")
        if temperature == 0 { temperature = 0.7 }
    }
}

// MARK: - Supporting Types

public struct EmailDraft: Identifiable {
    public let id: UUID
    public let originalEmail: EmailMessage
    public let content: String
    public let generatedAt: Date
    public let context: String
    
    public init(id: UUID = UUID(), originalEmail: EmailMessage, content: String, generatedAt: Date, context: String) {
        self.id = id
        self.originalEmail = originalEmail
        self.content = content
        self.generatedAt = generatedAt
        self.context = context
    }
}

public struct EmailAnalysis {
    public var tone: String = "neutro"
    public var sentiment: String = "neutro"
    public var urgency: EmailUrgency = .normal
    public var complexity: String = "media"
    public var mainTopics: [String] = []
    public var explicitRequests: [String] = []
    public var implicitRequests: [String] = []
}

public enum EmailCategory: String, CaseIterable {
    case work = "lavoro"
    case personal = "personale"
    case commercial = "commerciale"
    case technical = "tecnico"
    case social = "sociale"
    case spam = "spam"
    case other = "altro"
    
    public var displayName: String {
        switch self {
        case .work:
            return "Lavoro"
        case .personal:
            return "Personale"
        case .commercial:
            return "Commerciale"
        case .technical:
            return "Tecnico"
        case .social:
            return "Sociale"
        case .spam:
            return "Spam"
        case .other:
            return "Altro"
        }
    }
    
    public var iconName: String {
        switch self {
        case .work:
            return "briefcase.fill"
        case .personal:
            return "person.fill"
        case .commercial:
            return "cart.fill"
        case .technical:
            return "wrench.fill"
        case .social:
            return "person.2.fill"
        case .spam:
            return "exclamationmark.triangle.fill"
        case .other:
            return "questionmark.circle.fill"
        }
    }
}

public enum EmailUrgency: String, CaseIterable {
    case low = "bassa"
    case normal = "normale"
    case medium = "media"
    case high = "alta"
    
    public var displayName: String {
        switch self {
        case .low:
            return "Bassa"
        case .normal:
            return "Normale"
        case .medium:
            return "Media"
        case .high:
            return "Alta"
        }
    }
    
    public var color: String {
        switch self {
        case .low:
            return "green"
        case .normal:
            return "blue"
        case .medium:
            return "orange"
        case .high:
            return "red"
        }
    }
}

public enum EmailAIError: LocalizedError {
    case noProviderConfigured
    case invalidResponse
    case generationFailed
    
    public var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            return "Nessun provider AI configurato"
        case .invalidResponse:
            return "Risposta AI non valida"
        case .generationFailed:
            return "Generazione bozza fallita"
        }
    }
} 