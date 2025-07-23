import Foundation

// MARK: - Perplexity API Models

struct PerplexityRequest: Codable {
    let model: String
    let messages: [PerplexityMessage]
    let maxTokens: Int?
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    let stream: Bool?
    let presencePenalty: Double?
    let frequencyPenalty: Double?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case topK = "top_k"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
    }
}

struct PerplexityMessage: Codable {
    let role: String
    let content: String
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

struct PerplexityResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [PerplexityChoice]
    let usage: PerplexityUsage
}

struct PerplexityChoice: Codable {
    let index: Int
    let message: PerplexityMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct PerplexityUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Perplexity Service

class PerplexityService {
    static let shared = PerplexityService()
    
    private let baseURL = "https://api.perplexity.ai"
    private let defaultModel = "sonar-pro"
    
    // Modelli supportati da Perplexity
    static let supportedModels = [
        // Sonar Online
        "sonar-pro", "llama-sonar-huge-online", "llama-sonar-large-online",
        // Sonar Specializzati
        "sonar-reasoning-pro", "sonar-deep-research",
        // Open-Source
        "llama-405b-instruct", "llama-70b-instruct", "mixtral-8x7b-instruct"
    ]
    
    private init() {}
    
    // MARK: - API Key Management
    
    private func getAPIKey() -> String? {
        return KeychainManager.shared.load(key: "perplexity_api_key")
    }
    
    func saveAPIKey(_ apiKey: String) -> Bool {
        return KeychainManager.shared.save(key: "perplexity_api_key", value: apiKey)
    }
    
    func hasAPIKey() -> Bool {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Search Methods
    
    func search(query: String, model: String? = nil) async throws -> String {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw PerplexityError.missingAPIKey
        }
        
        // Usa il modello specificato o quello salvato nelle impostazioni
        let selectedModel = model ?? UserDefaults.standard.string(forKey: "selected_perplexity_model") ?? defaultModel
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = selectedModel == "sonar-deep-research" ? 300 : 60
        
        let messages = [
            PerplexityMessage(role: "system", content: "Sei un assistente di ricerca esperto. Fornisci risposte accurate e aggiornate in italiano."),
            PerplexityMessage(role: "user", content: query)
        ]
        
        let requestBody = PerplexityRequest(
            model: selectedModel,
            messages: messages,
            maxTokens: selectedModel == "sonar-deep-research" ? 8000 : 2048,
            temperature: nil,
            topP: nil,
            topK: nil,
            stream: false,
            presencePenalty: nil,
            frequencyPenalty: nil
        )
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
            
            // Debug logging
            if let jsonData = request.httpBody,
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🔍 Perplexity Request JSON: \(jsonString)")
            }
        } catch {
            print("❌ Encoding error: \(error)")
            throw PerplexityError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerplexityError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Debug logging per errori
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Perplexity Error Response (\(httpResponse.statusCode)): \(responseString)")
            }
            
            if httpResponse.statusCode == 401 {
                throw PerplexityError.unauthorizedAPIKey
            } else if httpResponse.statusCode == 429 {
                throw PerplexityError.rateLimitExceeded
            } else {
                throw PerplexityError.apiError(httpResponse.statusCode)
            }
        }
        
        do {
            let perplexityResponse = try JSONDecoder().decode(PerplexityResponse.self, from: data)
            guard let choice = perplexityResponse.choices.first else {
                throw PerplexityError.noResponse
            }
            return choice.message.content
        } catch {
            throw PerplexityError.decodingError
        }
    }
    
    // MARK: - Test Connection
    
    func testConnection() async throws -> Bool {
        do {
            _ = try await search(query: "Test")
            return true
        } catch {
            throw error
        }
    }
}

// MARK: - Perplexity Errors

enum PerplexityError: LocalizedError {
    case missingAPIKey
    case unauthorizedAPIKey
    case rateLimitExceeded
    case apiError(Int)
    case encodingError
    case decodingError
    case invalidResponse
    case noResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API Key Perplexity mancante. Configurala nelle impostazioni."
        case .unauthorizedAPIKey:
            return "API Key Perplexity non valida. Verifica la chiave nelle impostazioni."
        case .rateLimitExceeded:
            return "Limite di richieste superato. Riprova tra qualche minuto."
        case .apiError(let code):
            return "Errore API Perplexity: \(code)"
        case .encodingError:
            return "Errore nella codifica della richiesta."
        case .decodingError:
            return "Errore nella decodifica della risposta."
        case .invalidResponse:
            return "Risposta non valida dal server."
        case .noResponse:
            return "Nessuna risposta ricevuta."
        }
    }
} 