import Foundation
import CoreData
import UIKit

// MARK: - String Extensions

extension String {
    var isEmptyOrNil: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool {
        return self?.isEmptyOrNil ?? true
    }
}

// MARK: - Core Data Extensions for Enhanced Email Chat

extension MessaggioMarilena {
    // Computed properties aggiuntive per il workflow email

    // Verifica se il messaggio ha contenuto email valido
    var hasValidEmailContent: Bool {
        return emailId != nil && !(emailResponseDraft?.isEmpty ?? true)
    }

    // Ottiene il contenuto pulito per la risposta email
    var cleanEmailResponse: String {
        return emailResponseDraft?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

extension ChatMarilena {
    // Enhanced email chat features
    var hasTranscriptionContext: Bool {
        guard let messages = messaggi?.allObjects as? [MessaggioMarilena] else { return false }
        return messages.contains { $0.transcriptionId != nil }
    }
    
    var linkedTranscriptions: [String] {
        guard let messages = messaggi?.allObjects as? [MessaggioMarilena] else { return [] }
        return messages.compactMap { $0.transcriptionId }.removingDuplicates()
    }
    
    var canvasDrafts: [MessaggioMarilena] {
        guard let messages = messaggi?.allObjects as? [MessaggioMarilena] else { return [] }
        return messages.filter { $0.tipo == "email_draft_canvas" }
    }
    
    var lastEmailMessage: MessaggioMarilena? {
        guard let messages = messaggi?.allObjects as? [MessaggioMarilena] else { return nil }
        return messages
            .filter { $0.emailId != nil }
            .sorted { ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) }
            .first
    }
    
    // Enhanced workflow status
    var workflowStatus: EmailChatWorkflowStatus {
        if let lastDraft = canvasDrafts.last {
            if lastDraft.emailCanEdit {
                return .awaitingApproval
            } else {
                return .sent
            }
        } else if hasTranscriptionContext {
            return .contextGathered
        } else {
            return .initial
        }
    }
}

extension Trascrizione {
    // Email chat integration
    var isLinkedToEmailChat: Bool {
        guard let context = managedObjectContext else { return false }
        
        let fetchRequest: NSFetchRequest<MessaggioMarilena> = MessaggioMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "transcriptionId == %@", id?.uuidString ?? "")
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return !results.isEmpty
        } catch {
            return false
        }
    }
    
    var linkedEmailChats: [ChatMarilena] {
        guard let context = managedObjectContext,
              let transcriptionId = id?.uuidString else { return [] }
        
        let fetchRequest: NSFetchRequest<MessaggioMarilena> = MessaggioMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "transcriptionId == %@", transcriptionId)
        
        do {
            let messages = try context.fetch(fetchRequest)
            return Array(Set(messages.compactMap { $0.chat }))
        } catch {
            return []
        }
    }
    
    // Search within transcription for email context
    func searchRelevantContent(for keywords: [String]) -> [String] {
        guard let fullText = testoCompleto else { return [] }
        
        let sentences = fullText.components(separatedBy: ".")
        var relevantSentences: [String] = []
        
        for sentence in sentences {
            let lowercaseSentence = sentence.lowercased()
            for keyword in keywords {
                if lowercaseSentence.contains(keyword.lowercased()) {
                    relevantSentences.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    break
                }
            }
        }
        
        return relevantSentences
    }
    
    // Extract context summary for email responses
    func extractContextSummary(maxWords: Int = 100) -> String? {
        guard let fullText = testoCompleto else { return nil }
        
        let words = fullText.components(separatedBy: .whitespacesAndNewlines)
        if words.count <= maxWords {
            return fullText
        }
        
        let truncatedWords = Array(words.prefix(maxWords))
        return truncatedWords.joined(separator: " ") + "..."
    }
}

// MARK: - Workflow Status Enum

public enum EmailChatWorkflowStatus: String, CaseIterable {
    case initial = "initial"
    case contextGathered = "context_gathered"
    case draftGenerated = "draft_generated"
    case awaitingApproval = "awaiting_approval"
    case sent = "sent"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .initial:
            return "Iniziale"
        case .contextGathered:
            return "Contesto raccolto"
        case .draftGenerated:
            return "Bozza generata"
        case .awaitingApproval:
            return "In attesa di approvazione"
        case .sent:
            return "Inviato"
        case .completed:
            return "Completato"
        }
    }
    
    var icon: String {
        switch self {
        case .initial:
            return "envelope"
        case .contextGathered:
            return "doc.text.magnifyingglass"
        case .draftGenerated:
            return "pencil.and.outline"
        case .awaitingApproval:
            return "checkmark.circle"
        case .sent:
            return "paperplane.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    var color: UIColor {
        switch self {
        case .initial:
            return .systemBlue
        case .contextGathered:
            return .systemOrange
        case .draftGenerated:
            return .systemYellow
        case .awaitingApproval:
            return .systemPurple
        case .sent:
            return .systemGreen
        case .completed:
            return .systemGreen
        }
    }
}

// MARK: - Helper Extensions

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        return Array(Set(self))
    }
}

extension NSManagedObjectContext {
    // Convenience methods for enhanced email chat
    
    func findEmailChat(for sender: String) -> ChatMarilena? {
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "emailSender == %@ AND tipo == %@", sender, "email")
        fetchRequest.fetchLimit = 1
        
        return try? fetch(fetchRequest).first
    }
    
    func findTranscription(by id: UUID) -> Trascrizione? {
        let fetchRequest: NSFetchRequest<Trascrizione> = Trascrizione.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        return try? fetch(fetchRequest).first
    }
    
    func recentTranscriptions(limit: Int = 10) -> [Trascrizione] {
        let fetchRequest: NSFetchRequest<Trascrizione> = Trascrizione.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Trascrizione.dataCreazione, ascending: false)]
        fetchRequest.fetchLimit = limit
        
        return (try? fetch(fetchRequest)) ?? []
    }
    
    func emailChatsWithCanvas() -> [ChatMarilena] {
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "SUBQUERY(messaggi, $m, $m.tipo == %@).@count > 0", "email_draft_canvas")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMarilena.lastEmailDate, ascending: false)]
        
        return (try? fetch(fetchRequest)) ?? []
    }
}