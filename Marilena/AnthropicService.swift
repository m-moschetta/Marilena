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

struct AnthropicResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContent]
    let model: String
    let stop_reason: String?
    let stop_sequence: String?
    let usage: AnthropicUsage
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stop_reason
        case stop_sequence
        case usage
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
    
    // Modelli supportati da Anthropic (nomi API confermati)
    static let claudeModels = [
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-3-haiku-20240307",
        "claude-3-opus-20240229"
    ]
    
    public init() {}
    
    // MARK: - API Key Management
    private func getAPIKey() -> String? {
        return KeychainManager.shared.getAPIKey(for: "anthropic")
    }
    
    func hasAPIKey() -> Bool {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Chat Methods
    
    public func testConnection() async throws -> Bool {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw AnthropicError.noAPIKey
        }

        let model = UserDefaults.standard.string(forKey: "selectedAnthropicModel") ?? "claude-3-5-sonnet-20241022"
        let messages = [
            createMessage(role: "user", content: "Hello")
        ]

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Usa un max_tokens valido per il test
        let body = AnthropicRequest(model: model, maxTokens: 64, messages: messages, temperature: 0.2)
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return false
        }
        return true
    }

    func sendMessage(messages: [AnthropicMessage], completion: @escaping (Result<String, Error>) -> Void) {
        // Usa modello selezionato dall'utente oppure un fallback sicuro
        let selectedModel = UserDefaults.standard.string(forKey: "selectedAnthropicModel") ?? "claude-3-5-sonnet-20241022"
        let maxTokens = Int(UserDefaults.standard.double(forKey: "maxChatTokens"))
        let temperature = UserDefaults.standard.double(forKey: "temperature")
        
        sendMessage(messages: messages, model: selectedModel, maxTokens: maxTokens, temperature: temperature, completion: completion)
    }
    
    func sendMessage(messages: [AnthropicMessage], model: String, maxTokens: Int, temperature: Double, completion: @escaping (Result<String, Error>) -> Void) {
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        guard let apiKey = getAPIKey(), !apiKey.isEmpty, !forceGateway else {
            // Fallback/force: usa Cloudflare Gateway con formato OpenAI-compatibile
            let openAIMessages: [OpenAIMessage] = messages.map { msg in
                let text = msg.content.map { $0.text }.joined(separator: "\n\n")
                return OpenAIMessage(role: msg.role, content: text)
            }
            Task {
                do {
                    let text = try await CloudflareGatewayClient.shared.sendChat(
                        messages: openAIMessages,
                        model: model,
                        maxTokens: maxTokens == 0 ? nil : maxTokens,
                        temperature: temperature == 0 ? nil : temperature
                    )
                    DispatchQueue.main.async { completion(.success(text)) }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
            return
        }
        
        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Imposta un default sicuro per max_tokens (> 0) se non configurato
        let safeMaxTokens = maxTokens > 0 ? maxTokens : 1024

        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: safeMaxTokens,
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
                
                // Parse thinking for reasoning models
                let thinkingResponse = ThinkingManager.shared.parseResponse(responseText, model: model)
                
                DispatchQueue.main.async {
                    completion(.success(thinkingResponse.finalAnswer))
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
            return AIModelInfo(name: "Claude 4 Opus", description: "Il modello più potente di Anthropic per compiti complessi (Maggio 2025)", contextTokens: 200000, supportsStreaming: true)
        case "claude-sonnet-4-20250514":
            return AIModelInfo(name: "Claude 4 Sonnet", description: "High performance, bilanciamento ottimo per produzione (Maggio 2025)", contextTokens: 200000, supportsStreaming: true)
        case "claude-3-7-sonnet-20250219":
            return AIModelInfo(name: "Claude 3.7 Sonnet", description: "Primo modello hybrid reasoning con pensiero esteso (Feb 2025)", contextTokens: 200000, supportsStreaming: true)
        case "claude-3-5-sonnet-20241022":
            return AIModelInfo(name: "Claude 3.5 Sonnet", description: "Bilanciamento perfetto tra intelligenza e velocità", contextTokens: 200000, supportsStreaming: true)
        case "claude-3-5-haiku-20241022":
            return AIModelInfo(name: "Claude 3.5 Haiku", description: "Velocità ultra-rapida per compiti leggeri ed economici", contextTokens: 200000, supportsStreaming: true)
        case "claude-3-opus-20240229":
            return AIModelInfo(name: "Claude 3 Opus", description: "Modello legacy avanzato per ragionamento complesso", contextTokens: 200000, supportsStreaming: true)
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
