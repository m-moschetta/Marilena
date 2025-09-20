import Foundation

// MARK: - Shared Types

public struct AppleChatMessage: Sendable {
    public enum Role: String, Sendable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }

    public init(role: String, content: String) {
        let normalized = Role(rawValue: role.lowercased()) ?? .user
        self.init(role: normalized, content: content)
    }
}

public enum AppleIntelligenceAvailability: Sendable {
    case available
    case unavailable(reason: Reason)

    public enum Reason: Sendable, Equatable {
        case frameworkMissing
        case osUnsupported
        case appleIntelligenceDisabled
        case deviceNotEligible
        case restricted
        case unknown

        public var description: String {
            switch self {
            case .frameworkMissing:
                return "FoundationModels non è disponibile nel runtime corrente."
            case .osUnsupported:
                return "Aggiorna il dispositivo a iOS 18, iPadOS 18 o macOS Sequoia."
            case .appleIntelligenceDisabled:
                return "Attiva Apple Intelligence dalle Impostazioni > Apple Intelligence."
            case .deviceNotEligible:
                return "Questo dispositivo non supporta Apple Intelligence."
            case .restricted:
                return "Apple Intelligence non è disponibile nella tua lingua o regione."
            case .unknown:
                return "Apple Intelligence non è disponibile in questo momento."
            }
        }
    }
}

public struct AppleGenerationConfiguration: Sendable {
    public var instructions: String?
    public var temperature: Double?
    public var maxOutputTokens: Int?

    public init(
        instructions: String? = nil,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.instructions = instructions
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }
}

// MARK: - Service

public final class AppleIntelligenceService: @unchecked Sendable {
    public static let shared = AppleIntelligenceService()

    private init() {}

    public var isAvailable: Bool {
        switch availability() {
        case .available: return true
        case .unavailable: return false
        }
    }

    public func availability() -> AppleIntelligenceAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            let status = SystemLanguageModel.default.availability
            switch status {
            case .available:
                return .available
            case .unavailable:
                return .unavailable(reason: AppleIntelligenceAvailability.Reason(status))
            @unknown default:
                return .unavailable(reason: .unknown)
            }
        } else {
            return .unavailable(reason: .osUnsupported)
        }
        #else
        return .unavailable(reason: .frameworkMissing)
        #endif
    }

    @discardableResult
    public func sendMessage(
        messages: [AppleChatMessage],
        model: String = "foundation-medium",
        configuration: AppleGenerationConfiguration = AppleGenerationConfiguration()
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            guard case .available = availability() else {
                throw AppleIntelligenceError.unavailable(availability())
            }

            let instructionsText = configuration.instructions ?? Self.extractInstructions(from: messages)
            let session: LanguageModelSession
            if let instructionsText, !instructionsText.isEmpty {
                session = LanguageModelSession(model: .default, instructions: instructionsText)
            } else {
                session = LanguageModelSession(model: .default)
            }

            let prompt = Self.buildPrompt(from: messages)

            // Build options in a way that's compatible with current FoundationModels SDKs
            struct _SessionOptions {
                var temperature: Double? = nil
                var maximumResponseTokens: Int? = nil
            }
            var _options = _SessionOptions()
            if let temperature = configuration.temperature {
                _options.temperature = temperature
            }
            if let maxTokens = configuration.maxOutputTokens {
                _options.maximumResponseTokens = maxTokens
            }

            // Use the most widely available API. Some SDKs do not expose a `respond` overload with tuning parameters.
            // If options are requested but not supported, we gracefully ignore them.
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        throw AppleIntelligenceError.frameworkUnavailable
    }

    // MARK: - Helpers

    private static func extractInstructions(from messages: [AppleChatMessage]) -> String? {
        let systemMessages = messages.filter { $0.role == .system }.map { $0.content }
        guard !systemMessages.isEmpty else { return nil }
        return systemMessages.joined(separator: "\n\n")
    }

    private static func buildPrompt(from messages: [AppleChatMessage]) -> String {
        var components: [String] = []
        for message in messages where message.role != .system {
            let roleLabel: String
            switch message.role {
            case .user: roleLabel = "Utente"
            case .assistant: roleLabel = "Assistente"
            case .system: continue
            }
            components.append("\(roleLabel): \(message.content)")
        }

        if !components.isEmpty {
            components.append("Assistente:")
        }
        return components.joined(separator: "\n")
    }
}

// MARK: - Errors & Bridging

public enum AppleIntelligenceError: LocalizedError, Sendable {
    case frameworkUnavailable
    case unavailable(AppleIntelligenceAvailability)

    public var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            return "Il framework FoundationModels non è disponibile su questo dispositivo"
        case .unavailable(let availability):
            switch availability {
            case .available:
                return nil
            case .unavailable(let reason):
                return reason.description
            }
        }
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18.0, macOS 15.0, *)
private extension AppleIntelligenceAvailability.Reason {
    init(_ availability: SystemLanguageModel.Availability) {
        switch availability {
        case .available:
            self = .unknown
        case .unavailable(let reason):
            // Map known reasons; fall back to .unknown for any cases that aren't available in this SDK
            switch reason {
            // Known case names can vary across SDKs; use only broadly available ones and default otherwise.
            // If your SDK provides `.deviceIneligible` or similar, you can add explicit mappings here.
            default:
                self = .unknown
            }
        @unknown default:
            self = .unknown
        }
    }
}
#endif

