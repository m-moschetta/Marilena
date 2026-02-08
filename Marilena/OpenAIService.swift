import Foundation

public struct OpenAIMessage: Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let max_tokens: Int
    let temperature: Double
}

struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: OpenAIMessage
    }
}

// MARK: - OpenAI Service (unified legacy + modern)

class OpenAIService: AIServiceProtocol {
    static let shared = OpenAIService()

    public init() {}

    private lazy var responsesClient = OpenAIResponsesClient(
        apiKeyProvider: { KeychainManager.shared.load(key: "openai_api_key") },
        forceGatewayFlag: { UserDefaults.standard.bool(forKey: "force_gateway") }
    )

    private var useResponsesAPI: Bool {
        UserDefaults.standard.bool(forKey: "use_responses_api")
    }

    private var apiKey: String {
        KeychainManager.shared.load(key: "openai_api_key") ?? ""
    }

    // MARK: - Legacy callback API (used by 7 existing consumers)

    func sendMessage(messages: [OpenAIMessage], model: String, completion: @escaping (Result<String, Error>) -> Void) {
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let hasAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let resolvedTemperature = UserDefaults.standard.double(forKey: "temperature") != 0 ? UserDefaults.standard.double(forKey: "temperature") : 0.7
        let resolvedMaxTokens = Int(UserDefaults.standard.double(forKey: "max_tokens") != 0 ? UserDefaults.standard.double(forKey: "max_tokens") : 1000)
        if (forceGateway || !hasAPIKey) && !useResponsesAPI {
            Task {
                do {
                    let text = try await CloudflareGatewayClient.shared.sendChat(
                        messages: messages,
                        model: model,
                        maxTokens: resolvedMaxTokens,
                        temperature: resolvedTemperature
                    )
                    DispatchQueue.main.async { completion(.success(text)) }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
            return
        }

        if useResponsesAPI {
            Task {
                do {
                    let request = AIStreamingRequest(
                        messages: messages.map { AIMessage(role: $0.role, content: $0.content) },
                        model: model,
                        maxTokens: resolvedMaxTokens == 0 ? nil : resolvedMaxTokens,
                        temperature: resolvedTemperature,
                        provider: .openai
                    )
                    let completionResult = try await responsesClient.complete(for: request)
                    DispatchQueue.main.async {
                        completion(.success(completionResult.text))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
            return
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let temperature = resolvedTemperature
        let maxTokens = resolvedMaxTokens

        let requestBody = OpenAIRequest(
            model: model,
            messages: messages,
            max_tokens: maxTokens,
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
                    completion(.failure(OpenAIError.noData))
                }
                return
            }

            do {
                let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                let responseText = openAIResponse.choices.first?.message.content ?? "Nessuna risposta"
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

    func streamMessage(
        messages: [OpenAIMessage],
        model: String,
        onChunk: @escaping (String) -> Void,
        onToolCallDelta: ((AIToolCallDelta) -> Void)? = nil,
        onUsageDelta: ((AIUsageDelta) -> Void)? = nil,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let resolvedTemperature = UserDefaults.standard.double(forKey: "temperature") != 0 ? UserDefaults.standard.double(forKey: "temperature") : 0.7
        let resolvedMaxTokens = Int(UserDefaults.standard.double(forKey: "max_tokens") != 0 ? UserDefaults.standard.double(forKey: "max_tokens") : 1000)

        if useResponsesAPI {
            let request = AIStreamingRequest(
                messages: messages.map { AIMessage(role: $0.role, content: $0.content) },
                model: model,
                maxTokens: resolvedMaxTokens == 0 ? nil : resolvedMaxTokens,
                temperature: resolvedTemperature,
                provider: .openai
            )
            let stream = responsesClient.streamResponses(for: request)
            Task {
                do {
                    for try await chunk in stream {
                        if !chunk.textDelta.isEmpty {
                            onChunk(chunk.textDelta)
                        }
                        if let toolDelta = chunk.toolCallDelta {
                            onToolCallDelta?(toolDelta)
                        }
                        if let usage = chunk.usageDelta {
                            onUsageDelta?(usage)
                        }
                    }
                    onComplete()
                } catch {
                    onError(error)
                }
            }
            return
        }

        let stream = CloudflareGatewayClient.shared.streamChat(
            messages: messages,
            model: model,
            maxTokens: resolvedMaxTokens == 0 ? nil : resolvedMaxTokens,
            temperature: resolvedTemperature
        )
        Task {
            do {
                for try await delta in stream {
                    onChunk(delta)
                }
                onComplete()
            } catch {
                onError(error)
            }
        }
    }

    // MARK: - AIServiceProtocol (async/await, used by AICoordinator)

    func sendMessage(_ request: AIRequest) async throws -> AIResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
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

// MARK: - Errors

enum OpenAIError: Error, LocalizedError {
    case noAPIKey
    case noData

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API Key OpenAI non configurata"
        case .noData:
            return "Nessun dato ricevuto da OpenAI"
        }
    }
}

// MARK: - Shared OpenAI Models (used by ModernXAIService etc.)

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
