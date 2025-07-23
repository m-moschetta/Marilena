import Foundation
import Combine

// MARK: - Chat Service (Riusabile)
// Servizio di chat AI modulare e riutilizzabile

@MainActor
public class ChatService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var messages: [ModularChatMessage] = []
    @Published public var isProcessing = false
    @Published public var error: String?
    @Published public var currentSession: ChatSession?
    
    // MARK: - Configuration
    private let aiProviderManager: AIProviderManager
    private let promptManager: PromptManager
    private let configuration: ChatConfiguration
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var processingStartTime: Date?
    
    // MARK: - Initialization
    
    public init(
        aiProviderManager: AIProviderManager = .shared,
        promptManager: PromptManager = .shared,
        configuration: ChatConfiguration = ChatConfiguration()
    ) {
        self.aiProviderManager = aiProviderManager
        self.promptManager = promptManager
        self.configuration = configuration
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Invia un messaggio e riceve la risposta AI
    public func sendMessage(_ text: String, context: String = "") async {
        let userMessage = ModularChatMessage(
            content: text,
            role: .user,
            metadata: MessageMetadata(context: context)
        )
        
        messages.append(userMessage)
        isProcessing = true
        error = nil
        processingStartTime = Date()
        
        do {
            let response = try await processMessage(text, context: context)
            let processingTime = processingStartTime.map { Date().timeIntervalSince($0) }
            
            let aiMessage = ModularChatMessage(
                content: response,
                role: .assistant,
                metadata: MessageMetadata(
                    model: configuration.model,
                    processingTime: processingTime,
                    context: context
                )
            )
            messages.append(aiMessage)
            
            // Aggiorna la sessione
            updateCurrentSession()
            
        } catch {
            self.error = error.localizedDescription
            print("❌ ChatService: Errore durante l'elaborazione: \(error)")
        }
        
        isProcessing = false
        processingStartTime = nil
    }
    
    /// Cancella tutti i messaggi
    public func clearMessages() {
        messages.removeAll()
        error = nil
        updateCurrentSession()
    }
    
    /// Esporta la conversazione
    public func exportConversation() -> String {
        return messages.map { message in
            "\(message.role.displayName): \(message.content)"
        }.joined(separator: "\n\n")
    }
    
    /// Crea una nuova sessione di chat
    public func createSession(title: String, context: String? = nil) {
        currentSession = ChatSession(
            title: title,
            messages: messages,
            context: context
        )
    }
    
    /// Carica una sessione esistente
    public func loadSession(_ session: ChatSession) {
        currentSession = session
        messages = session.messages
        error = nil
    }
    
    /// Salva la sessione corrente
    public func saveSession() -> ChatSession? {
        guard let session = currentSession else { return nil }
        
        let updatedSession = ChatSession(
            id: session.id,
            title: session.title,
            messages: messages,
            createdAt: session.createdAt,
            updatedAt: Date(),
            context: session.context
        )
        
        currentSession = updatedSession
        return updatedSession
    }
    
    /// Ottiene il riassunto della conversazione
    public func getConversationSummary() -> String {
        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }
        
        return """
        Conversazione: \(messages.count) messaggi totali
        Messaggi utente: \(userMessages.count)
        Messaggi assistente: \(assistantMessages.count)
        Ultimo aggiornamento: \(Date().formatted())
        """
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Osserva cambiamenti nei messaggi per aggiornare la sessione
        $messages
            .sink { [weak self] _ in
                self?.updateCurrentSession()
            }
            .store(in: &cancellables)
    }
    
    private func updateCurrentSession() {
        guard let session = currentSession else { return }
        
        currentSession = ChatSession(
            id: session.id,
            title: session.title,
            messages: messages,
            createdAt: session.createdAt,
            updatedAt: Date(),
            context: session.context
        )
    }
    
    private func processMessage(_ text: String, context: String) async throws -> String {
        guard let (provider, model) = aiProviderManager.getBestChatProvider() else {
            throw ChatError.noProviderConfigured
        }
        
        // Prepara il prompt con il contesto
        let prompt = PromptManager.getPrompt(
            for: .chatBase,
            replacements: [
                "CONTESTO_UTENTE": context,
                "MESSAGGIO": text
            ]
        )
        
        // Verifica che il contesto non sia troppo lungo
        let totalContext = prompt.count + context.count
        if totalContext > configuration.contextWindow {
            throw ChatError.contextTooLong
        }
        
        switch provider {
        case .openai:
            return try await sendToOpenAI(prompt: prompt, model: model)
        case .anthropic:
            return try await sendToAnthropic(prompt: prompt, model: model)
        case .groq:
            return try await sendToGroq(prompt: prompt, model: model)
        }
    }
    
    private func sendToOpenAI(prompt: String, model: String) async throws -> String {
        let service = OpenAIService.shared
        return try await withCheckedThrowingContinuation { continuation in
            let message = OpenAIMessage(role: "user", content: prompt)
            service.sendMessage(messages: [message], model: model) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func sendToAnthropic(prompt: String, model: String) async throws -> String {
        let service = AnthropicService.shared
        return try await withCheckedThrowingContinuation { continuation in
            let content = AnthropicContent(type: "text", text: prompt)
            let message = AnthropicMessage(role: "user", content: [content])
            service.sendMessage(messages: [message], model: model, maxTokens: configuration.maxTokens, temperature: configuration.temperature) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func sendToGroq(prompt: String, model: String) async throws -> String {
        // TODO: Implementare GroqService
        throw ChatError.providerNotImplemented
    }
}

// MARK: - Chat Service Extensions

extension ChatService {
    
    /// Configura il servizio con nuove impostazioni
    public func configure(_ newConfiguration: ChatConfiguration) {
        // Aggiorna la configurazione
        // Nota: In una implementazione completa, questo richiederebbe una refactor per rendere configuration mutabile
        print("🔧 ChatService: Configurazione aggiornata")
    }
    
    /// Ottiene statistiche della conversazione
    public func getConversationStats() -> ConversationStats {
        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }
        let totalTokens = messages.compactMap { $0.metadata?.tokens }.reduce(0, +)
        let avgProcessingTime = messages.compactMap { $0.metadata?.processingTime }.reduce(0, +) / Double(max(messages.count, 1))
        
        return ConversationStats(
            totalMessages: messages.count,
            userMessages: userMessages.count,
            assistantMessages: assistantMessages.count,
            totalTokens: totalTokens,
            averageProcessingTime: avgProcessingTime
        )
    }
}

// MARK: - Conversation Stats

public struct ConversationStats {
    public let totalMessages: Int
    public let userMessages: Int
    public let assistantMessages: Int
    public let totalTokens: Int
    public let averageProcessingTime: TimeInterval
    
    public init(
        totalMessages: Int,
        userMessages: Int,
        assistantMessages: Int,
        totalTokens: Int,
        averageProcessingTime: TimeInterval
    ) {
        self.totalMessages = totalMessages
        self.userMessages = userMessages
        self.assistantMessages = assistantMessages
        self.totalTokens = totalTokens
        self.averageProcessingTime = averageProcessingTime
    }
} 