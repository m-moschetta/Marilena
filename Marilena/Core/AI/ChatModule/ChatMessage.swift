import Foundation
import CoreData

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

// MARK: - Modular Chat Session

public struct ModularChatSession: Identifiable, Codable {
    public let id: UUID
    public let title: String
    public var messages: [ModularChatMessage]
    public let createdAt: Date
    public var updatedAt: Date
    public let type: String
    
    public init(
        id: UUID = UUID(),
        title: String,
        messages: [ModularChatMessage] = [],
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
    public let session: ModularChatSession
    public let aiProviderManager: AIProviderManager
    public let promptManager: PromptManager
    public let context: NSManagedObjectContext
    public let adapter: ModuleAdapter?
    
    // Impostazioni AI
    public let maxTokens: Int
    public let temperature: Double
    public let selectedProvider: AIProvider
    public let selectedModel: String
    
    public init(
        session: ModularChatSession,
        aiProviderManager: AIProviderManager,
        promptManager: PromptManager,
        context: NSManagedObjectContext,
        adapter: ModuleAdapter? = nil,
        maxTokens: Int = 100000,
        temperature: Double = 0.7,
        selectedProvider: AIProvider = .openai,
        selectedModel: String = "gpt-4o-mini"
    ) {
        self.session = session
        self.aiProviderManager = aiProviderManager
        self.promptManager = promptManager
        self.context = context
        self.adapter = adapter
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.selectedProvider = selectedProvider
        self.selectedModel = selectedModel
    }
}

// MARK: - AI Provider

public enum AIProvider: String, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case groq = "groq"
    
    public var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .groq: return "Groq"
        }
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