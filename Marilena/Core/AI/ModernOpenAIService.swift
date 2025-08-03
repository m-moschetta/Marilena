import Foundation
import Combine

// MARK: - Modern OpenAI Service
class ModernOpenAIService: AIServiceProtocol {
    private let networkService: NetworkService
    private let apiKey: String
    
    init(networkService: NetworkService = .shared, apiKey: String) {
        self.networkService = networkService
        self.apiKey = apiKey
    }
    
    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        let openAIRequest = OpenAIChatRequest(
            model: request.model,
            messages: request.messages.map { OpenAIChatMessage(role: $0.role, content: $0.content) },
            max_tokens: request.maxTokens,
            temperature: request.temperature
        )
        
        let endpoint = APIEndpoint(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            method: .post,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ],
            body: try JSONEncoder().encode(openAIRequest)
        )
        
        let response: OpenAIChatResponse = try await networkService.request(endpoint)
        
        guard let choice = response.choices.first else {
            throw AIServiceError.noResponse
        }
        
        return AIResponse(
            content: choice.message.content,
            usage: AIUsage(
                promptTokens: response.usage?.prompt_tokens ?? 0,
                completionTokens: response.usage?.completion_tokens ?? 0,
                totalTokens: response.usage?.total_tokens ?? 0
            ),
            model: response.model
        )
    }
    
    func sendStreamMessage(_ request: AIRequest) -> AsyncThrowingStream<AIStreamResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let openAIRequest = OpenAIChatRequest(
                        model: request.model,
                        messages: request.messages.map { OpenAIChatMessage(role: $0.role, content: $0.content) },
                        max_tokens: request.maxTokens,
                        temperature: request.temperature,
                        stream: true
                    )
                    
                    let endpoint = APIEndpoint(
                        url: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        method: .post,
                        headers: [
                            "Authorization": "Bearer \(apiKey)",
                            "Content-Type": "application/json"
                        ],
                        body: try JSONEncoder().encode(openAIRequest)
                    )
                    
                    // For now, we'll use a simple approach without streaming
                    // In a real implementation, you'd need to implement streaming
                    let response: OpenAIChatResponse = try await networkService.request(endpoint)
                    
                    if let choice = response.choices.first {
                        continuation.yield(AIStreamResponse(content: choice.message.content, isComplete: true))
                    }
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