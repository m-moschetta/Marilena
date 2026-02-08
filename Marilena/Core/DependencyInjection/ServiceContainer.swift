import Foundation

// MARK: - Service Container Protocol

@MainActor
protocol ServiceContainerProtocol {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func register<T>(_ type: T.Type, singleton: T)
    func resolve<T>(_ type: T.Type) -> T?
    func isRegistered<T>(_ type: T.Type) -> Bool
}

// MARK: - Service Container Implementation

/// Thread-safe Dependency Injection Container per Marilena
/// Implementazione production-ready con supporto singleton e factory
@MainActor
public class ServiceContainer: ServiceContainerProtocol {
    
    // MARK: - Shared Instance
    
    public static let shared = ServiceContainer()
    
    // MARK: - Private Properties
    
    private var services: [String: Any] = [:]
    private var singletons: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    
    // Thread-safety lock per accesso concorrente ai dizionari
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        print("🏗️ ServiceContainer: Inizializzazione DI Container")
        setupDefaultServices()
        print("✅ ServiceContainer: Container ready with \(services.count) services")
    }
    
    // MARK: - Registration Methods
    
    /// Registra un servizio con factory method (crea nuova istanza ad ogni resolve)
    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        factories[key] = factory
        print("📦 ServiceContainer: Registered factory for \(key)")
    }
    
    /// Registra un servizio come singleton (istanza condivisa)
    public func register<T>(_ type: T.Type, singleton: T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        singletons[key] = singleton
        print("📦 ServiceContainer: Registered singleton for \(key)")
    }
    
    /// Registra un servizio generico
    public func register<T>(_ type: T.Type, service: T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        services[key] = service
        print("📦 ServiceContainer: Registered service for \(key)")
    }
    
    // MARK: - Resolution Methods
    
    /// Risolve una dipendenza dal container
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        lock.lock()
        defer { lock.unlock() }

        // 1. Check singletons first
        if let singleton = singletons[key] as? T {
            return singleton
        }

        // 2. Check factories
        if let factory = factories[key], let instance = factory() as? T {
            return instance
        }

        // 3. Check registered services
        if let service = services[key] as? T {
            return service
        }

        // 4. Not found
        print("⚠️ ServiceContainer: Service \(key) not registered. Available services: \(Array(services.keys))")
        return nil
    }
    
    /// Verifica se un servizio è registrato
    public func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        return singletons[key] != nil || factories[key] != nil || services[key] != nil
    }
    
    // MARK: - Utility Methods
    
    /// Elenca tutti i servizi registrati per debugging
    public func listRegisteredServices() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        var allServices: Set<String> = Set()
        allServices.formUnion(singletons.keys)
        allServices.formUnion(factories.keys)
        allServices.formUnion(services.keys)
        return Array(allServices).sorted()
    }
    
    /// Reset del container (utile per testing)
    public func reset() {
        print("🔄 ServiceContainer: Resetting container")
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
        singletons.removeAll()
        factories.removeAll()
        setupDefaultServices()
    }
    
    // MARK: - Default Services Setup
    
    /// Configura i servizi di default per compatibilità con sistema esistente
    private func setupDefaultServices() {
        // NOTE: Non registriamo ancora i servizi esistenti per evitare breaking changes
        // I servizi esistenti continueranno a funzionare con le loro implementazioni attuali
        // Li aggiungeremo gradualmente nella fase successiva
        
        print("🔧 ServiceContainer: Default services setup completed")
    }
}

// MARK: - Service Locator Pattern

/// Service Locator per accesso semplificato ai servizi
@MainActor
public enum ServiceLocator {

    /// Risolve un servizio dal container principale
    public static func resolve<T>(_ type: T.Type) -> T? {
        return ServiceContainer.shared.resolve(type)
    }

    /// Verifica se un servizio è disponibile
    public static func isAvailable<T>(_ type: T.Type) -> Bool {
        return ServiceContainer.shared.isRegistered(type)
    }
}

// MARK: - Property Wrapper per Injection

/// Property wrapper per dependency injection automatica
@propertyWrapper
public struct Injected<T> {
    private let type: T.Type

    public init(_ type: T.Type) {
        self.type = type
    }

    @MainActor
    public var wrappedValue: T? {
        return ServiceLocator.resolve(type)
    }
}

// MARK: - Extensions for Common Types

extension ServiceContainer {
    
    /// Registra servizio condizionale
    public func registerIf<T>(_ condition: Bool, _ type: T.Type, factory: @escaping () -> T) {
        if condition {
            register(type, factory: factory)
        }
    }
}