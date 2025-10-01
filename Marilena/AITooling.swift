import Foundation

public struct AIToolDefinition {
    public let name: String
    public let description: String
    public let jsonSchema: String
    
    public init(name: String, description: String, jsonSchema: String) {
        self.name = name
        self.description = description
        self.jsonSchema = jsonSchema
    }
}

public struct AIMessage {
    public let role: String
    public let content: String
    
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public enum AIModelProvider: CaseIterable {
    case apple
    case openai
    case anthropic
    case groq
    case mistral
    case perplexity
    case deepseek
    case xai
    case google
    case meta
    
    public var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .groq: return "Groq"
        case .mistral: return "Mistral"
        case .perplexity: return "Perplexity"
        case .deepseek: return "Deepseek"
        case .xai: return "XAI"
        case .google: return "Google"
        case .meta: return "Meta"
        }
    }
}

public struct AIUsage {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    
    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}
