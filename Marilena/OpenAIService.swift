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

class OpenAIService {
    static let shared = OpenAIService()
    
    public init() {}
    
    private lazy var responsesClient = OpenAIResponsesClient(
        apiKeyProvider: { KeychainManager.shared.load(key: "openai_api_key") },
        forceGatewayFlag: { UserDefaults.standard.bool(forKey: "force_gateway") }
    )
    
    private var useResponsesAPI: Bool {
        UserDefaults.standard.bool(forKey: "use_responses_api")
    }

    func sendMessage(messages: [OpenAIMessage], model: String, completion: @escaping (Result<String, Error>) -> Void) {
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let hasAPIKey = (KeychainManager.shared.load(key: "openai_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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
        request.setValue("Bearer \(KeychainManager.shared.load(key: "openai_api_key") ?? "")", forHTTPHeaderField: "Authorization")
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
}

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
