import Foundation
import Combine

// MARK: - Modern xAI Service
class ModernXAIService: AIServiceProtocol {
    private let networkService: NetworkService
    private let apiKey: String

    init(networkService: NetworkService = .shared, apiKey: String) {
        self.networkService = networkService
        self.apiKey = apiKey
    }

    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        // Fallback se manca la API key
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            throw NSError(domain: "ModernXAIService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "API key xAI mancante"])
        }

        #if DEBUG
        print("🔑 xAI API Key length: \(trimmedKey.count)")
        print("🔑 xAI API Key prefix: \(String(trimmedKey.prefix(8)))...")
        #endif

        // Validazione modello xAI - assicuriamoci che il modello sia valido per xAI
        if !isValidXAIModel(request.model) {
            throw NSError(domain: "ModernXAIService", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Modello '\(request.model)' non supportato da xAI. Utilizzare modelli grok-*"])
        }

        // xAI usa lo stesso formato di OpenAI per le richieste ma richiede stream: false esplicitamente
        let mappedModel = mapToXAIModel(request.model)

        #if DEBUG
        print("🔄 xAI Model Mapping: '\(request.model)' -> '\(mappedModel)'")
        #endif

        let supportsPenalties = mappedModel.lowercased().contains("grok-3")

        let xaiRequest = XAIChatRequest(
            model: mappedModel,
            messages: request.messages.map { OpenAIChatMessage(role: $0.role, content: $0.content) },
            max_tokens: request.maxTokens,
            temperature: request.temperature,
            stream: false,  // xAI richiede esplicitamente questo parametro
            top_p: 1.0,
            frequency_penalty: supportsPenalties ? 0.0 : nil,
            presence_penalty: supportsPenalties ? 0.0 : nil
        )

        let endpoint = APIEndpoint(
            url: URL(string: "https://api.x.ai/v1/chat/completions")!,
            method: .post,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ],
            body: try JSONEncoder().encode(xaiRequest)
        )

        #if DEBUG
        print("🚀 xAI Request - Model: \(request.model)")
        print("🚀 xAI Request - Messages: \(request.messages.count)")
        print("🚀 xAI Request - URL: \(endpoint.url)")

        // Log del JSON della richiesta
        if let jsonData = endpoint.body,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🚀 xAI Request JSON: \(jsonString)")
        }
        #endif

        let response: OpenAIChatResponse
        do {
            response = try await networkService.request(endpoint)
        } catch {
            // Gestione errori specifici per xAI
            #if DEBUG
            print("❌ xAI Error: \(error)")
            print("❌ xAI Error Type: \(type(of: error))")

            // Gestione specifica per NetworkError con dati di risposta
            if let networkError = error as? NetworkError {
                print("✅ Detected NetworkError!")
                switch networkError {
                case .httpError(let statusCode, let data):
                    print("❌ xAI HTTP Error \(statusCode) with \(data.count) bytes of data")
                    let responseString = String(data: data, encoding: .utf8) ?? "Cannot decode response"
                    print("❌ xAI Response Body: \(responseString)")

                    if statusCode == 400 {
                        throw NSError(domain: "ModernXAIService", code: 400,
                                     userInfo: [NSLocalizedDescriptionKey: "Richiesta xAI non valida: \(responseString)"])
                    } else if statusCode == 401 {
                        throw NSError(domain: "ModernXAIService", code: 401,
                                     userInfo: [NSLocalizedDescriptionKey: "API key xAI non valida o scaduta"])
                    } else if statusCode == 429 {
                        throw NSError(domain: "ModernXAIService", code: 429,
                                     userInfo: [NSLocalizedDescriptionKey: "Limite di rate raggiunti per xAI"])
                    }
                default:
                    print("❌ xAI Network Error: \(networkError)")
                }
            } else {
                // Try to extract error info even if it's not NetworkError
                print("⚠️ Not a NetworkError, trying to extract info...")
                let nsError = error as NSError
                print("❌ xAI NSError Code: \(nsError.code)")
                print("❌ xAI NSError Description: \(nsError.localizedDescription)")
                print("❌ xAI NSError UserInfo: \(nsError.userInfo)")

                // Check for error description that might contain our data
                if nsError.localizedDescription.contains("httpError") {
                    print("⚠️ Contains httpError - this should be a NetworkError!")
                }
            }
            #endif

            throw error
        }

        #if DEBUG
        print("✅ xAI Response - Choices: \(response.choices.count)")
        print("✅ xAI Response - Model: \(response.model)")
        #endif

        guard let choice = response.choices.first else {
            throw NSError(domain: "ModernXAIService", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Nessuna risposta ricevuta da xAI"])
        }

        let usage = AIUsage(
            promptTokens: response.usage?.prompt_tokens ?? 0,
            completionTokens: response.usage?.completion_tokens ?? 0,
            totalTokens: response.usage?.total_tokens ?? 0
        )

        return AIResponse(
            content: choice.message.content,
            usage: usage,
            model: response.model
        )
    }

    func sendStreamMessage(_ request: AIRequest) -> AsyncThrowingStream<AIStreamResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Per ora implementiamo una versione non-streaming
                    // In futuro possiamo aggiungere supporto per lo streaming
                    let response = try await sendMessage(request)
                    continuation.yield(AIStreamResponse(content: response.content, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - xAI Specific Structures
// xAI richiede alcuni parametri aggiuntivi rispetto a OpenAI

struct XAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let max_tokens: Int
    let temperature: Double
    let stream: Bool
    let top_p: Double?
    let frequency_penalty: Double?
    let presence_penalty: Double?

    init(
        model: String,
        messages: [OpenAIChatMessage],
        max_tokens: Int,
        temperature: Double,
        stream: Bool = false,
        top_p: Double? = nil,
        frequency_penalty: Double? = nil,
        presence_penalty: Double? = nil
    ) {
        self.model = model
        self.messages = messages
        self.max_tokens = max_tokens
        self.temperature = temperature
        self.stream = stream
        self.top_p = top_p
        self.frequency_penalty = frequency_penalty
        self.presence_penalty = presence_penalty
    }
}

// MARK: - Extension for Model Validation and Testing
extension ModernXAIService {
    private func isValidXAIModel(_ model: String) -> Bool {
        // xAI usa modelli che iniziano con "grok-"
        return model.lowercased().hasPrefix("grok-") ||
               model.lowercased().contains("grok")
    }

    private func mapToXAIModel(_ model: String) -> String {
        // Mappa i nostri nomi modello a quelli ufficiali xAI se necessario
        let lowercased = model.lowercased()

        // Normalizza alcuni nomi comuni
        // Nota: grok-beta è stato deprecato il 2025-09-15, ora usare grok-3
        switch lowercased {
        case "grok-4-latest", "grok-4":
            return "grok-3"  // Usa il modello attualmente disponibile
        case "grok-4-fast":
            return "grok-3"  // Usa il modello attualmente disponibile
        case "grok-4-fast-non-reasoning-latest":
            return "grok-3"  // Versione non-reasoning, usa modello base
        case "grok-4-fast-reasoning-latest":
            return "grok-3"  // Versione reasoning, usa modello base per ora
        case "grok-code-fast-1":
            return "grok-3"  // Modello per codice, usa modello base per ora
        case "grok-3":
            return "grok-3"  // Usa il nome ufficiale
        case "grok-beta":
            return "grok-3"  // grok-beta deprecato, fallback a grok-3
        default:
            return model  // Usa il nome originale
        }
    }

    #if DEBUG
    /// Test function per verificare la connessione xAI
    func testXAIConnection() async throws -> String {
        let testRequest = AIRequest(
            messages: [AIMessage(role: "user", content: "Test connection - rispondi solo 'OK'")],
            model: "grok-4-latest",
            maxTokens: 10,
            temperature: 0.1
        )

        let response = try await sendMessage(testRequest)
        return response.content
    }
    #endif
}
