# 🏗️ **FASE 1: FOUNDATION REBUILD - DETTAGLI TECNICI**

## 📦 **1.1 DEPENDENCY INJECTION CONTAINER**

### **Technical Implementation:**

```swift
// Container Protocol
protocol DIContainer {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func register<T>(_ type: T.Type, instance: T)
    func resolve<T>(_ type: T.Type) -> T
    func resolve<T>(_ type: T.Type) -> T?
}

// Container Implementation
final class DIContainerImpl: DIContainer {
    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        singletons[key] = instance
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        if let singleton = singletons[key] as? T {
            return singleton
        }
        
        guard let factory = factories[key] else {
            fatalError("Service \(key) not registered")
        }
        
        return factory() as! T
    }
}

// Service Locator
enum ServiceLocator {
    private static let container = DIContainerImpl()
    
    static func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        container.register(type, factory: factory)
    }
    
    static func register<T>(_ type: T.Type, instance: T) {
        container.register(type, instance: instance)
    }
    
    static func resolve<T>(_ type: T.Type) -> T {
        return container.resolve(type)
    }
}

// Configuration at App Launch
func configureDependencies() {
    // Core Services
    ServiceLocator.register(EmailServiceProtocol.self) {
        EmailService(
            repository: ServiceLocator.resolve(EmailRepositoryProtocol.self),
            authService: ServiceLocator.resolve(AuthServiceProtocol.self),
            syncManager: ServiceLocator.resolve(SyncManagerProtocol.self)
        )
    }
    
    ServiceLocator.register(EmailRepositoryProtocol.self) {
        EmailRepository(
            context: ServiceLocator.resolve(CoreDataServiceProtocol.self).backgroundContext,
            cacheService: ServiceLocator.resolve(CacheServiceProtocol.self)
        )
    }
    
    // AI Services
    ServiceLocator.register(AIOrchestratorProtocol.self) {
        AIOrchestrator(
            providers: [
                OpenAIProvider(),
                AnthropicProvider()
            ],
            loadBalancer: ServiceLocator.resolve(AILoadBalancerProtocol.self),
            rateLimiter: ServiceLocator.resolve(RateLimiterProtocol.self),
            cache: ServiceLocator.resolve(AICacheProtocol.self)
        )
    }
}
```

### **File Structure:**
```
Marilena/Core/DependencyInjection/
├── DIContainer.swift
├── ServiceLocator.swift
├── DIConfiguration.swift
└── Tests/
    ├── DIContainerTests.swift
    └── ServiceLocatorTests.swift
```

---

## 🔧 **1.2 SERVICE PROTOCOLS & INTERFACES**

### **Core Email Protocol:**

```swift
// Email Service Protocol
@MainActor
protocol EmailServiceProtocol: AnyObject, ObservableObject {
    var isAuthenticated: Bool { get }
    var emails: [EmailMessage] { get }
    var currentAccount: EmailAccount? { get }
    var syncStatus: SyncStatus { get }
    
    func authenticate(provider: EmailProvider) async throws
    func loadEmails() async throws
    func sendEmail(to: String, subject: String, body: String) async throws
    func deleteEmail(_ id: String) async throws
    func markAsRead(_ id: String) async throws
    func searchEmails(query: String) async throws -> [EmailMessage]
}

// AI Service Protocol
protocol AIServiceProtocol: AnyObject {
    func categorizeEmail(_ email: EmailMessage) async throws -> EmailCategory
    func generateResponse(for email: EmailMessage, tone: ResponseTone) async throws -> String
    func analyzeEmail(_ email: EmailMessage) async throws -> EmailAnalysis
    func summarizeEmail(_ email: EmailMessage) async throws -> String
    func translateEmail(_ email: EmailMessage, to language: Language) async throws -> String
}

// Cache Service Protocol
protocol CacheServiceProtocol: AnyObject {
    func cache<T: Codable>(_ object: T, forKey key: String) async
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) async -> T?
    func remove(forKey key: String) async
    func clearAll() async
    func size() async -> Int64
}

// Repository Protocol
protocol EmailRepositoryProtocol: AnyObject {
    func save(_ email: EmailMessage) async throws
    func fetch(id: String) async throws -> EmailMessage?
    func fetchAll() async throws -> [EmailMessage]
    func fetchByThread(threadId: String) async throws -> [EmailMessage]
    func delete(id: String) async throws
    func search(query: String) async throws -> [EmailMessage]
}

// Auth Service Protocol
protocol AuthServiceProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var currentProvider: EmailProvider? { get }
    
    func authenticate(provider: EmailProvider) async throws -> AuthResult
    func refreshToken() async throws
    func logout() async
    func getValidToken() async throws -> String
}
```

### **Supporting Models:**

```swift
// Email Analysis Result
struct EmailAnalysis {
    let emailId: String
    let category: EmailCategory
    let urgency: UrgencyLevel
    let sentiment: SentimentScore
    let keyTopics: [String]
    let suggestedActions: [SuggestedAction]
    let confidence: Double
    let processedAt: Date
}

// Auth Result
struct AuthResult {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
    let account: EmailAccount
    let scopes: [String]
}

// Sync Status
enum SyncStatus {
    case idle
    case syncing
    case completed
    case failed(Error)
    case paused
}
```

---

## 🗂️ **1.3 REPOSITORY PATTERN IMPLEMENTATION**

### **Generic Repository:**

```swift
// Base Repository Protocol
protocol Repository {
    associatedtype Entity
    associatedtype ID
    
    func save(_ entity: Entity) async throws
    func find(by id: ID) async throws -> Entity?
    func findAll() async throws -> [Entity]
    func delete(by id: ID) async throws
    func deleteAll() async throws
    func count() async throws -> Int
}

// Email Repository Implementation
final class EmailRepository: Repository {
    typealias Entity = EmailMessage
    typealias ID = String
    
    private let context: NSManagedObjectContext
    private let cacheService: CacheServiceProtocol
    private let queue = DispatchQueue(label: "email.repository", qos: .utility)
    
    init(context: NSManagedObjectContext, cacheService: CacheServiceProtocol) {
        self.context = context
        self.cacheService = cacheService
    }
    
    func save(_ email: EmailMessage) async throws {
        // First save to cache for immediate access
        await cacheService.cache(email, forKey: "email_\(email.id)")
        
        // Then persist to CoreData
        try await context.perform {
            let entity = EmailMessageEntity(context: self.context)
            entity.id = email.id
            entity.from = email.from
            entity.to = email.to
            entity.subject = email.subject
            entity.content = email.content
            entity.dateReceived = email.dateReceived
            entity.isRead = email.isRead
            entity.threadId = email.threadId
            
            try self.context.save()
        }
    }
    
    func find(by id: String) async throws -> EmailMessage? {
        // Try cache first
        if let cached = await cacheService.retrieve(EmailMessage.self, forKey: "email_\(id)") {
            return cached
        }
        
        // Fallback to CoreData
        return try await context.perform {
            let request: NSFetchRequest<EmailMessageEntity> = EmailMessageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            request.fetchLimit = 1
            
            guard let entity = try self.context.fetch(request).first else {
                return nil
            }
            
            return EmailMessage(from: entity)
        }
    }
    
    func fetchByThread(threadId: String) async throws -> [EmailMessage] {
        return try await context.perform {
            let request: NSFetchRequest<EmailMessageEntity> = EmailMessageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "threadId == %@", threadId)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \EmailMessageEntity.dateReceived, ascending: true)]
            
            let entities = try self.context.fetch(request)
            return entities.map { EmailMessage(from: $0) }
        }
    }
    
    func search(query: String) async throws -> [EmailMessage] {
        return try await context.perform {
            let request: NSFetchRequest<EmailMessageEntity> = EmailMessageEntity.fetchRequest()
            
            let predicates = [
                NSPredicate(format: "subject CONTAINS[cd] %@", query),
                NSPredicate(format: "content CONTAINS[cd] %@", query),
                NSPredicate(format: "from CONTAINS[cd] %@", query)
            ]
            
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \EmailMessageEntity.dateReceived, ascending: false)]
            
            let entities = try self.context.fetch(request)
            return entities.map { EmailMessage(from: $0) }
        }
    }
}

// Chat Repository
final class ChatRepository: Repository {
    typealias Entity = ChatMarilena
    typealias ID = String
    
    private let context: NSManagedObjectContext
    
    func save(_ chat: ChatMarilena) async throws {
        try await context.perform {
            try self.context.save()
        }
    }
    
    func findEmailChats() async throws -> [ChatMarilena] {
        return try await context.perform {
            let request: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
            request.predicate = NSPredicate(format: "tipo == %@", "email")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMarilena.lastEmailDate, ascending: false)]
            
            return try self.context.fetch(request)
        }
    }
}
```

---

## ⚙️ **1.4 CONFIGURATION MANAGEMENT SYSTEM**

### **Configuration Implementation:**

```swift
// Configuration Protocol
protocol ConfigurationProtocol {
    var environment: Environment { get }
    var apiEndpoints: APIEndpoints { get }
    var emailSettings: EmailSettings { get }
    var aiSettings: AISettings { get }
    var cacheSettings: CacheSettings { get }
    var securitySettings: SecuritySettings { get }
}

// Environment Enum
enum Environment: String, CaseIterable {
    case development = "dev"
    case staging = "staging"
    case production = "prod"
    
    static var current: Environment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
}

// Configuration Structs
struct APIEndpoints {
    let gmail: String
    let outlook: String
    let openai: String
    let anthropic: String
    let perplexity: String
}

struct EmailSettings {
    let smtpTimeout: TimeInterval
    let imapTimeout: TimeInterval
    let maxRetries: Int
    let batchSize: Int
    let syncInterval: TimeInterval
    let maxAttachmentSize: Int64
}

struct AISettings {
    let openaiModel: String
    let anthropicModel: String
    let maxTokens: Int
    let temperature: Double
    let rateLimitPerMinute: Int
    let cacheTTL: TimeInterval
}

struct CacheSettings {
    let maxMemorySize: Int64
    let maxDiskSize: Int64
    let emailTTL: TimeInterval
    let aiResponseTTL: TimeInterval
}

struct SecuritySettings {
    let tokenRefreshThreshold: TimeInterval
    let maxTokenAge: TimeInterval
    let enablePinning: Bool
    let allowInsecureConnections: Bool
}

// Configuration Manager
final class ConfigurationManager: ConfigurationProtocol {
    let environment: Environment
    
    init(environment: Environment = Environment.current) {
        self.environment = environment
    }
    
    var apiEndpoints: APIEndpoints {
        switch environment {
        case .development:
            return APIEndpoints(
                gmail: "https://gmail.googleapis.com/gmail/v1",
                outlook: "https://graph.microsoft.com/v1.0",
                openai: "https://api.openai.com/v1",
                anthropic: "https://api.anthropic.com/v1",
                perplexity: "https://api.perplexity.ai"
            )
        case .staging:
            return APIEndpoints(
                gmail: "https://gmail.googleapis.com/gmail/v1",
                outlook: "https://graph.microsoft.com/v1.0",
                openai: "https://api.openai.com/v1",
                anthropic: "https://api.anthropic.com/v1",
                perplexity: "https://api.perplexity.ai"
            )
        case .production:
            return APIEndpoints(
                gmail: "https://gmail.googleapis.com/gmail/v1",
                outlook: "https://graph.microsoft.com/v1.0",
                openai: "https://api.openai.com/v1",
                anthropic: "https://api.anthropic.com/v1",
                perplexity: "https://api.perplexity.ai"
            )
        }
    }
    
    var emailSettings: EmailSettings {
        switch environment {
        case .development:
            return EmailSettings(
                smtpTimeout: 30,
                imapTimeout: 30,
                maxRetries: 3,
                batchSize: 20,
                syncInterval: 60,
                maxAttachmentSize: 25 * 1024 * 1024 // 25MB
            )
        case .staging, .production:
            return EmailSettings(
                smtpTimeout: 60,
                imapTimeout: 60,
                maxRetries: 5,
                batchSize: 50,
                syncInterval: 30,
                maxAttachmentSize: 25 * 1024 * 1024 // 25MB
            )
        }
    }
    
    var aiSettings: AISettings {
        switch environment {
        case .development:
            return AISettings(
                openaiModel: "gpt-4-turbo",
                anthropicModel: "claude-3-sonnet-20240229",
                maxTokens: 500,
                temperature: 0.7,
                rateLimitPerMinute: 10,
                cacheTTL: 300 // 5 minutes
            )
        case .staging, .production:
            return AISettings(
                openaiModel: "gpt-4-turbo",
                anthropicModel: "claude-3-sonnet-20240229",
                maxTokens: 1000,
                temperature: 0.7,
                rateLimitPerMinute: 50,
                cacheTTL: 1800 // 30 minutes
            )
        }
    }
}
```

---

## 🔐 **1.5 SECURE TOKEN & CREDENTIAL MANAGER**

### **Security Implementation:**

```swift
// Secure Storage Protocol
protocol SecureStorageProtocol {
    func store(_ data: Data, forKey key: String) throws
    func retrieve(forKey key: String) throws -> Data?
    func delete(forKey key: String) throws
    func deleteAll() throws
}

// Keychain Implementation
final class KeychainSecureStorage: SecureStorageProtocol {
    private let service = "com.marilena.secure"
    
    func store(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
    }
    
    func retrieve(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw SecurityError.keychainError(status)
        }
        
        return result as? Data
    }
}

// Token Manager
final class TokenManager {
    private let secureStorage: SecureStorageProtocol
    private let configuration: ConfigurationProtocol
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    init(secureStorage: SecureStorageProtocol, configuration: ConfigurationProtocol) {
        self.secureStorage = secureStorage
        self.configuration = configuration
    }
    
    func storeTokens(_ tokens: OAuthTokens, for provider: EmailProvider) throws {
        let data = try jsonEncoder.encode(tokens)
        try secureStorage.store(data, forKey: "\(provider.rawValue)_tokens")
    }
    
    func retrieveTokens(for provider: EmailProvider) throws -> OAuthTokens? {
        guard let data = try secureStorage.retrieve(forKey: "\(provider.rawValue)_tokens") else {
            return nil
        }
        return try jsonDecoder.decode(OAuthTokens.self, from: data)
    }
    
    func isTokenValid(_ tokens: OAuthTokens) -> Bool {
        let expiryDate = tokens.issuedAt.addingTimeInterval(TimeInterval(tokens.expiresIn))
        let refreshThreshold = configuration.securitySettings.tokenRefreshThreshold
        return Date().addingTimeInterval(refreshThreshold) < expiryDate
    }
    
    func refreshTokenIfNeeded(_ tokens: OAuthTokens, provider: EmailProvider) async throws -> OAuthTokens {
        guard !isTokenValid(tokens) else { return tokens }
        
        let refreshedTokens = try await performTokenRefresh(tokens, provider: provider)
        try storeTokens(refreshedTokens, for: provider)
        
        NotificationCenter.default.post(
            name: .tokenRefreshed,
            object: nil,
            userInfo: ["provider": provider]
        )
        
        return refreshedTokens
    }
    
    private func performTokenRefresh(_ tokens: OAuthTokens, provider: EmailProvider) async throws -> OAuthTokens {
        // Implementation for token refresh
        // This would integrate with OAuth2 refresh flow
        
        switch provider {
        case .google:
            return try await refreshGoogleToken(tokens)
        case .microsoft:
            return try await refreshMicrosoftToken(tokens)
        }
    }
}

// OAuth Tokens Model
struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let issuedAt: Date
    
    init(accessToken: String, refreshToken: String, tokenType: String, expiresIn: Int, scope: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.issuedAt = Date()
    }
}

// Security Errors
enum SecurityError: LocalizedError {
    case keychainError(OSStatus)
    case tokenExpired
    case invalidToken
    case refreshFailed
    
    var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .tokenExpired:
            return "Authentication token has expired"
        case .invalidToken:
            return "Invalid authentication token"
        case .refreshFailed:
            return "Failed to refresh authentication token"
        }
    }
}

// Notification Extensions
extension Notification.Name {
    static let tokenRefreshed = Notification.Name("tokenRefreshed")
    static let authenticationRequired = Notification.Name("authenticationRequired")
}
```

---

## ✅ **ACCEPTANCE CRITERIA FASE 1**

### **Functional Requirements:**
- [ ] DI Container può registrare e risolvere servizi
- [ ] Tutti i servizi implementano i protocolli definiti
- [ ] Repository pattern funziona con CoreData e Cache
- [ ] Configuration manager supporta tutti gli environment
- [ ] Token manager gestisce sicuramente credenziali e refresh

### **Non-Functional Requirements:**
- [ ] Test coverage > 90% per tutti i componenti
- [ ] Nessuna dipendenza hard-coded tra servizi
- [ ] Keychain integration sicura e funzionante
- [ ] Performance: DI resolution < 1ms
- [ ] Memory: No memory leaks in DI container

### **Technical Requirements:**
- [ ] Protocolli ben definiti e documentati
- [ ] Error handling completo
- [ ] Thread-safe operations
- [ ] Logging appropriato
- [ ] Configuration validata

---

## 🚀 **DELIVERY CHECKLIST**

- [ ] Tutti i file implementati e testati
- [ ] Code review completato
- [ ] Tests passano al 100%
- [ ] Documentation aggiornata
- [ ] Performance benchmarks eseguiti
- [ ] Security audit completato
- [ ] Integrazione con sistema esistente testata

**Estimated Time: 20 ore (2 giorni)**