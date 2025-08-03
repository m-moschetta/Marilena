import Foundation

// MARK: - Service Factory Pattern
class AIServiceFactory {
    static let shared = AIServiceFactory()
    
    private var services: [String: Any] = [:]
    
    private init() {}
    
    // MARK: - Service Registration
    func registerService<T>(_ service: T, for type: String) {
        services[type] = service
    }
    
    // MARK: - Service Retrieval
    func service<T>(for type: String) -> T? {
        return services[type] as? T
    }
    
    // MARK: - Legacy Compatibility
    func legacyOpenAIService() -> OpenAIService {
        if let service: OpenAIService = service(for: "legacy_openai") {
            return service
        }
        
        let service = OpenAIService()
        registerService(service, for: "legacy_openai")
        return service
    }
    
    func legacyAnthropicService() -> AnthropicService {
        if let service: AnthropicService = service(for: "legacy_anthropic") {
            return service
        }
        
        let service = AnthropicService()
        registerService(service, for: "legacy_anthropic")
        return service
    }
}
