import Foundation

/// Servizio per l'integrazione con DeepSeek API
/// DeepSeek offre modelli economici e veloci per ragionamento avanzato
class DeepSeekService {
    static let shared = DeepSeekService()

    private let baseURL = "https://api.deepseek.com/v1"

    // Modelli disponibili su DeepSeek
    static let deepSeekModels = [
        "deepseek-chat",        // Modello principale per chat e ragionamento
        "deepseek-coder",       // Specializzato per generazione codice
        "deepseek-reasoner"     // Modello avanzato per ragionamento complesso
    ]

    public init() {}

    // MARK: - API Key Management

    private func getAPIKey() -> String? {
        return KeychainManager.shared.getAPIKey(for: "deepseek")
    }

    func hasAPIKey() -> Bool {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            return false
        }
        return true
    }

    // MARK: - Chat Methods

    /// Invia un messaggio usando il modello selezionato
    func sendMessage(messages: [OpenAIMessage], completion: @escaping (Result<String, Error>) -> Void) {
        let selectedModel = UserDefaults.standard.string(forKey: "selectedDeepSeekModel") ?? "deepseek-chat"
        let maxTokens = Int(UserDefaults.standard.double(forKey: "maxChatTokens"))
        let temperature = UserDefaults.standard.double(forKey: "temperature")

        sendMessage(messages: messages, model: selectedModel, maxTokens: maxTokens, temperature: temperature, completion: completion)
    }

    /// Invia un messaggio con parametri specifici
    func sendMessage(messages: [OpenAIMessage], model: String, maxTokens: Int?, temperature: Double?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(DeepSeekError.missingAPIKey))
            return
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepara il body della richiesta (formato OpenAI-compatible)
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages.map { message in
                ["role": message.role, "content": message.content]
            },
            "max_tokens": maxTokens ?? 4096,
            "temperature": temperature ?? 0.7,
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(DeepSeekError.invalidRequest))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(DeepSeekError.noData))
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    completion(.failure(DeepSeekError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        guard let apiKey = getAPIKey() else {
            throw DeepSeekError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }

        return false
    }
}

// MARK: - Error Types

enum DeepSeekError: Error, LocalizedError {
    case missingAPIKey
    case invalidRequest
    case noData
    case invalidResponse
    case networkError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API Key DeepSeek mancante"
        case .invalidRequest:
            return "Richiesta non valida"
        case .noData:
            return "Nessun dato ricevuto"
        case .invalidResponse:
            return "Risposta API non valida"
        case .networkError:
            return "Errore di rete"
        }
    }
}




