import Foundation

public enum AIModelProvider: String, Codable, CaseIterable {
    case apple = "apple"
    case openai = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case meta = "meta"
    case xai = "xai"
    case mistral = "mistral"
    case perplexity = "perplexity"
    case deepseek = "deepseek"
    case groq = "groq"

    public var displayName: String {
        switch self {
        case .apple: return "Apple Intelligence"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        case .meta: return "Meta"
        case .xai: return "xAI"
        case .mistral: return "Mistral AI"
        case .perplexity: return "Perplexity"
        case .deepseek: return "DeepSeek"
        case .groq: return "Groq"
        }
    }

    public var baseURL: String {
        switch self {
        case .apple: return ""
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .google: return "https://generativelanguage.googleapis.com/v1"
        case .meta: return "https://api.llama-api.com/v1"
        case .xai: return "https://api.x.ai/v1"
        case .mistral: return "https://api.mistral.ai/v1"
        case .perplexity: return "https://api.perplexity.ai"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        }
    }
}