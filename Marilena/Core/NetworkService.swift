import Foundation

// MARK: - Network Service Protocol
public protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func request(_ endpoint: APIEndpoint) async throws -> Data
}

// MARK: - API Endpoint
public struct APIEndpoint {
    public let url: URL
    public let method: HTTPMethod
    public let headers: [String: String]
    public let body: Data?
    
    public init(url: URL, method: HTTPMethod = .post, headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - Network Service Implementation
public class NetworkService: NetworkServiceProtocol {
    public static let shared = NetworkService()
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await request(endpoint)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    public func request(_ endpoint: APIEndpoint) async throws -> Data {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return data
    }
}

// MARK: - Network Errors
public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case encodingError
    case decodingError(Error)
    case noData
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL non valido"
        case .invalidResponse:
            return "Risposta del server non valida"
        case .httpError(let statusCode, _):
            return "Errore HTTP: \(statusCode)"
        case .encodingError:
            return "Errore nella codifica dei dati"
        case .decodingError(let error):
            return "Errore nella decodifica: \(error.localizedDescription)"
        case .noData:
            return "Nessun dato ricevuto"
        }
    }
}

// MARK: - API Configuration
public struct APIConfiguration {
    public let baseURL: String
    public let apiKey: String
    public let headers: [String: String]
    
    public init(baseURL: String, apiKey: String, headers: [String: String] = [:]) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.headers = headers
    }
}
