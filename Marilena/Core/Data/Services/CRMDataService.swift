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
    @Published public var analytics: CRMAnalytics = CRMAnalytics()
    
    private let persistenceController: PersistenceController
    private let emailCacheService: EmailCacheService
    private let calendarManager: CalendarManager
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.persistenceController = PersistenceController.shared
        self.emailCacheService = EmailCacheService()
        self.calendarManager = CalendarManager()
        
        setupAutoSync()
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
            
            // Aggiorna analytics
            updateAnalytics()
            
            print("✅ CRMDataService: Caricati \(unifiedContacts.count) contatti")
            
        } catch {
            print("❌ CRMDataService Error: \(error)")
        }
    }
    
    public func saveContactChanges(_ contactId: String, notes: String, tags: [String]) async {
        // Salva in modo persistente
        await saveContactToPersistentStore(contactId: contactId, notes: notes, tags: tags)
        
        // Aggiorna il contatto locale
        if let index = contacts.firstIndex(where: { $0.id == contactId }) {
            contacts[index].notes = notes
            contacts[index].tags = tags
        }
        
        print("✅ CRMDataService: Salvate modifiche per contatto \(contactId)")
    }
    
    public func deleteContact(_ contactId: String) async {
        // Rimuovi dalla persistenza
        await deleteContactFromPersistentStore(contactId: contactId)
        
        // Rimuovi dal cache locale
        contacts.removeAll { $0.id == contactId }
        
        print("✅ CRMDataService: Eliminato contatto \(contactId)")
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
                        self.loadSavedContactDataSync(for: &newContact)
                        
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
    
    // MARK: - Core Data Persistence
    
    private func saveContactToPersistentStore(contactId: String, notes: String, tags: [String]) async {
        let context = persistenceController.container.viewContext
        
        await context.perform {
            do {
                // Cerca se il contatto CRM esiste già
                let request = NSFetchRequest<NSManagedObject>(entityName: "CronologiaContesto")
                request.predicate = NSPredicate(format: "tipoAggiornamento == %@ AND contenuto CONTAINS %@", "crm_contact", contactId)
                
                let existingRecords = try context.fetch(request)
                let record: NSManagedObject
                
                if let existing = existingRecords.first {
                    record = existing
                } else {
                    // Crea nuovo record
                    guard let entity = NSEntityDescription.entity(forEntityName: "CronologiaContesto", in: context) else {
                        print("❌ CRMDataService: Impossibile creare entità CronologiaContesto")
                        return
                    }
                    record = NSManagedObject(entity: entity, insertInto: context)
                    record.setValue(UUID(), forKey: "id")
                    record.setValue("crm_contact", forKey: "tipoAggiornamento")
                    record.setValue(Date(), forKey: "dataSalvataggio")
                }
                
                // Salva i dati del contatto come JSON
                let contactData: [String: Any] = [
                    "contactId": contactId,
                    "notes": notes,
                    "tags": tags,
                    "lastModified": Date().timeIntervalSince1970
                ]
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: contactData),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    record.setValue(jsonString, forKey: "contenuto")
                }
                
                try context.save()
                print("✅ CRMDataService: Salvato contatto \(contactId) in Core Data")
                
            } catch {
                print("❌ CRMDataService Error nel salvataggio Core Data: \(error)")
                // Fallback a UserDefaults
                self.saveContactToUserDefaults(contactId: contactId, notes: notes, tags: tags)
            }
        }
    }
    
    private func deleteContactFromPersistentStore(contactId: String) async {
        let context = persistenceController.container.viewContext
        
        await context.perform {
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: "CronologiaContesto")
                request.predicate = NSPredicate(format: "tipoAggiornamento == %@ AND contenuto CONTAINS %@", "crm_contact", contactId)
                
                let existingRecords = try context.fetch(request)
                for record in existingRecords {
                    context.delete(record)
                }
                
                try context.save()
                print("✅ CRMDataService: Eliminato contatto \(contactId) da Core Data")
                
            } catch {
                print("❌ CRMDataService Error nell'eliminazione Core Data: \(error)")
                // Fallback a UserDefaults
                UserDefaults.standard.removeObject(forKey: "contact_\(contactId)")
            }
        }
    }
    
    private func saveContactToUserDefaults(contactId: String, notes: String, tags: [String]) {
        let key = "contact_\(contactId)"
        let data = ["notes": notes, "tags": tags, "lastModified": Date().timeIntervalSince1970] as [String: Any]
        UserDefaults.standard.set(data, forKey: key)
        print("✅ CRMDataService: Fallback - Salvato contatto \(contactId) in UserDefaults")
    }
    
    private func loadSavedContactDataSync(for contact: inout CRMContactReal) {
        // Fallback rapido a UserDefaults per chiamata sync
        let key = "contact_\(contact.id)"
        if let savedData = UserDefaults.standard.dictionary(forKey: key) {
            contact.notes = savedData["notes"] as? String
            contact.tags = savedData["tags"] as? [String] ?? contact.tags
        }
    }
    
    private func loadContactFromCoreData(contactId: String, completion: @escaping ([String: Any]?) -> Void) {
        let context = persistenceController.container.viewContext
        
        context.perform {
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: "CronologiaContesto")
                request.predicate = NSPredicate(format: "tipoAggiornamento == %@ AND contenuto CONTAINS %@", "crm_contact", contactId)
                request.fetchLimit = 1
                
                let records = try context.fetch(request)
                
                if let record = records.first,
                   let jsonString = record.value(forKey: "contenuto") as? String,
                   let jsonData = jsonString.data(using: .utf8),
                   let contactData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    DispatchQueue.main.async {
                        completion(contactData)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
                
            } catch {
                print("❌ CRMDataService Error nel caricamento Core Data: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    private func loadContactFromUserDefaults(for contact: inout CRMContactReal) {
        let key = "contact_\(contact.id)"
        if let savedData = UserDefaults.standard.dictionary(forKey: key) {
            contact.notes = savedData["notes"] as? String
            contact.tags = savedData["tags"] as? [String] ?? contact.tags
        }
    }
    
    // MARK: - Auto-Sync System
    
    private func setupAutoSync() {
        // Osserva cambiamenti nell'EmailCacheService
        emailCacheService.$cachedEmails
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.syncContactsFromEmailChanges()
                }
            }
            .store(in: &cancellables)
        
        // Sincronizzazione periodica ogni 10 minuti
        Timer.publish(every: 600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.periodicSync()
                }
            }
            .store(in: &cancellables)
        
        print("✅ CRMDataService: Auto-sync attivato")
    }
    
    private func syncContactsFromEmailChanges() async {
        print("🔄 CRMDataService: Sincronizzazione da cambiamenti email...")
        
        // Ricarica i contatti quando cambiano le email
        let oldContactsCount = contacts.count
        await loadContacts()
        
        let newContactsCount = contacts.count
        if newContactsCount != oldContactsCount {
            print("✅ CRMDataService: Rilevati \(newContactsCount - oldContactsCount) nuovi contatti")
        }
    }
    
    private func periodicSync() async {
        print("⏰ CRMDataService: Sincronizzazione periodica...")
        
        // Verifica se ci sono nuovi contatti dalle email
        await syncContactsFromEmailChanges()
        
        // Cleanup contatti obsoleti (senza interazioni da molto tempo)
        await cleanupOldContacts()
    }
    
    private func cleanupOldContacts() async {
        let sixMonthsAgo = Date().addingTimeInterval(-180 * 24 * 3600)
        let contactsToCleanup = contacts.filter { contact in
            guard let lastInteraction = contact.lastInteractionDate else {
                return true // Rimuovi contatti senza interazioni
            }
            return lastInteraction < sixMonthsAgo && contact.interactionCount <= 1
        }
        
        if !contactsToCleanup.isEmpty {
            for contact in contactsToCleanup {
                await deleteContactFromPersistentStore(contactId: contact.id)
            }
            
            // Rimuovi dal cache locale
            contacts.removeAll { contact in
                contactsToCleanup.contains { $0.id == contact.id }
            }
            
            print("🗑️ CRMDataService: Rimossi \(contactsToCleanup.count) contatti obsoleti")
        }
    }
    
    public func forceSync() async {
        print("🔄 CRMDataService: Sincronizzazione forzata...")
        isLoading = true
        await loadContacts()
        print("✅ CRMDataService: Sincronizzazione forzata completata")
    }
    
    public func pauseAutoSync() {
        cancellables.removeAll()
        print("⏸️ CRMDataService: Auto-sync sospeso")
    }
    
    public func resumeAutoSync() {
        setupAutoSync()
        print("▶️ CRMDataService: Auto-sync ripreso")
    }
    
    // MARK: - Analytics & Metrics
    
    private func updateAnalytics() {
        let now = Date()
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let oneMonthAgo = now.addingTimeInterval(-30 * 24 * 3600)
        let sixMonthsAgo = now.addingTimeInterval(-180 * 24 * 3600)
        
        let totalContacts = contacts.count
        
        // Contatti attivi (con interazioni negli ultimi 30 giorni)
        let activeContacts = contacts.filter { contact in
            guard let lastInteraction = contact.lastInteractionDate else { return false }
            return lastInteraction > oneMonthAgo
        }.count
        
        // Distribuzione per forza relazione
        let lowStrength = contacts.filter { $0.relationshipStrength == .low }.count
        let mediumStrength = contacts.filter { $0.relationshipStrength == .medium }.count  
        let highStrength = contacts.filter { $0.relationshipStrength == .high }.count
        
        // Contatti per sorgente
        let emailContacts = contacts.filter { $0.source == .email }.count
        let calendarContacts = contacts.filter { $0.source == .calendar }.count
        let manualContacts = contacts.filter { $0.source == .manual }.count
        
        // Trend settimanale e mensile
        let weeklyActiveContacts = contacts.filter { contact in
            guard let lastInteraction = contact.lastInteractionDate else { return false }
            return lastInteraction > oneWeekAgo
        }.count
        
        let monthlyActiveContacts = contacts.filter { contact in
            guard let lastInteraction = contact.lastInteractionDate else { return false }
            return lastInteraction > oneMonthAgo
        }.count
        
        // Top contatti per interazioni
        let topContactsByInteractions = contacts
            .sorted { $0.interactionCount > $1.interactionCount }
            .prefix(5)
            .map { TopContactMetric(name: $0.displayName, interactions: $0.interactionCount, lastInteraction: $0.lastInteractionDate) }
        
        // Calcolo relationship health score
        let totalInteractions = contacts.reduce(0) { $0 + $1.interactionCount }
        let averageInteractions = totalContacts > 0 ? Double(totalInteractions) / Double(totalContacts) : 0.0
        
        let healthScore = calculateHealthScore()
        
        // Trend analysis
        let growthRate = calculateGrowthRate()
        
        // Aggiorna analytics
        analytics = CRMAnalytics(
            totalContacts: totalContacts,
            activeContacts: activeContacts,
            weeklyActiveContacts: weeklyActiveContacts,
            monthlyActiveContacts: monthlyActiveContacts,
            relationshipStrengthDistribution: RelationshipStrengthDistribution(
                low: lowStrength,
                medium: mediumStrength,
                high: highStrength
            ),
            sourceDistribution: SourceDistribution(
                email: emailContacts,
                calendar: calendarContacts,
                manual: manualContacts
            ),
            topContactsByInteractions: Array(topContactsByInteractions),
            averageInteractionsPerContact: averageInteractions,
            relationshipHealthScore: healthScore,
            contactGrowthRate: growthRate,
            lastUpdated: now
        )
    }
    
    private func calculateHealthScore() -> Double {
        guard !contacts.isEmpty else { return 0.0 }
        
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 3600)
        
        // Fattori per il punteggio salute
        let recentActivityScore = Double(contacts.filter { 
            $0.lastInteractionDate ?? Date.distantPast > thirtyDaysAgo 
        }.count) / Double(contacts.count) * 40.0
        
        let highValueContactsScore = Double(contacts.filter { 
            $0.relationshipStrength == .high 
        }.count) / Double(contacts.count) * 30.0
        
        let interactionVolumeScore = min(30.0, contacts.reduce(0) { $0 + $1.interactionCount } / contacts.count)
        
        return recentActivityScore + highValueContactsScore + interactionVolumeScore
    }
    
    private func calculateGrowthRate() -> Double {
        // Implementazione semplificata - in produzione si userebbe storico
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let recentContacts = contacts.filter { contact in
            // Assumiamo che contatti con poche interazioni siano "nuovi"
            contact.interactionCount <= 2
        }.count
        
        return contacts.isEmpty ? 0.0 : Double(recentContacts) / Double(contacts.count) * 100.0
    }
    
    public func getContactsAnalytics() -> CRMAnalytics {
        return analytics
    }
    
    public func getTopContactsByCategory(_ category: ContactAnalyticsCategory) -> [CRMContactReal] {
        switch category {
        case .mostActive:
            return contacts.sorted { $0.interactionCount > $1.interactionCount }.prefix(10).map { $0 }
        case .recentInteractions:
            return contacts
                .filter { $0.lastInteractionDate != nil }
                .sorted { ($0.lastInteractionDate ?? Date.distantPast) > ($1.lastInteractionDate ?? Date.distantPast) }
                .prefix(10)
                .map { $0 }
        case .highValue:
            return contacts.filter { $0.relationshipStrength == .high }.prefix(10).map { $0 }
        case .needsAttention:
            let twoMonthsAgo = Date().addingTimeInterval(-60 * 24 * 3600)
            return contacts
                .filter { 
                    $0.relationshipStrength != .low && 
                    ($0.lastInteractionDate ?? Date.distantPast) < twoMonthsAgo 
                }
                .prefix(10)
                .map { $0 }
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