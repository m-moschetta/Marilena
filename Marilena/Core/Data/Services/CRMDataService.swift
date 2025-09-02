import Foundation
import CoreData
import SwiftUI
import Combine

// MARK: - CRM Data Service

@MainActor
public class CRMDataService: ObservableObject {
    public static let shared = CRMDataService()
    
    @Published public var isLoading = false
    @Published public var contacts: [CRMContactReal] = []
    @Published public var lastUpdateDate: Date?
    
    private let persistenceController: PersistenceController
    private let emailCacheService: EmailCacheService
    private let calendarManager: CalendarManager
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.persistenceController = PersistenceController.shared
        self.emailCacheService = EmailCacheService()
        self.calendarManager = CalendarManager()
    }
    
    // MARK: - Public Methods
    
    public func loadContacts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Carica contatti da email
            let emailContacts = await loadEmailContacts()
            
            // Carica contatti da calendario
            let calendarContacts = await loadCalendarContacts()
            
            // Unifica i contatti
            let unifiedContacts = mergeContacts(emailContacts: emailContacts, calendarContacts: calendarContacts)
            
            contacts = unifiedContacts
            lastUpdateDate = Date()
            
            print("✅ CRMDataService: Caricati \(unifiedContacts.count) contatti")
            
        } catch {
            print("❌ CRMDataService Error: \(error)")
        }
    }
    
    public func saveContactChanges(_ contactId: String, notes: String, tags: [String]) async {
        // Salva le modifiche in UserDefaults per ora
        // TODO: Implementare persistenza in Core Data
        let key = "contact_\(contactId)"
        let data = ["notes": notes, "tags": tags] as [String: Any]
        UserDefaults.standard.set(data, forKey: key)
        
        // Aggiorna il contatto locale
        if let index = contacts.firstIndex(where: { $0.id == contactId }) {
            contacts[index].notes = notes
            contacts[index].tags = tags
        }
        
        print("✅ CRMDataService: Salvate modifiche per contatto \(contactId)")
    }
    
    // MARK: - Private Methods
    
    private func loadEmailContacts() async -> [CRMContactReal] {
        let context = persistenceController.container.viewContext
        var emailContacts: [CRMContactReal] = []
        
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CachedEmail")
            request.predicate = NSPredicate(format: "from != nil AND from != ''")
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            do {
                let emails = try context.fetch(request)
                var contactMap: [String: CRMContactReal] = [:]
                
                for email in emails {
                    guard let fromEmail = email.value(forKey: "from") as? String,
                          !fromEmail.isEmpty else { continue }
                    
                    let cleanEmail = self.extractEmailAddress(from: fromEmail)
                    
                    if var existingContact = contactMap[cleanEmail] {
                        // Aggiorna contatto esistente
                        existingContact.interactionCount += 1
                        if let emailDate = email.value(forKey: "date") as? Date,
                           existingContact.lastInteractionDate ?? Date.distantPast < emailDate {
                            existingContact.lastInteractionDate = emailDate
                        }
                        
                        // Aggiungi categoria email
                        if let subject = email.value(forKey: "subject") as? String {
                            let category = self.categorizeEmail(subject: subject)
                            if !existingContact.tags.contains(category) {
                                existingContact.tags.append(category)
                            }
                        }
                        
                        contactMap[cleanEmail] = existingContact
                        
                    } else {
                        // Nuovo contatto
                        let displayName = self.extractNameFromEmail(fromEmail)
                        let subject = email.value(forKey: "subject") as? String ?? ""
                        let category = self.categorizeEmail(subject: subject)
                        
                        var newContact = CRMContactReal(
                            id: UUID().uuidString,
                            displayName: displayName,
                            email: cleanEmail,
                            phone: nil,
                            company: self.extractCompanyFromEmail(cleanEmail),
                            jobTitle: nil,
                            lastInteractionDate: email.value(forKey: "date") as? Date,
                            interactionCount: 1,
                            relationshipStrength: self.calculateRelationshipStrength(interactionCount: 1),
                            tags: [category],
                            notes: nil,
                            source: .email
                        )
                        
                        // Carica dati salvati se esistenti
                        self.loadSavedContactData(for: &newContact)
                        
                        contactMap[cleanEmail] = newContact
                    }
                }
                
                emailContacts = Array(contactMap.values)
                
            } catch {
                print("❌ CRMDataService Error loading email contacts: \(error)")
            }
        }
        
        return emailContacts
    }
    
    private func loadCalendarContacts() async -> [CRMContactReal] {
        // Per ora ritorna array vuoto - da implementare quando CalendarManager è pronto
        // TODO: Integrare con CalendarManager per estrarre partecipanti agli eventi
        return []
    }
    
    private func mergeContacts(emailContacts: [CRMContactReal], calendarContacts: [CRMContactReal]) -> [CRMContactReal] {
        var mergedContacts: [String: CRMContactReal] = [:]
        
        // Aggiungi contatti email
        for contact in emailContacts {
            mergedContacts[contact.email] = contact
        }
        
        // Merge contatti calendario
        for calendarContact in calendarContacts {
            if var existing = mergedContacts[calendarContact.email] {
                // Merge dei dati
                existing.interactionCount += calendarContact.interactionCount
                existing.tags.append(contentsOf: calendarContact.tags.filter { !existing.tags.contains($0) })
                if let calendarDate = calendarContact.lastInteractionDate,
                   existing.lastInteractionDate ?? Date.distantPast < calendarDate {
                    existing.lastInteractionDate = calendarDate
                }
                existing.relationshipStrength = calculateRelationshipStrength(interactionCount: existing.interactionCount)
                mergedContacts[calendarContact.email] = existing
            } else {
                mergedContacts[calendarContact.email] = calendarContact
            }
        }
        
        return Array(mergedContacts.values)
            .sorted { $0.interactionCount > $1.interactionCount }
    }
    
    private func loadSavedContactData(for contact: inout CRMContactReal) {
        let key = "contact_\(contact.id)"
        if let savedData = UserDefaults.standard.dictionary(forKey: key) {
            contact.notes = savedData["notes"] as? String
            contact.tags = savedData["tags"] as? [String] ?? contact.tags
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractEmailAddress(from fullEmail: String) -> String {
        // Estrae solo l'indirizzo email da "Nome Cognome <email@domain.com>"
        if let range = fullEmail.range(of: "<(.+?)>", options: .regularExpression) {
            return String(fullEmail[range]).replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "")
        }
        return fullEmail.trimmingCharacters(in: .whitespaces)
    }
    
    private func extractNameFromEmail(_ fullEmail: String) -> String {
        // Estrae il nome da "Nome Cognome <email@domain.com>"
        if fullEmail.contains("<") {
            let name = fullEmail.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespaces) ?? ""
            if !name.isEmpty {
                return name
            }
        }
        
        // Fallback: usa la parte locale dell'email
        let email = extractEmailAddress(from: fullEmail)
        let localPart = email.components(separatedBy: "@").first ?? email
        return localPart.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
    
    private func extractCompanyFromEmail(_ email: String) -> String? {
        let domain = email.components(separatedBy: "@").last ?? ""
        let companyPart = domain.components(separatedBy: ".").first ?? ""
        
        // Escludi domini comuni
        let commonDomains = ["gmail", "yahoo", "outlook", "hotmail", "icloud", "me", "mac"]
        if commonDomains.contains(companyPart.lowercased()) {
            return nil
        }
        
        return companyPart.capitalized
    }
    
    private func categorizeEmail(subject: String) -> String {
        let lowerSubject = subject.lowercased()
        
        if lowerSubject.contains("meeting") || lowerSubject.contains("riunione") {
            return "meeting"
        } else if lowerSubject.contains("project") || lowerSubject.contains("progetto") {
            return "progetto"
        } else if lowerSubject.contains("support") || lowerSubject.contains("supporto") {
            return "supporto"
        } else if lowerSubject.contains("invoice") || lowerSubject.contains("fattura") {
            return "fatturazione"
        } else if lowerSubject.contains("newsletter") {
            return "newsletter"
        } else {
            return "generale"
        }
    }
    
    private func calculateRelationshipStrength(interactionCount: Int) -> CRMRelationshipStrength {
        switch interactionCount {
        case 1...3: return .low
        case 4...10: return .medium
        default: return .high
        }
    }
}

// MARK: - CRM Contact Real Model

public struct CRMContactReal: Identifiable {
    public let id: String
    public let displayName: String
    public let email: String
    public let phone: String?
    public let company: String?
    public let jobTitle: String?
    public var lastInteractionDate: Date?
    public var interactionCount: Int
    public var relationshipStrength: CRMRelationshipStrength
    public var tags: [String]
    public var notes: String?
    public let source: CRMContactSource
    
    public var initials: String {
        let components = displayName.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

public enum CRMContactSource: String, CaseIterable {
    case email = "email"
    case calendar = "calendar"
    case manual = "manual"
    
    public var displayName: String {
        switch self {
        case .email: return "Email"
        case .calendar: return "Calendario"
        case .manual: return "Manuale"
        }
    }
    
    public var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .calendar: return "calendar"
        case .manual: return "person.badge.plus"
        }
    }
    
    public var color: Color {
        switch self {
        case .email: return .green
        case .calendar: return .orange
        case .manual: return .purple
        }
    }
}

public enum CRMRelationshipStrength: CaseIterable {
    case low, medium, high
    
    public var displayName: String {
        switch self {
        case .low: return "Bassa"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }
    
    public var color: Color {
        switch self {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        }
    }
    
    public var icon: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        }
    }
}