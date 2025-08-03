import Foundation

// MARK: - Profilo

public struct Profilo {
    public let id: UUID
    public let nome: String
    public let cognome: String
    public let email: String
    public let dataNascita: Date
    public let immagineProfilo: Data?
} 