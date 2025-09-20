import Foundation

struct AIStreamingRequest: Sendable {
    let messages: [AIMessage]
    let model: String
    let maxTokens: Int?
    let temperature: Double?
    let metadata: [String: String]
    let provider: AIModelProvider?
    
    init(
        messages: [AIMessage],
        model: String,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        metadata: [String: String] = [:],
        provider: AIModelProvider? = nil
    ) {
        self.messages = messages
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.metadata = metadata
        self.provider = provider
    }
}

struct AIStreamChunk: Sendable {
    let textDelta: String
    let finishReason: String?
    let usageDelta: AIUsageDelta?
    let toolCallDelta: AIToolCallDelta?
    let provider: AIModelProvider?
    let rawEvent: Data?
    
    init(
        textDelta: String,
        finishReason: String? = nil,
        usageDelta: AIUsageDelta? = nil,
        toolCallDelta: AIToolCallDelta? = nil,
        provider: AIModelProvider? = nil,
        rawEvent: Data? = nil
    ) {
        self.textDelta = textDelta
        self.finishReason = finishReason
        self.usageDelta = usageDelta
        self.toolCallDelta = toolCallDelta
        self.provider = provider
        self.rawEvent = rawEvent
    }

    var isEmpty: Bool {
        textDelta.isEmpty && finishReason == nil && usageDelta == nil && toolCallDelta == nil
    }
}

struct AIUsageDelta: Sendable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    
    init(
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

struct AIToolCallDelta: Sendable {
    let index: Int
    let id: String?
    let name: String?
    let argumentsDelta: String
    let isCompleted: Bool
    
    init(
        index: Int,
        id: String? = nil,
        name: String? = nil,
        argumentsDelta: String,
        isCompleted: Bool = false
    ) {
        self.index = index
        self.id = id
        self.name = name
        self.argumentsDelta = argumentsDelta
        self.isCompleted = isCompleted
    }
}

struct AIStreamingCompletion: Sendable {
    let text: String
    let finishReason: String?
    let usage: AIUsage?
    let toolCalls: [AIToolCall]?
    let provider: AIModelProvider?
}

struct AIToolCall: Sendable {
    let index: Int
    let id: String?
    let name: String
    let arguments: String
}

protocol AIStreamingClientProtocol: AnyObject {
    func streamResponses(
        for request: AIStreamingRequest
    ) -> AsyncThrowingStream<AIStreamChunk, Error>
    
    func complete(
        for request: AIStreamingRequest
    ) async throws -> AIStreamingCompletion
}
