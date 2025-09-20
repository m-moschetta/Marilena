import Foundation
import Combine

// MARK: - Modern OpenAI Service
class ModernOpenAIService: AIServiceProtocol {
    private let networkService: NetworkService
    private let apiKey: String
    private lazy var responsesClient = OpenAIResponsesClient(
        apiKeyProvider: { [weak self] in self?.apiKey },
        forceGatewayFlag: { UserDefaults.standard.bool(forKey: "force_gateway") }
    )
    
    init(networkService: NetworkService = .shared, apiKey: String) {
        self.networkService = networkService
        self.apiKey = apiKey
    }
    
    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let useResponsesAPI = UserDefaults.standard.bool(forKey: "use_responses_api")
        let effectiveMaxTokens = request.maxTokens == 0 ? nil : request.maxTokens
        let effectiveTemperature = request.temperature

        if useResponsesAPI && !trimmedKey.isEmpty && !forceGateway {
            let streamingRequest = AIStreamingRequest(
                messages: request.messages,
                model: request.model,
                maxTokens: effectiveMaxTokens,
                temperature: effectiveTemperature,
                provider: .openai
            )
            let completion = try await responsesClient.complete(for: streamingRequest)
            return AIResponse(
                content: completion.text,
                usage: completion.usage,
                model: completion.provider?.rawValue ?? request.model
            )
        }

        let openAIMessages = request.messages.map { OpenAIMessage(role: $0.role, content: $0.content) }
        let text = try await CloudflareGatewayClient.shared.sendChat(
            messages: openAIMessages,
            model: request.model,
            maxTokens: effectiveMaxTokens,
            temperature: effectiveTemperature
        )
        return AIResponse(
            content: text,
            usage: nil,
            model: request.model
        )
    }
    
    func sendStreamMessage(_ request: AIRequest) -> AsyncThrowingStream<AIStreamResponse, Error> {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let useResponsesAPI = UserDefaults.standard.bool(forKey: "use_responses_api")
        let effectiveMaxTokens = request.maxTokens == 0 ? nil : request.maxTokens
        let effectiveTemperature = request.temperature

        if useResponsesAPI && !trimmedKey.isEmpty && !forceGateway {
            let streamingRequest = AIStreamingRequest(
                messages: request.messages,
                model: request.model,
                maxTokens: effectiveMaxTokens,
                temperature: effectiveTemperature,
                provider: .openai
            )
            let chunkStream = responsesClient.streamResponses(for: streamingRequest)
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        for try await chunk in chunkStream {
                            if !chunk.textDelta.isEmpty {
                                continuation.yield(AIStreamResponse(content: chunk.textDelta, isComplete: false))
                            }
                        }
                        continuation.yield(AIStreamResponse(content: "", isComplete: true))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }

        let openAIMessages = request.messages.map { OpenAIMessage(role: $0.role, content: $0.content) }
        let stream = CloudflareGatewayClient.shared.streamChat(
            messages: openAIMessages,
            model: request.model,
            maxTokens: effectiveMaxTokens,
            temperature: effectiveTemperature
        )
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await delta in stream {
                        continuation.yield(AIStreamResponse(content: delta, isComplete: false))
                    }
                    continuation.yield(AIStreamResponse(content: "", isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Request/Response Models
struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let max_tokens: Int
    let temperature: Double
    let stream: Bool?
    
    init(model: String, messages: [OpenAIChatMessage], max_tokens: Int, temperature: Double, stream: Bool = false) {
        self.model = model
        self.messages = messages
        self.max_tokens = max_tokens
        self.temperature = temperature
        self.stream = stream
    }
}

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIChatMessage
    let finish_reason: String?
}

struct OpenAIUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

// MARK: - AI Service Error
enum AIServiceError: Error, LocalizedError {
    case noResponse
    case invalidRequest
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "Nessuna risposta ricevuta"
        case .invalidRequest:
            return "Richiesta non valida"
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        }
    }
} 
