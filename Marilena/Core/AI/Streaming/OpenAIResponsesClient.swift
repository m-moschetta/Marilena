import Foundation

final class OpenAIResponsesClient: AIStreamingClientProtocol {
    private let apiKeyProvider: () -> String?
    private let urlSession: URLSession
    private let forceGatewayFlag: () -> Bool
    
    init(
        apiKeyProvider: @escaping () -> String?,
        urlSession: URLSession = .shared,
        forceGatewayFlag: @escaping () -> Bool = { UserDefaults.standard.bool(forKey: "force_gateway") }
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.urlSession = urlSession
        self.forceGatewayFlag = forceGatewayFlag
    }
    
    // MARK: - AIStreamingClientProtocol
    func streamResponses(for request: AIStreamingRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        if shouldUseGateway(for: request) {
            return gatewayStream(for: request)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlRequest = try buildStreamingURLRequest(for: request)
                    let (bytes, response) = try await urlSession.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OpenAIResponsesError.invalidHTTPResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw OpenAIResponsesError.httpStatus(httpResponse.statusCode)
                    }
                    
                    var currentEvent: String?
                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            currentEvent = line.replacingOccurrences(of: "event:", with: "").trimmingCharacters(in: .whitespaces)
                            continue
                        }
                        
                        guard line.hasPrefix("data:") else { continue }
                        let dataString = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                        if dataString == "[DONE]" {
                            continuation.finish()
                            break
                        }
                        guard let jsonData = dataString.data(using: .utf8) else { continue }
                        let eventType = currentEvent
                        let chunks = try parseStreamEvents(data: jsonData, explicitEventType: eventType)
                        for chunk in chunks where !chunk.isEmpty {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func complete(for request: AIStreamingRequest) async throws -> AIStreamingCompletion {
        if shouldUseGateway(for: request) {
            return try await gatewayComplete(for: request)
        }
        
        let urlRequest = try buildCompletionURLRequest(for: request)
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIResponsesError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIResponsesError.httpStatusWithBody(code: httpResponse.statusCode, body: body)
        }
        
        let completion = try JSONDecoder().decode(OpenAIResponsesCompletionEnvelope.self, from: data)
        return completion.toStreamingCompletion(provider: request.provider ?? .openai)
    }
    
    // MARK: - Helpers
    private func shouldUseGateway(for request: AIStreamingRequest) -> Bool {
        let apiKey = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return apiKey.isEmpty || forceGatewayFlag()
    }
    
    private func gatewayStream(for request: AIStreamingRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        let openAIMessages = request.messages.map { OpenAIMessage(role: $0.role, content: $0.content) }
        let stream = CloudflareGatewayClient.shared.streamChat(
            messages: openAIMessages,
            model: request.model,
            maxTokens: request.maxTokens,
            temperature: request.temperature
        )
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await delta in stream {
                        let chunk = AIStreamChunk(
                            textDelta: delta,
                            provider: .openai
                        )
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func gatewayComplete(for request: AIStreamingRequest) async throws -> AIStreamingCompletion {
        let openAIMessages = request.messages.map { OpenAIMessage(role: $0.role, content: $0.content) }
        let text = try await CloudflareGatewayClient.shared.sendChat(
            messages: openAIMessages,
            model: request.model,
            maxTokens: request.maxTokens,
            temperature: request.temperature
        )
        return AIStreamingCompletion(
            text: text,
            finishReason: nil,
            usage: nil,
            toolCalls: nil,
            provider: .openai
        )
    }
    
    private func buildStreamingURLRequest(for request: AIStreamingRequest) throws -> URLRequest {
        var urlRequest = try buildBaseURLRequest(for: request)
        let payload = try makePayload(for: request, stream: true)
        urlRequest.httpBody = payload
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("keep-alive", forHTTPHeaderField: "Connection")
        return urlRequest
    }
    
    private func buildCompletionURLRequest(for request: AIStreamingRequest) throws -> URLRequest {
        var urlRequest = try buildBaseURLRequest(for: request)
        urlRequest.httpBody = try makePayload(for: request, stream: false)
        return urlRequest
    }
    
    private func buildBaseURLRequest(for request: AIStreamingRequest) throws -> URLRequest {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw OpenAIResponsesError.missingAPIKey
        }
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw OpenAIResponsesError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return urlRequest
    }
    
    private func makePayload(for request: AIStreamingRequest, stream: Bool) throws -> Data {
        let payload = OpenAIResponsesRequestPayload(
            model: request.model,
            input: request.messages.map { OpenAIResponsesRequestPayload.Message(message: $0) },
            temperature: request.temperature,
            maxOutputTokens: request.maxTokens,
            metadata: request.metadata.isEmpty ? nil : request.metadata,
            stream: stream
        )
        return try JSONEncoder().encode(payload)
    }
    
    private func parseStreamEvents(data: Data, explicitEventType: String?) throws -> [AIStreamChunk] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        let eventType = explicitEventType ?? (json["type"] as? String)
        switch eventType {
        case "response.output_text.delta":
            let text = extractOutputTextDelta(from: json)
            guard !text.isEmpty else { return [] }
            return [AIStreamChunk(textDelta: text, provider: .openai, rawEvent: data)]
        case "response.tool_calls.delta":
            return extractToolCallDeltas(from: json, completed: false, raw: data)
        case "response.tool_calls.done":
            return extractToolCallDeltas(from: json, completed: true, raw: data)
        case "response.delta":
            if let usageDelta = extractUsageDelta(from: json) {
                return [AIStreamChunk(
                    textDelta: "",
                    finishReason: nil,
                    usageDelta: usageDelta,
                    provider: .openai,
                    rawEvent: data
                )]
            }
            return []
        case "response.output_text.done":
            return []
        case "response.completed":
            if let response = json["response"] as? [String: Any] {
                let completion = OpenAIResponsesCompletionEnvelope(json: response).toStreamingCompletion(provider: .openai)
                return [AIStreamChunk(
                    textDelta: "",
                    finishReason: completion.finishReason,
                    usageDelta: completion.usage.map { AIUsageDelta(promptTokens: $0.promptTokens, completionTokens: $0.completionTokens, totalTokens: $0.totalTokens) },
                    provider: .openai,
                    rawEvent: data
                )]
            }
            return []
        case "response.error":
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                throw OpenAIResponsesError.apiError(message)
            }
            return []
        default:
            return []
        }
    }

    private func extractOutputTextDelta(from json: [String: Any]) -> String {
        guard let delta = json["delta"] as? [String: Any] else { return "" }
        if let text = delta["output_text_delta"] as? String {
            return text
        }
        if let outputArray = delta["output_text"] as? [[String: Any]] {
            return outputArray.compactMap { $0["text"] as? String }.joined()
        }
        if let text = delta["content"] as? String {
            return text
        }
        return ""
    }

    private func extractToolCallDeltas(from json: [String: Any], completed: Bool, raw: Data) -> [AIStreamChunk] {
        guard let delta = json["delta"] as? [String: Any],
              let toolCalls = delta["tool_calls"] as? [[String: Any]] else {
            return []
        }

        return toolCalls.enumerated().map { index, call in
            let id = call["id"] as? String
            var name: String?
            var argumentsDelta = ""

            if let function = call["function"] as? [String: Any] {
                name = function["name"] as? String
                if let deltaArgs = function["arguments_delta"] as? String {
                    argumentsDelta = deltaArgs
                } else if let fullArgs = function["arguments"] as? String {
                    argumentsDelta = fullArgs
                }
            }

            let toolCallDelta = AIToolCallDelta(
                index: call["index"] as? Int ?? index,
                id: id,
                name: name,
                argumentsDelta: argumentsDelta,
                isCompleted: completed
            )

            return AIStreamChunk(
                textDelta: "",
                finishReason: nil,
                usageDelta: nil,
                toolCallDelta: toolCallDelta,
                provider: .openai,
                rawEvent: raw
            )
        }
    }

    private func extractUsageDelta(from json: [String: Any]) -> AIUsageDelta? {
        guard let delta = json["delta"] as? [String: Any],
              let usage = delta["usage"] as? [String: Any] else {
            return nil
        }

        let prompt = usage["prompt_tokens"] as? Int
        let completion = usage["completion_tokens"] as? Int
        let total = usage["total_tokens"] as? Int
        if prompt == nil && completion == nil && total == nil {
            return nil
        }
        return AIUsageDelta(promptTokens: prompt, completionTokens: completion, totalTokens: total)
    }
}

// MARK: - Payloads
private struct OpenAIResponsesRequestPayload: Encodable {
    struct Message: Encodable {
        struct Content: Encodable {
            let type: String
            let text: String
        }
        let role: String
        let content: [Content]

        init(message: AIMessage) {
            self.role = message.role
            self.content = [Content(type: "input_text", text: message.content)]
        }

        init(_ message: AIMessage) { self.init(message: message) }
    }
    
    let model: String
    let input: [Message]
    let temperature: Double?
    let maxOutputTokens: Int?
    let metadata: [String: String]?
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model
        case input
        case temperature
        case maxOutputTokens = "max_output_tokens"
        case metadata
        case stream
    }
}

// MARK: - Stream Event Envelope
private struct OpenAIStreamEventEnvelope: Decodable {
    let type: String
    let delta: String?
    let response: OpenAIResponsesCompletionEnvelope?
    let error: OpenAIResponsesErrorPayload?
    
    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case response
        case error
    }
    
    var responseDelta: String? {
        if let response = response {
            return response.outputText
        }
        return nil
    }
}

private struct OpenAIResponsesErrorPayload: Decodable {
    let message: String
}

// MARK: - Completion Envelope
private struct OpenAIResponsesCompletionEnvelope: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let type: String
            let text: String?
        }
        let role: String?
        let content: [Content]

        init(json: [String: Any]) {
            self.role = json["role"] as? String
            if let contents = json["content"] as? [[String: Any]] {
                self.content = contents.map { contentDict in
                    let type = contentDict["type"] as? String ?? ""
                    let text = contentDict["text"] as? String
                    return Content(type: type, text: text)
                }
            } else {
                self.content = []
            }
        }
    }
    
    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }

        init(promptTokens: Int?, completionTokens: Int?, totalTokens: Int?) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
        }
    }
    
    let id: String
    let output: [Output]
    let usage: Usage?
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case output
        case usage
        case finishReason = "finish_reason"
    }
    
    var outputText: String {
        output.flatMap { $0.content }.compactMap { content in
            content.type == "output_text" ? content.text : nil
        }.joined()
    }
    
    func toStreamingCompletion(provider: AIModelProvider) -> AIStreamingCompletion {
        return AIStreamingCompletion(
            text: outputText,
            finishReason: finishReason,
            usage: usage.map { AIUsage(
                promptTokens: $0.promptTokens ?? 0,
                completionTokens: $0.completionTokens ?? 0,
                totalTokens: $0.totalTokens ?? 0
            )},
            toolCalls: nil,
            provider: provider
        )
    }

    init(json: [String: Any]) {
        self.id = json["id"] as? String ?? ""
        if let outputs = json["output"] as? [[String: Any]] {
            self.output = outputs.map { Output(json: $0) }
        } else {
            self.output = []
        }
        if let usageDict = json["usage"] as? [String: Any] {
            self.usage = Usage(
                promptTokens: usageDict["prompt_tokens"] as? Int,
                completionTokens: usageDict["completion_tokens"] as? Int,
                totalTokens: usageDict["total_tokens"] as? Int
            )
        } else {
            self.usage = nil
        }
        self.finishReason = json["finish_reason"] as? String
    }
}

// MARK: - Errors
enum OpenAIResponsesError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidHTTPResponse
    case httpStatus(Int)
    case httpStatusWithBody(code: Int, body: String)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key OpenAI non configurata"
        case .invalidURL:
            return "URL OpenAI Responses non valido"
        case .invalidHTTPResponse:
            return "Risposta HTTP non valida"
        case .httpStatus(let code):
            return "Errore HTTP OpenAI Responses: \(code)"
        case .httpStatusWithBody(let code, let body):
            return "Errore HTTP OpenAI Responses: \(code) - \(body)"
        case .apiError(let message):
            return message
        }
    }
}
