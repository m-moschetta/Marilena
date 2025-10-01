import Foundation

/// Servizio dedicato al threading/raggruppamento delle email in conversazioni
public final class EmailThreadingManager {

    // MARK: - Public Methods

    /// Organizza email in conversazioni basate su subject e participants
    public func organizeIntoConversations(_ emails: [EmailMessage]) -> [EmailConversation] {
        var conversationDict: [String: [EmailMessage]] = [:]

        for email in emails {
            let key = conversationKey(for: email)
            conversationDict[key, default: []].append(email)
        }

        return conversationDict.map { (key, messages) in
            createConversation(from: messages)
        }.sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: - Private Methods

    /// Genera chiave univoca per raggruppare email della stessa conversazione
    private func conversationKey(for email: EmailMessage) -> String {
        // Normalizza subject rimuovendo prefissi comuni (Re:, Fwd:, etc.)
        let normalizedSubject = normalizeSubject(email.subject)

        // Crea set di partecipanti univoci
        var participants = Set<String>()
        participants.insert(email.from.lowercased())
        email.to.forEach { participants.insert($0.lowercased()) }

        let sortedParticipants = participants.sorted().joined(separator: "|")

        return "\(normalizedSubject)|\(sortedParticipants)"
    }

    /// Normalizza subject rimuovendo prefissi comuni
    private func normalizeSubject(_ subject: String) -> String {
        var normalized = subject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Rimuovi prefissi comuni iterativamente
        let prefixes = ["re:", "fwd:", "fw:", "r:", "ri:", "rif:", "i:"]

        var changed = true
        while changed {
            changed = false
            for prefix in prefixes {
                if normalized.hasPrefix(prefix) {
                    normalized = String(normalized.dropFirst(prefix.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    changed = true
                    break
                }
            }
        }

        return normalized
    }

    /// Crea conversazione da gruppo di email
    private func createConversation(from messages: [EmailMessage]) -> EmailConversation {
        let sortedMessages = messages.sorted { $0.date < $1.date }

        guard let firstMessage = sortedMessages.first else {
            return EmailConversation(
                id: UUID().uuidString,
                subject: "Empty Conversation",
                messages: [],
                participants: Set<String>(),
                createdAt: Date(),
                lastActivity: Date()
            )
        }

        let subject = firstMessage.subject
        let createdAt = firstMessage.date
        let lastActivity = sortedMessages.last?.date ?? firstMessage.date

        // Raccogli partecipanti univoci
        var participantsSet = Set<String>()
        for message in sortedMessages {
            participantsSet.insert(message.from)
            message.to.forEach { participantsSet.insert($0) }
        }

        return EmailConversation(
            id: UUID().uuidString,
            subject: subject,
            messages: sortedMessages,
            participants: participantsSet,
            createdAt: createdAt,
            lastActivity: lastActivity
        )
    }
}
