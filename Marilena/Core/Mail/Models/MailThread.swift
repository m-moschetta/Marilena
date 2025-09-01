import Foundation

/// Rappresenta un thread/conversazione di email
public struct MailThread: Identifiable, Codable {
    public let id: String
    public let subject: String
    public let participants: Set<MailParticipant>
    public let messageIds: [String]
    public let labels: Set<String>
    public let createdAt: Date
    public let lastActivity: Date
    public let providerId: String
    public let unreadCount: Int
    public let totalCount: Int

    /// Messaggio più recente nel thread
    public var latestMessage: MailMessage? {
        // Questo sarà popolato dal service quando necessario
        nil
    }

    /// Soggetto normalizzato (senza "Re:", "Fwd:", etc.)
    public var normalizedSubject: String {
        normalizeSubject(subject)
    }

    /// Verifica se il thread ha messaggi non letti
    public var hasUnreadMessages: Bool {
        unreadCount > 0
    }

    public init(
        id: String,
        subject: String,
        participants: Set<MailParticipant>,
        messageIds: [String],
        labels: Set<String> = [],
        createdAt: Date,
        lastActivity: Date,
        providerId: String,
        unreadCount: Int = 0,
        totalCount: Int = 0
    ) {
        self.id = id
        self.subject = subject
        self.participants = participants
        self.messageIds = messageIds
        self.labels = labels
        self.createdAt = createdAt
        self.lastActivity = lastActivity
        self.providerId = providerId
        self.unreadCount = unreadCount
        self.totalCount = totalCount
    }

    /// Aggiunge un messaggio al thread
    public func addingMessage(_ message: MailMessage) -> MailThread {
        var newMessageIds = messageIds
        if !newMessageIds.contains(message.id) {
            newMessageIds.append(message.id)
        }

        var newParticipants = participants
        newParticipants.insert(message.from)
        newParticipants.formUnion(message.to)
        newParticipants.formUnion(message.cc)
        newParticipants.formUnion(message.bcc)

        var newLabels = labels
        newLabels.formUnion(message.labels)

        let newUnreadCount = message.flags.isRead ? unreadCount : unreadCount + 1

        return MailThread(
            id: id,
            subject: message.subject, // Aggiorna soggetto con quello del messaggio più recente
            participants: newParticipants,
            messageIds: newMessageIds.sorted { $0 < $1 }, // Mantiene ordine per consistenza
            labels: newLabels,
            createdAt: createdAt,
            lastActivity: max(lastActivity, message.date),
            providerId: providerId,
            unreadCount: newUnreadCount,
            totalCount: totalCount + (newMessageIds.count > messageIds.count ? 1 : 0)
        )
    }

    /// Marca il thread come letto
    public func markingAsRead() -> MailThread {
        MailThread(
            id: id,
            subject: subject,
            participants: participants,
            messageIds: messageIds,
            labels: labels,
            createdAt: createdAt,
            lastActivity: lastActivity,
            providerId: providerId,
            unreadCount: 0,
            totalCount: totalCount
        )
    }

    /// Aggiunge una label al thread
    public func addingLabel(_ label: String) -> MailThread {
        var newLabels = labels
        newLabels.insert(label)

        return MailThread(
            id: id,
            subject: subject,
            participants: participants,
            messageIds: messageIds,
            labels: newLabels,
            createdAt: createdAt,
            lastActivity: lastActivity,
            providerId: providerId,
            unreadCount: unreadCount,
            totalCount: totalCount
        )
    }

    /// Rimuove una label dal thread
    public func removingLabel(_ label: String) -> MailThread {
        var newLabels = labels
        newLabels.remove(label)

        return MailThread(
            id: id,
            subject: subject,
            participants: participants,
            messageIds: messageIds,
            labels: newLabels,
            createdAt: createdAt,
            lastActivity: lastActivity,
            providerId: providerId,
            unreadCount: unreadCount,
            totalCount: totalCount
        )
    }

    /// Normalizza il soggetto rimuovendo prefissi comuni
    private func normalizeSubject(_ subject: String) -> String {
        var normalized = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rimuovi prefissi comuni (case insensitive)
        let prefixesToRemove = ["Re:", "RE:", "Fwd:", "FWD:", "Fw:", "FW:", "Fwd :", "Re :",
                               "R:", "R :", "Ri:", "Ri :", "I:", "Oggetto:"]

        for prefix in prefixesToRemove {
            while normalized.lowercased().hasPrefix(prefix.lowercased()) {
                normalized = String(normalized.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return normalized.isEmpty ? "Nessun oggetto" : normalized
    }
}
