import Foundation

struct OpenAIMessage: Codable {
    let role: String
    let content: String
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
    
    private init() {}
    
    func sendMessage(messages: [OpenAIMessage], model: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = KeychainManager.shared.load(key: "openai_api_key"), !apiKey.isEmpty else {
            DispatchQueue.main.async {
                completion(.failure(OpenAIError.noAPIKey))
            }
            return
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let temperature = UserDefaults.standard.double(forKey: "temperature") != 0 ? UserDefaults.standard.double(forKey: "temperature") : 0.7
        let maxTokens = Int(UserDefaults.standard.double(forKey: "max_tokens") != 0 ? UserDefaults.standard.double(forKey: "max_tokens") : 1000)
        
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
