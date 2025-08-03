import Foundation

// MARK: - AI Service Protocol
protocol AIServiceProtocol {
    func sendMessage(_ request: AIRequest) async throws -> AIResponse
    func sendStreamMessage(_ request: AIRequest) -> AsyncThrowingStream<AIStreamResponse, Error>
}

// MARK: - AI Models
struct AIRequest: Codable {
    let messages: [AIMessage]
    let model: String
    let maxTokens: Int
    let temperature: Double
    
    init(messages: [AIMessage], model: String, maxTokens: Int = 1000, temperature: Double = 0.7) {
        self.messages = messages
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

struct AIMessage: Codable {
    let role: String
    let content: String
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

struct AIResponse: Codable {
    let content: String
    let usage: AIUsage?
    let model: String
}

struct AIStreamResponse: Codable {
    let content: String
    let isComplete: Bool
}

struct AIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
} 