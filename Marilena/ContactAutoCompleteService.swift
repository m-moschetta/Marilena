import Foundation
import SwiftUI
import Combine

/// Servizio per auto-completamento intelligente dei contatti email
@MainActor
public class ContactAutoCompleteService: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var suggestions: [ContactSuggestion] = []
    @Published public var isLoading = false
    
    private let emailService: EmailService
    private var cachedContacts: [ContactSuggestion] = []
    private var lastCacheUpdate: Date = .distantPast
    private let cacheValidityDuration: TimeInterval = 300 // 5 minuti
    
    // MARK: - Initialization
    
    public static let shared = ContactAutoCompleteService()
    
    private init() {
        self.emailService = EmailService()
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Cerca suggerimenti per il testo inserito
    public func searchSuggestions(for query: String) {
        guard !query.isEmpty else {
            suggestions = []
            return
        }
        
        // Se la cache è obsoleta, aggiorna
        if shouldUpdateCache() {
            updateContactCache()
        }
        
        // Filtra i contatti in base al query
        let filteredSuggestions = cachedContacts.filter { contact in
            let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Cerca nell'email
            if contact.email.lowercased().contains(normalizedQuery) {
                return true
            }
            
            // Cerca nel nome se presente
            if let name = contact.name, name.lowercased().contains(normalizedQuery) {
                return true
            }
            
            // Cerca nel dominio
            if contact.domain.lowercased().contains(normalizedQuery) {
                return true
            }
            
            return false
        }
        
        // Ordina per rilevanza (priorità: nome esatto > email esatta > parziale)
        let sortedSuggestions = filteredSuggestions.sorted { first, second in
            let normalizedQuery = query.lowercased()
            
            // Priorità 1: Match esatto nome
            if let firstName = first.name?.lowercased(), let secondName = second.name?.lowercased() {
                if firstName.starts(with: normalizedQuery) && !secondName.starts(with: normalizedQuery) {
                    return true
                }
                if !firstName.starts(with: normalizedQuery) && secondName.starts(with: normalizedQuery) {
                    return false
                }
            }
            
            // Priorità 2: Match esatto email
            if first.email.lowercased().starts(with: normalizedQuery) && !second.email.lowercased().starts(with: normalizedQuery) {
                return true
            }
            if !first.email.lowercased().starts(with: normalizedQuery) && second.email.lowercased().starts(with: normalizedQuery) {
                return false
            }
            
            // Priorità 3: Frequenza di utilizzo
            if first.frequency != second.frequency {
                return first.frequency > second.frequency
            }
            
            // Priorità 4: Recenza ultimo utilizzo
            return first.lastUsed > second.lastUsed
        }
        
        // Limita a 8 suggerimenti massimo
        suggestions = Array(sortedSuggestions.prefix(8))
    }
    
    /// Registra l'utilizzo di un contatto
    public func recordContactUsage(_ contact: EmailContact) {
        // Aggiorna la cache se il contatto è stato utilizzato
        if let index = cachedContacts.firstIndex(where: { $0.email == contact.email }) {
            cachedContacts[index].frequency += 1
            cachedContacts[index].lastUsed = Date()
        } else {
            // Aggiungi nuovo contatto alla cache
            let newSuggestion = ContactSuggestion(
                email: contact.email,
                name: contact.name,
                frequency: 1,
                lastUsed: Date(),
                source: .manual
            )
            cachedContacts.append(newSuggestion)
        }
        
        print("📧 ContactAutoCompleteService: Registrato utilizzo contatto: \(contact.email)")
    }
    
    /// Forza l'aggiornamento della cache contatti
    public func refreshCache() {
        updateContactCache()
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        // Osserva quando le email vengono caricate
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EmailsLoaded"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateContactCache()
            }
        }
    }
    
    private func shouldUpdateCache() -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastCacheUpdate)
        return timeSinceLastUpdate > cacheValidityDuration || cachedContacts.isEmpty
    }
    
    private func updateContactCache() {
        isLoading = true
        
        var contactMap: [String: ContactSuggestion] = [:]
        
        // Estrai contatti dalle email caricate
        for email in emailService.emails {
            // Aggiungi mittente
            addContactToMap(&contactMap, email: email.from, source: .sent, date: email.date)
            
            // Aggiungi destinatari se disponibili (per email inviate)
            if email.emailType == .sent {
                // Gestisci array di destinatari
                for recipient in email.to {
                    addContactToMap(&contactMap, email: recipient, source: .received, date: email.date)
                }
            }
        }
        
        // Estrai contatti dalle conversazioni
        for conversation in emailService.emailConversations {
            for participant in conversation.participants {
                addContactToMap(&contactMap, email: participant, source: .conversation, date: conversation.lastActivity)
            }
        }
        
        // Converti in array e ordina per frequenza
        cachedContacts = Array(contactMap.values).sorted { first, second in
            if first.frequency != second.frequency {
                return first.frequency > second.frequency
            }
            return first.lastUsed > second.lastUsed
        }
        
        lastCacheUpdate = Date()
        isLoading = false
        
        print("📧 ContactAutoCompleteService: Cache aggiornata con \(cachedContacts.count) contatti")
    }
    
    private func addContactToMap(_ contactMap: inout [String: ContactSuggestion], email: String, source: ContactSource, date: Date) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty, cleanEmail.contains("@") else { return }
        
        if let existing = contactMap[cleanEmail] {
            // Aggiorna frequenza e data
            contactMap[cleanEmail] = ContactSuggestion(
                email: cleanEmail,
                name: existing.name,
                frequency: existing.frequency + 1,
                lastUsed: max(existing.lastUsed, date),
                source: existing.source
            )
        } else {
            // Estrai nome dal display name se presente
            let extractedName = extractDisplayName(from: email)
            
            contactMap[cleanEmail] = ContactSuggestion(
                email: cleanEmail,
                name: extractedName,
                frequency: 1,
                lastUsed: date,
                source: source
            )
        }
    }
    
    private func extractDisplayName(from emailString: String) -> String? {
        // Formato: "Nome Cognome <email@domain.com>" o "email@domain.com"
        let trimmed = emailString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.contains("<"), let nameEnd = trimmed.firstIndex(of: "<") {
            let name = String(trimmed[..<nameEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && name != trimmed {
                return name.replacingOccurrences(of: "\"", with: "") // Rimuovi virgolette se presenti
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types

/// Rappresenta un suggerimento di contatto
public struct ContactSuggestion: Identifiable, Hashable {
    public let id = UUID()
    public let email: String
    public let name: String?
    public var frequency: Int
    public var lastUsed: Date
    public let source: ContactSource
    
    /// Nome display per UI
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return "\(name) <\(email)>"
        }
        return email
    }
    
    /// Nome breve per UI compatta
    public var shortDisplayName: String {
        name ?? email
    }
    
    /// Dominio email
    public var domain: String {
        if let atIndex = email.lastIndex(of: "@") {
            return String(email[email.index(after: atIndex)...])
        }
        return email
    }
    
    /// Iniziali per avatar
    public var initials: String {
        if let name = name, !name.isEmpty {
            let components = name.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.map(String.init)
            return initials.prefix(2).joined().uppercased()
        } else {
            return String(email.prefix(2)).uppercased()
        }
    }
    
    /// Converte in EmailContact
    public func toEmailContact() -> EmailContact {
        return EmailContact(email: email, name: name)
    }
}

/// Fonte del contatto
public enum ContactSource: String, CaseIterable {
    case sent = "sent"         // Da email inviate
    case received = "received" // Da email ricevute  
    case conversation = "conversation" // Da conversazioni
    case manual = "manual"     // Inserito manualmente
}