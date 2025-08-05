import Foundation
import Combine

// MARK: - Memory Cache Service Implementation

/// Implementazione in-memory del CacheServiceProtocol
/// Thread-safe cache con supporto scadenza e gestione memoria
@MainActor
public class MemoryCacheService: CacheServiceProtocol, ObservableObject {
    
    // MARK: - Private Types
    
    private struct CacheEntry {
        let value: Any
        let expiration: Date?
        let createdAt: Date
        
        init(value: Any, expiration: Date? = nil) {
            self.value = value
            self.expiration = expiration
            self.createdAt = Date()
        }
        
        var isExpired: Bool {
            guard let expiration = expiration else { return false }
            return Date() > expiration
        }
    }
    
    // MARK: - Properties
    
    private var cache: [String: CacheEntry] = [:]
    private let maxMemoryItems: Int
    private let defaultTTL: TimeInterval
    
    /// Timer per pulizia periodica
    private var cleanupTimer: Timer?
    
    /// Statistiche cache
    @Published public private(set) var cacheStats = CacheStats()
    
    // MARK: - Initialization
    
    public init(maxMemoryItems: Int = 1000, defaultTTL: TimeInterval = 30 * 60) {
        self.maxMemoryItems = maxMemoryItems
        self.defaultTTL = defaultTTL
        
        print("🗄️ MemoryCacheService: Initialized with max items: \(maxMemoryItems), TTL: \(defaultTTL)s")
        
        setupCleanupTimer()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - CacheServiceProtocol Implementation
    
    public func set<T: Codable>(_ object: T, forKey key: String) async {
        print("🗄️ MemoryCacheService: Setting object for key: \(key)")
        
        // Check memory limits
        if cache.count >= maxMemoryItems {
            await evictOldestItems(count: maxMemoryItems / 4) // Evict 25% when full
        }
        
        let entry = CacheEntry(value: object, expiration: Date().addingTimeInterval(defaultTTL))
        cache[key] = entry
        
        // Update stats
        cacheStats.totalSets += 1
        cacheStats.currentItems = cache.count
        
        print("✅ MemoryCacheService: Object cached successfully")
    }
    
    public func get<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        print("🗄️ MemoryCacheService: Getting object for key: \(key)")
        
        guard let entry = cache[key] else {
            print("❌ MemoryCacheService: Cache miss for key: \(key)")
            cacheStats.totalMisses += 1
            return nil
        }
        
        // Check expiration
        if entry.isExpired {
            print("⏰ MemoryCacheService: Cache entry expired for key: \(key)")
            cache.removeValue(forKey: key)
            cacheStats.totalMisses += 1
            cacheStats.currentItems = cache.count
            return nil
        }
        
        // Type safety check
        guard let value = entry.value as? T else {
            print("❌ MemoryCacheService: Type mismatch for key: \(key)")
            cache.removeValue(forKey: key)
            cacheStats.totalMisses += 1
            cacheStats.currentItems = cache.count
            return nil
        }
        
        print("✅ MemoryCacheService: Cache hit for key: \(key)")
        cacheStats.totalHits += 1
        return value
    }
    
    public func remove(forKey key: String) async {
        print("🗄️ MemoryCacheService: Removing object for key: \(key)")
        
        if cache.removeValue(forKey: key) != nil {
            cacheStats.totalRemovals += 1
            cacheStats.currentItems = cache.count
            print("✅ MemoryCacheService: Object removed successfully")
        } else {
            print("⚠️ MemoryCacheService: No object found for removal: \(key)")
        }
    }
    
    public func clear() async {
        print("🗄️ MemoryCacheService: Clearing entire cache")
        
        let itemCount = cache.count
        cache.removeAll()
        
        cacheStats.totalRemovals += itemCount
        cacheStats.currentItems = 0
        
        print("✅ MemoryCacheService: Cache cleared (\(itemCount) items removed)")
    }
    
    public func exists(forKey key: String) async -> Bool {
        guard let entry = cache[key] else { return false }
        
        if entry.isExpired {
            cache.removeValue(forKey: key)
            cacheStats.currentItems = cache.count
            return false
        }
        
        return true
    }
    
    public func getCacheSize() async -> Int {
        // Approximate memory calculation
        let baseSize = cache.count * MemoryLayout<String>.size // Keys
        let entriesSize = cache.values.reduce(0) { total, entry in
            return total + estimateObjectSize(entry.value)
        }
        
        return baseSize + entriesSize
    }
    
    public func getExpiration(forKey key: String) async -> Date? {
        return cache[key]?.expiration
    }
    
    public func setExpiration(forKey key: String, expiration: Date) async {
        print("🗄️ MemoryCacheService: Setting expiration for key: \(key)")
        
        guard let entry = cache[key] else {
            print("⚠️ MemoryCacheService: Cannot set expiration, key not found: \(key)")
            return
        }
        
        let updatedEntry = CacheEntry(value: entry.value, expiration: expiration)
        cache[key] = updatedEntry
        
        print("✅ MemoryCacheService: Expiration updated successfully")
    }
    
    // MARK: - Additional Cache Management
    
    /// Cleanup automatica entry scadute
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.cleanupExpiredEntries()
            }
        }
    }
    
    private func cleanupExpiredEntries() async {
        let beforeCount = cache.count
        
        let expiredKeys = cache.compactMap { key, entry in
            entry.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        
        let removedCount = beforeCount - cache.count
        if removedCount > 0 {
            cacheStats.totalRemovals += removedCount
            cacheStats.currentItems = cache.count
            print("🧹 MemoryCacheService: Cleaned up \(removedCount) expired entries")
        }
    }
    
    /// Evict oldest items quando la cache è piena
    private func evictOldestItems(count: Int) async {
        let sortedByAge = cache.sorted { $0.value.createdAt < $1.value.createdAt }
        let toRemove = Array(sortedByAge.prefix(count))
        
        for (key, _) in toRemove {
            cache.removeValue(forKey: key)
        }
        
        cacheStats.totalRemovals += toRemove.count
        cacheStats.currentItems = cache.count
        
        print("🗑️ MemoryCacheService: Evicted \(toRemove.count) oldest items")
    }
    
    /// Stima dimensione oggetto (approssimativa)
    private func estimateObjectSize(_ object: Any) -> Int {
        switch object {
        case let string as String:
            return string.utf8.count
        case let data as Data:
            return data.count
        case let array as [Any]:
            return array.reduce(0) { $0 + estimateObjectSize($1) }
        default:
            return 100 // Default estimate for complex objects
        }
    }
    
    // MARK: - Statistics and Monitoring
    
    /// Ottieni statistiche dettagliate
    public func getDetailedStats() -> CacheStats {
        var stats = cacheStats
        stats.hitRate = stats.totalHits > 0 ? Double(stats.totalHits) / Double(stats.totalHits + stats.totalMisses) : 0.0
        return stats
    }
    
    /// Reset statistiche
    public func resetStats() {
        cacheStats = CacheStats()
        print("📊 MemoryCacheService: Statistics reset")
    }
}

// MARK: - Cache Statistics

public struct CacheStats {
    public var totalHits: Int = 0
    public var totalMisses: Int = 0
    public var totalSets: Int = 0
    public var totalRemovals: Int = 0
    public var currentItems: Int = 0
    public var hitRate: Double = 0.0
    
    public var efficiency: String {
        return String(format: "%.1f%% hit rate", hitRate * 100)
    }
}

// MARK: - Service Container Registration

public extension ServiceContainer {
    
    /// Registra MemoryCacheService come implementazione di CacheServiceProtocol
    func registerMemoryCacheService() {
        let cacheService = MemoryCacheService()
        self.register(CacheServiceProtocol.self, singleton: cacheService)
        print("🗄️ ServiceContainer: MemoryCacheService registered")
    }
}

// MARK: - Cache Configuration

/// Configurazione per diversi tipi di cache
public enum CacheConfiguration {
    
    /// Configurazione per cache email (TTL 30 min, 500 items max)
    public static let email = CacheConfig(
        maxItems: 500,
        defaultTTL: 30 * 60,
        cleanupInterval: 5 * 60
    )
    
    /// Configurazione per cache chat (TTL 1 ora, 200 items max)
    public static let chat = CacheConfig(
        maxItems: 200,
        defaultTTL: 60 * 60,
        cleanupInterval: 10 * 60
    )
    
    /// Configurazione per cache AI responses (TTL 10 min, 100 items max)
    public static let aiResponse = CacheConfig(
        maxItems: 100,
        defaultTTL: 10 * 60,
        cleanupInterval: 2 * 60
    )
}

public struct CacheConfig {
    public let maxItems: Int
    public let defaultTTL: TimeInterval
    public let cleanupInterval: TimeInterval
    
    public init(maxItems: Int, defaultTTL: TimeInterval, cleanupInterval: TimeInterval) {
        self.maxItems = maxItems
        self.defaultTTL = defaultTTL
        self.cleanupInterval = cleanupInterval
    }
}