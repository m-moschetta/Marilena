import Foundation
import Combine
import SwiftUI

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
    
    /// Genera una risposta personalizzata basata su un prompt specifico
    public func generateCustomResponse(for email: EmailMessage, basedOn draft: EmailDraft?, withPrompt customPrompt: String) async -> EmailDraft? {
        isGenerating = true
        error = nil
        
        do {
            let prompt = createCustomResponsePrompt(for: email, basedOn: draft, withPrompt: customPrompt)
            let response = try await sendToAI(prompt: prompt)
            
            let customDraft = EmailDraft(
                id: UUID(),
                originalEmail: email,
                content: response,
                generatedAt: Date(),
                context: "Risposta personalizzata: \(customPrompt)"
            )
            
            generatedDrafts.append(customDraft)
            isGenerating = false
            
            return customDraft
            
        } catch {
            self.error = error.localizedDescription
            isGenerating = false
            return nil
        }
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
        // Usa il prompt configurabile dalle impostazioni
        let basePrompt = UserDefaults.standard.string(forKey: "email_prompt_draft") ?? PromptManager.emailDraftPrompt
        
        return basePrompt
            .replacingOccurrences(of: "{CONTESTO}", with: context)
            .replacingOccurrences(of: "{MITtente}", with: email.from)
            .replacingOccurrences(of: "{Oggetto}", with: email.subject)
            .replacingOccurrences(of: "{Data}", with: formatDate(email.date))
            .replacingOccurrences(of: "{Corpo}", with: email.body)
    }
    
    private func createAnalysisPrompt(for email: EmailMessage) -> String {
        let basePrompt = UserDefaults.standard.string(forKey: "email_prompt_analysis") ?? PromptManager.emailAnalysisPrompt
        
        return basePrompt
            .replacingOccurrences(of: "{MITtente}", with: email.from)
            .replacingOccurrences(of: "{Oggetto}", with: email.subject)
            .replacingOccurrences(of: "{Corpo}", with: email.body)
    }
    
    private func createCategorizationPrompt(for email: EmailMessage) -> String {
        let basePrompt = UserDefaults.standard.string(forKey: "email_prompt_categorization") ?? PromptManager.emailCategorizationPrompt
        
        return basePrompt
            .replacingOccurrences(of: "{MITtente}", with: email.from)
            .replacingOccurrences(of: "{Oggetto}", with: email.subject)
            .replacingOccurrences(of: "{Corpo}", with: email.body)
    }
    
    private func createSummaryPrompt(for email: EmailMessage) -> String {
        let basePrompt = UserDefaults.standard.string(forKey: "email_prompt_summary") ?? PromptManager.emailSummaryPrompt
        
        return basePrompt
            .replacingOccurrences(of: "{MITtente}", with: email.from)
            .replacingOccurrences(of: "{Oggetto}", with: email.subject)
            .replacingOccurrences(of: "{Corpo}", with: email.body)
    }
    
    private func createUrgencyPrompt(for email: EmailMessage) -> String {
        let basePrompt = UserDefaults.standard.string(forKey: "email_prompt_urgency") ?? PromptManager.emailUrgencyPrompt
        
        return basePrompt
            .replacingOccurrences(of: "{MITtente}", with: email.from)
            .replacingOccurrences(of: "{Oggetto}", with: email.subject)
            .replacingOccurrences(of: "{Corpo}", with: email.body)
    }
    
    private func createCustomResponsePrompt(for email: EmailMessage, basedOn draft: EmailDraft?, withPrompt customPrompt: String) -> String {
        let basePrompt = """
        Genera una risposta email personalizzata seguendo queste istruzioni specifiche:
        
        ISTRUZIONI PERSONALIZZATE:
        \(customPrompt)
        
        CONTESTO EMAIL ORIGINALE:
        Mittente: {MITtente}
        Oggetto: {Oggetto}
        Data: {Data}
        Corpo: {Corpo}
        
        BOZZA DI RIFERIMENTO (se disponibile):
        {BOZZA_RIFERIMENTO}
        
        Genera una risposta email professionale e appropriata che segua esattamente le istruzioni personalizzate fornite.
        """
        
        let draftContent = draft?.content ?? "Nessuna bozza di riferimento disponibile"
        
        return basePrompt
            .replacingOccurrences(of: "{MITtente}", with: email.from)
            .replacingOccurrences(of: "{Oggetto}", with: email.subject)
            .replacingOccurrences(of: "{Data}", with: formatDate(email.date))
            .replacingOccurrences(of: "{Corpo}", with: email.body)
            .replacingOccurrences(of: "{BOZZA_RIFERIMENTO}", with: draftContent)
    }
    
    /// Genera una risposta AI da un prompt personalizzato
    public func generateResponse(prompt: String) async throws -> String {
        isGenerating = true
        error = nil
        
        do {
            let response = try await sendToAI(prompt: prompt)
            isGenerating = false
            return response
        } catch {
            self.error = error.localizedDescription
            isGenerating = false
            throw error
        }
    }
    
    private func sendToAI(prompt: String) async throws -> String {
        // Usa il provider AI configurato
        let provider = AIProviderManager.shared.getBestChatProvider()
        
        return try await withCheckedThrowingContinuation { continuation in
            switch provider?.provider {
            case .openai:
                let message = OpenAIMessage(role: "user", content: prompt)
                openAIService.sendMessage(messages: [message], model: selectedModel) { result in
                    switch result {
                    case .success(let response):
                        continuation.resume(returning: response)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            case .anthropic:
                let content = AnthropicContent(type: "text", text: prompt)
                let message = AnthropicMessage(role: "user", content: [content])
                anthropicService.sendMessage(messages: [message], model: "claude-sonnet-4-20250514", maxTokens: maxTokens, temperature: temperature) { result in
                    switch result {
                    case .success(let response):
                        continuation.resume(returning: response)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            default:
                continuation.resume(throwing: EmailAIError.noProviderConfigured)
            }
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
        case "commerciale", "spam":
            return .promotional
        case "tecnico", "sociale":
            return .notifications
        default:
            return .notifications
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
    public var category: EmailCategory = .notifications
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
    
    public var icon: String {
        switch self {
        case .low:
            return "arrow.down.circle"
        case .normal:
            return "circle"
        case .medium:
            return "exclamationmark.circle"
        case .high:
            return "exclamationmark.2"
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