import Foundation

// MARK: - Chat Message Model
// Modello dati per messaggi di chat riutilizzabile

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
    
    public init(
        model: String? = nil,
        tokens: Int? = nil,
        processingTime: TimeInterval? = nil,
        error: String? = nil,
        context: String? = nil
    ) {
        self.model = model
        self.tokens = tokens
        self.processingTime = processingTime
        self.error = error
        self.context = context
    }
}

// MARK: - Chat Session

public struct ChatSession: Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let messages: [ModularChatMessage]
    public let createdAt: Date
    public let updatedAt: Date
    public let context: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        messages: [ModularChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        context: String? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.context = context
    }
}

// MARK: - Chat Configuration

public struct ChatConfiguration {
    public let maxTokens: Int
    public let temperature: Double
    public let model: String
    public let systemPrompt: String?
    public let contextWindow: Int
    
    public init(
        maxTokens: Int = 4000,
        temperature: Double = 0.7,
        model: String = "gpt-4.1-mini",
        systemPrompt: String? = nil,
        contextWindow: Int = 8000
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.model = model
        self.systemPrompt = systemPrompt
        self.contextWindow = contextWindow
    }
}

// MARK: - Chat Error

public enum ChatError: LocalizedError {
    case noProviderConfigured
    case providerNotImplemented
    case invalidResponse
    case networkError(String)
    case rateLimitExceeded
    case contextTooLong
    
    public var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            return "Nessun provider AI configurato"
        case .providerNotImplemented:
            return "Provider non ancora implementato"
        case .invalidResponse:
            return "Risposta AI non valida"
        case .networkError(let message):
            return "Errore di rete: \(message)"
        case .rateLimitExceeded:
            return "Limite di richieste superato"
        case .contextTooLong:
            return "Contesto troppo lungo per il modello"
        }
    }
} 