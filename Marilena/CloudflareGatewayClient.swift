import Foundation

// MARK: - Cloudflare Gateway Client
// Fallback client per instradare le chiamate al Cloudflare Worker
// quando le API key dei provider non sono configurate nelle impostazioni.

final class CloudflareGatewayClient {
    static let shared = CloudflareGatewayClient()
    private init() {}

    private let baseURL = "https://llm-proxy-gateway.mariomos94.workers.dev"
    private let session = URLSession.shared

    // MARK: - Request/Response models (OpenAI-compatibili)
    private struct ChatRequest: Codable {
        let model: String
        let messages: [OpenAIMessage]
        let max_tokens: Int?
        let temperature: Double?
        let stream: Bool?

        init(model: String, messages: [OpenAIMessage], max_tokens: Int?, temperature: Double?, stream: Bool? = nil) {
            self.model = model
            self.messages = messages
            self.max_tokens = max_tokens
            self.temperature = temperature
            self.stream = stream
        }
    }

    private struct ChatResponse: Codable {
        struct Choice: Codable { let message: OpenAIMessage? }
        let choices: [Choice]
    }

    // MARK: - API
    func sendChat(
        messages: [OpenAIMessage],
        model: String,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw CloudflareGatewayError.invalidURL
        }

        let payload = ChatRequest(
            model: model,
            messages: messages,
            max_tokens: maxTokens,
            temperature: temperature
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        if let provider = detectProvider(for: model) {
            req.setValue(provider, forHTTPHeaderField: "x-provider")
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw CloudflareGatewayError.invalidResponse }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw CloudflareGatewayError.http(status: http.statusCode, body: "model=\(model) provider=\(detectProvider(for: model) ?? "?") body=\(body)")
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message?.content, !content.isEmpty else {
            throw CloudflareGatewayError.emptyResponse
        }
        return content
    }

    // MARK: - Streaming (SSE)
    struct StreamChunk: Codable {
        struct Choice: Codable { let delta: OpenAIMessage? }
        let choices: [Choice]
    }

    // Versione AsyncThrowingStream: restituisce chunk di testo incrementali
    func streamChat(
        messages: [OpenAIMessage],
        model: String,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
                        throw CloudflareGatewayError.invalidURL
                    }

                    // Richiesta con stream abilitato
                    let payload = ChatRequest(
                        model: model,
                        messages: messages,
                        max_tokens: maxTokens,
                        temperature: temperature,
                        stream: true
                    )

                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue("keep-alive", forHTTPHeaderField: "Connection")
                    req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                    req.httpBody = try JSONEncoder().encode(payload)
                    if let provider = detectProvider(for: model) {
                        req.setValue(provider, forHTTPHeaderField: "x-provider")
                    }

                    let (bytes, response) = try await session.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw CloudflareGatewayError.sseHTTP(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
                    }

                    for try await line in bytes.lines {
                        // SSE lines: "data: {json}" oppure "data: [DONE]"
                        guard line.hasPrefix("data:") else { continue }
                        let dataPart = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                        if dataPart == "[DONE]" {
                            continuation.finish()
                            break
                        }
                        if let jsonData = dataPart.data(using: .utf8) {
                            if let chunk = try? JSONDecoder().decode(StreamChunk.self, from: jsonData),
                               let delta = chunk.choices.first?.delta?.content,
                               !delta.isEmpty {
                                continuation.yield(delta)
                            }
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // Versione con callback, utile per UI legacy
    func streamChat(
        messages: [OpenAIMessage],
        model: String,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        Task {
            do {
                let stream = streamChat(
                    messages: messages,
                    model: model,
                    maxTokens: maxTokens,
                    temperature: temperature
                )
                for try await part in stream {
                    DispatchQueue.main.async { onChunk(part) }
                }
                DispatchQueue.main.async { onComplete() }
            } catch {
                DispatchQueue.main.async { onError(error) }
            }
        }
    }

    // MARK: - Provider Detection
    private func detectProvider(for model: String) -> String? {
        let m = model.lowercased()
        if m.contains("claude") { return "anthropic" }
        if m.contains("mistral") { return "mistral" }
        if m.hasPrefix("gpt-") || m.contains("chatgpt") || m.hasPrefix("o1") || m.hasPrefix("o3") { return "openai" }
        // Groq: escludi ID in formato namespace (con "/") che non sono supportati da Groq
        if (m.contains("llama") || m.contains("mixtral") || m.contains("gemma") || m.contains("qwen") || m.contains("deepseek")) && !m.contains("/") {
            return "groq"
        }
        return nil
    }

    // MARK: - Error Type
    enum CloudflareGatewayError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case http(status: Int, body: String)
        case sseHTTP(status: Int)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Gateway: URL non valido"
            case .invalidResponse:
                return "Gateway: risposta non valida"
            case .http(let status, let body):
                return "Gateway HTTP \(status): \(body)"
            case .sseHTTP(let status):
                return "Gateway streaming HTTP \(status)"
            case .emptyResponse:
                return "Gateway: risposta vuota"
            }
        }
    }
}
