import Foundation

// MARK: - Anthropic API Models

struct AnthropicMessage: Codable {
    let role: String
    let content: [AnthropicContent]
}

struct AnthropicContent: Codable {
    let type: String
    let text: String
}

struct AnthropicRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicMessage]
    let temperature: Double?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

@MainActor
struct AnthropicResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: AnthropicUsage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

struct AnthropicUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Anthropic Service

class AnthropicService {
    static let shared = AnthropicService()
    
    private let baseURL = "https://api.anthropic.com/v1"
    
    // Modelli supportati da Anthropic
    static let claudeModels = [
        "claude-opus-4-20250514",
        "claude-sonnet-4-20250514", 
        "claude-3-7-sonnet-20250219",
        "claude-3-5-haiku-20241022"
    ]
    
    private init() {}
    
    // MARK: - API Key Management
    private func getAPIKey() -> String? {
        return KeychainManager.shared.load(key: "anthropicApiKey")
    }
    
    func hasAPIKey() -> Bool {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Chat Methods
    
    func sendMessage(messages: [AnthropicMessage], completion: @escaping (Result<String, Error>) -> Void) {
        // Usa le impostazioni specifiche per Chat AI
        let selectedModel = UserDefaults.standard.string(forKey: "selectedAnthropicModel") ?? "claude-sonnet-4-20250514"
        let maxTokens = Int(UserDefaults.standard.double(forKey: "maxChatTokens"))
        let temperature = UserDefaults.standard.double(forKey: "temperature")
        
        sendMessage(messages: messages, model: selectedModel, maxTokens: maxTokens, temperature: temperature, completion: completion)
    }
    
    func sendMessage(messages: [AnthropicMessage], model: String, maxTokens: Int, temperature: Double, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            DispatchQueue.main.async {
                completion(.failure(AnthropicError.noAPIKey))
            }
            return
        }
        
        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: maxTokens,
            messages: messages,
            temperature: temperature
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(AnthropicError.noData))
                }
                return
            }
            
            do {
                let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
                let responseText = anthropicResponse.content.first?.text ?? "Nessuna risposta"
                DispatchQueue.main.async {
                    completion(.success(responseText))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Utility Methods
    
    func createMessage(role: String, content: String) -> AnthropicMessage {
        return AnthropicMessage(
            role: role,
            content: [AnthropicContent(type: "text", text: content)]
        )
    }
    
    func createMessagesFromOpenAI(_ openAIMessages: [OpenAIMessage]) -> [AnthropicMessage] {
        return openAIMessages.map { openAIMessage in
            let role = openAIMessage.role == "user" ? "user" : "assistant"
            return createMessage(role: role, content: openAIMessage.content)
        }
    }
    
    // MARK: - Model Information
    	
    func getModelInfo(model: String) -> AIModelInfo? {
        switch model {
        case "claude-opus-4-20250514":
            return AIModelInfo(name: "Claude Opus 4", description: "Il modello più potente per ragionamento complesso", contextTokens: 200000, supportsStreaming: true)
        case "claude-sonnet-4-20250514":
            return AIModelInfo(name: "Claude Sonnet 4", description: "Bilanciamento perfetto tra intelligenza e velocità", contextTokens: 200000, supportsStreaming: true)
        case "claude-3-7-sonnet-20250219":
            return AIModelInfo(name: "Claude Sonnet 3.7", description: "Alte prestazioni con pensiero esteso", contextTokens: 200000, supportsStreaming: true)
        case "claude-3-5-haiku-20241022":
            return AIModelInfo(name: "Claude Haiku 3.5", description: "Velocità quasi istantanea per compiti leggeri", contextTokens: 200000, supportsStreaming: true)
        default:
            return AIModelInfo(name: model, description: "Modello generico", contextTokens: 200000, supportsStreaming: true)
        }
    }
    
    // MARK: - Platform-Specific Model Names
    
    func getModelNameForPlatform(model: String, platform: Platform) -> String {
        switch platform {
        case .directAPI:
            return model
        case .awsBedrock:
            return "anthropic.\(model)-v1:0"
        case .gcpVertexAI:
            return model.replacingOccurrences(of: "-", with: "@")
        }
    }
}

enum Platform {
    case directAPI
    case awsBedrock
    case gcpVertexAI
}

enum AnthropicError: Error, LocalizedError {
    case noAPIKey
    case noData
    case invalidModel
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API Key Anthropic non configurata"
        case .noData:
            return "Nessun dato ricevuto da Anthropic"
        case .invalidModel:
            return "Modello Anthropic non valido"
        }
    }
} 
