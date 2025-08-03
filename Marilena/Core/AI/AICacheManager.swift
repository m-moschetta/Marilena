import Foundation
import Combine
import CommonCrypto

// MARK: - AI Cache Manager
class AICacheManager: ObservableObject {
    static let shared = AICacheManager()
    
    private let cache = NSCache<NSString, CachedAIResponse>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxMemorySize: Int = 50 * 1024 * 1024 // 50MB
    private let maxDiskSize: Int = 500 * 1024 * 1024 // 500MB
    
    @Published var cacheStats = AICacheStats(memoryItems: 0, diskSize: 0, hitRate: 0.0)
    
    private init() {
        // Configura cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("AICache")
        
        // Crea directory se non esiste
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configura NSCache
        cache.totalCostLimit = maxMemorySize
        cache.countLimit = 1000
        
        // Setup cleanup
        setupCacheCleanup()
    }
    
    // MARK: - Cache Operations
    func cacheResponse(_ response: AIResponse, for request: AIRequest) {
        let key = generateCacheKey(for: request)
        let cachedResponse = CachedAIResponse(
            response: response,
            timestamp: Date(),
            accessCount: 1,
            size: estimateSize(of: response)
        )
        
        // Cache in memory
        cache.setObject(cachedResponse, forKey: key as NSString)
        
        // Cache on disk
        saveToDisk(cachedResponse, for: key)
        
        updateStats()
    }
    
    func getCachedResponse(for request: AIRequest) -> AIResponse? {
        let key = generateCacheKey(for: request)
        
        // Check memory cache first
        if let cachedResponse = cache.object(forKey: key as NSString) {
            cachedResponse.accessCount += 1
            cachedResponse.lastAccess = Date()
            return cachedResponse.response
        }
        
        // Check disk cache
        if let cachedResponse = loadFromDisk(for: key) {
            cache.setObject(cachedResponse, forKey: key as NSString)
            cachedResponse.accessCount += 1
            cachedResponse.lastAccess = Date()
            return cachedResponse.response
        }
        
        return nil
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        updateStats()
    }
    
    // MARK: - Private Methods
    private func generateCacheKey(for request: AIRequest) -> String {
        let content = request.messages.map { "\($0.role):\($0.content)" }.joined()
        let hash = content.data(using: .utf8)?.sha256() ?? ""
        return "\(request.model)_\(hash)"
    }
    
    private func estimateSize(of response: AIResponse) -> Int {
        return response.content.utf8.count + 100 // Approximate overhead
    }
    
    private func saveToDisk(_ cachedResponse: CachedAIResponse, for key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let data = try JSONEncoder().encode(cachedResponse)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save cache to disk: \(error)")
        }
    }
    
    private func loadFromDisk(for key: String) -> CachedAIResponse? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(CachedAIResponse.self, from: data)
        } catch {
            return nil
        }
    }
    
    private func setupCacheCleanup() {
        // Cleanup ogni 24 ore
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            self.performCacheCleanup()
        }
    }
    
    private func performCacheCleanup() {
        // Rimuovi cache vecchie (>7 giorni)
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                if let creationDate = try file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Cache cleanup failed: \(error)")
        }
        
        updateStats()
    }
    
    private func updateStats() {
        let memoryCount = cache.totalCostLimit
        let diskSize = calculateDiskSize()
        
        DispatchQueue.main.async {
            self.cacheStats = AICacheStats(
                memoryItems: memoryCount,
                diskSize: diskSize,
                hitRate: self.calculateHitRate()
            )
        }
    }
    
    private func calculateDiskSize() -> Int {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            return files.reduce(0) { total, file in
                let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                return total + (size ?? 0)
            }
        } catch {
            return 0
        }
    }
    
    private func calculateHitRate() -> Double {
        // Implementazione semplificata - in produzione usare metriche reali
        return 0.75
    }
}

// MARK: - Supporting Types
class CachedAIResponse: NSObject, Codable {
    let response: AIResponse
    var timestamp: Date
    var accessCount: Int
    var lastAccess: Date
    let size: Int
    
    init(response: AIResponse, timestamp: Date, accessCount: Int, size: Int) {
        self.response = response
        self.timestamp = timestamp
        self.accessCount = accessCount
        self.lastAccess = timestamp
        self.size = size
    }
}

struct AICacheStats {
    let memoryItems: Int
    let diskSize: Int
    let hitRate: Double
}

// MARK: - Extensions
extension Data {
    func sha256() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
} 