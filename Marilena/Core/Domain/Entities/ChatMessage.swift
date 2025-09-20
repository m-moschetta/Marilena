import Foundation
import CoreData

// MARK: - Chat Message Model
// Modello dati per messaggi di chat riutilizzabile con tutte le funzionalità avanzate

public struct ModularChatMessage: Identifiable, Codable, Equatable {
    public let id: UUID
    public let content: String
    public let role: MessageRole
    public let timestamp: Date
    public let metadata: MessageMetadata?
    
    public init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Message Role

public enum MessageRole: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    public var displayName: String {
        switch self {
        case .user:
            return "Utente"
        case .assistant:
            return "Assistente"
        case .system:
            return "Sistema"
        }
    }
    
    public var iconName: String {
        switch self {
        case .user:
            return "person.circle.fill"
        case .assistant:
            return "brain.head.profile"
        case .system:
            return "gear.circle.fill"
        }
    }
}

// MARK: - Message Metadata

public struct MessageMetadata: Codable, Equatable {
    public let model: String?
    public let tokens: Int?
    public let processingTime: TimeInterval?
    public let error: String?
    public let context: String?
    public let provider: String?
    public let cost: Double?
    public let confidence: Double?
    public let toolCalls: [MessageToolCall]?
    
    public init(
        model: String? = nil,
        tokens: Int? = nil,
        processingTime: TimeInterval? = nil,
        error: String? = nil,
        context: String? = nil,
        provider: String? = nil,
        cost: Double? = nil,
        confidence: Double? = nil,
        toolCalls: [MessageToolCall]? = nil
    ) {
        self.model = model
        self.tokens = tokens
        self.processingTime = processingTime
        self.error = error
        self.context = context
        self.provider = provider
        self.cost = cost
        self.confidence = confidence
        self.toolCalls = toolCalls
    }
}

public struct MessageToolCall: Codable, Equatable {
    public let id: String?
    public let name: String?
    public let arguments: String
    public let isCompleted: Bool
    
    public init(id: String?, name: String?, arguments: String, isCompleted: Bool) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.isCompleted = isCompleted
    }
}

public extension MessageMetadata {
    func with(
        tokens: Int? = nil,
        provider: String? = nil,
        toolCalls: [MessageToolCall]? = nil
    ) -> MessageMetadata {
        MessageMetadata(
            model: model,
            tokens: tokens ?? self.tokens,
            processingTime: processingTime,
            error: error,
            context: context,
            provider: provider ?? self.provider,
            cost: cost,
            confidence: confidence,
            toolCalls: toolCalls ?? self.toolCalls
        )
    }
}

// MARK: - Chat Session

public struct ChatSession: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let messages: [ModularChatMessage]
    public let createdAt: Date
    public let updatedAt: Date
    public let type: String
    
    public init(
        id: UUID = UUID(),
        title: String,
        messages: [ModularChatMessage],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        type: String = "chat"
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.type = type
    }
}

// MARK: - Chat Configuration

public struct ChatConfiguration {
    public let selectedModel: String
    public let maxTokens: Int
    public let temperature: Double
    public let enableStreaming: Bool
    public let enableContext: Bool
    public let adapter: ModuleAdapter?
    
    public init(
        selectedModel: String = "gpt-4o-mini",
        maxTokens: Int = 4000,
        temperature: Double = 0.7,
        enableStreaming: Bool = false,
        enableContext: Bool = true,
        adapter: ModuleAdapter? = nil
    ) {
        self.selectedModel = selectedModel
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.enableStreaming = enableStreaming
        self.enableContext = enableContext
        self.adapter = adapter
    }
}

// MARK: - Chat Error

public enum ChatError: LocalizedError {
    case noProviderConfigured
    case contextTooLong
    case providerNotImplemented
    case invalidResponse
    case networkError(String)
    case rateLimitExceeded
    case quotaExceeded
    
    public var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            return "Nessun provider AI configurato"
        case .contextTooLong:
            return "Il contesto è troppo lungo per essere elaborato"
        case .providerNotImplemented:
            return "Provider non ancora implementato"
        case .invalidResponse:
            return "Risposta AI non valida"
        case .networkError(let message):
            return "Errore di rete: \(message)"
        case .rateLimitExceeded:
            return "Limite di richieste superato"
        case .quotaExceeded:
            return "Quota API esaurita"
        }
    }
}

// MARK: - AI Provider

public enum AIProvider: String, CaseIterable, Codable {
    case openai = "openai"
    case anthropic = "anthropic"
    case groq = "groq"
    case perplexity = "perplexity"
    
    public var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .groq:
            return "Groq"
        case .perplexity:
            return "Perplexity"
        }
    }
    
    public var iconName: String {
        switch self {
        case .openai:
            return "brain.head.profile"
        case .anthropic:
            return "person.2.circle.fill"
        case .groq:
            return "bolt.circle.fill"
        case .perplexity:
            return "magnifyingglass.circle.fill"
        }
    }
} 
