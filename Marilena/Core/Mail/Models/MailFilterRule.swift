import Foundation

/// Regola di filtro per categorizzare automaticamente le email
public struct MailFilterRule: Identifiable, Codable {
    public let id: String
    public let name: String
    public let conditions: [MailFilterCondition]
    public let actions: [MailFilterAction]
    public let priority: Int
    public let isEnabled: Bool
    public let createdAt: Date
    public let lastTriggeredAt: Date?
    public let triggerCount: Int

    /// Verifica se una regola si applica a un messaggio
    public func matches(message: MailMessage) -> Bool {
        guard isEnabled else { return false }

        // Tutte le condizioni devono essere soddisfatte (AND logico)
        for condition in conditions {
            if !condition.matches(message: message) {
                return false
            }
        }

        return true
    }

    /// Applica le azioni della regola a un messaggio
    public func applyActions(to message: MailMessage) -> MailMessage {
        var updatedMessage = message

        for action in actions {
            updatedMessage = action.apply(to: updatedMessage)
        }

        return updatedMessage
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        conditions: [MailFilterCondition],
        actions: [MailFilterAction],
        priority: Int = 0,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        lastTriggeredAt: Date? = nil,
        triggerCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.conditions = conditions
        self.actions = actions
        self.priority = priority
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastTriggeredAt = lastTriggeredAt
        self.triggerCount = triggerCount
    }

    /// Crea una regola aggiornata con il trigger incrementato
    public func triggered() -> MailFilterRule {
        MailFilterRule(
            id: id,
            name: name,
            conditions: conditions,
            actions: actions,
            priority: priority,
            isEnabled: isEnabled,
            createdAt: createdAt,
            lastTriggeredAt: Date(),
            triggerCount: triggerCount + 1
        )
    }
}

/// Condizione per una regola di filtro
public struct MailFilterCondition: Codable {
    public let type: MailFilterConditionType
    public let value: String
    public let isCaseSensitive: Bool
    public let operator: MailFilterOperator

    /// Verifica se la condizione corrisponde al messaggio
    public func matches(message: MailMessage) -> Bool {
        let searchValue = isCaseSensitive ? value : value.lowercased()
        let messageValue: String

        switch type {
        case .from:
            messageValue = isCaseSensitive ? message.from.email : message.from.email.lowercased()
        case .to:
            let emails = message.to.map { isCaseSensitive ? $0.email : $0.email.lowercased() }
            return `operator`.evaluate(emails, searchValue)
        case .cc:
            let emails = message.cc.map { isCaseSensitive ? $0.email : $0.email.lowercased() }
            return `operator`.evaluate(emails, searchValue)
        case .subject:
            messageValue = isCaseSensitive ? message.subject : message.subject.lowercased()
        case .body:
            let bodyText = message.bodyPlain ?? message.bodyHTML ?? ""
            messageValue = isCaseSensitive ? bodyText : bodyText.lowercased()
        case .hasAttachment:
            return `operator`.evaluate(message.attachments.isEmpty ? ["false"] : ["true"], searchValue)
        case .size:
            return `operator`.evaluate([String(message.size)], searchValue)
        case .date:
            return `operator`.evaluate([String(message.date.timeIntervalSince1970)], searchValue)
        case .label:
            return `operator`.evaluate(message.labels, searchValue)
        }

        return `operator`.evaluate([messageValue], searchValue)
    }

    public init(
        type: MailFilterConditionType,
        value: String,
        isCaseSensitive: Bool = false,
        operator: MailFilterOperator = .contains
    ) {
        self.type = type
        self.value = value
        self.isCaseSensitive = isCaseSensitive
        self.operator = `operator`
    }
}

/// Tipo di condizione per il filtro
public enum MailFilterConditionType: String, Codable {
    case from
    case to
    case cc
    case subject
    case body
    case hasAttachment
    case size
    case date
    case label
}

/// Operatore per la condizione
public enum MailFilterOperator: String, Codable {
    case contains
    case equals
    case startsWith
    case endsWith
    case greaterThan
    case lessThan
    case isEmpty
    case isNotEmpty

    func evaluate(_ values: [String], _ searchValue: String) -> Bool {
        switch self {
        case .contains:
            return values.contains { $0.contains(searchValue) }
        case .equals:
            return values.contains { $0 == searchValue }
        case .startsWith:
            return values.contains { $0.hasPrefix(searchValue) }
        case .endsWith:
            return values.contains { $0.hasSuffix(searchValue) }
        case .greaterThan:
            return values.contains { value in
                guard let num = Double(value), let searchNum = Double(searchValue) else { return false }
                return num > searchNum
            }
        case .lessThan:
            return values.contains { value in
                guard let num = Double(value), let searchNum = Double(searchValue) else { return false }
                return num < searchNum
            }
        case .isEmpty:
            return values.allSatisfy { $0.isEmpty }
        case .isNotEmpty:
            return values.allSatisfy { !$0.isEmpty }
        }
    }
}

/// Azione da applicare quando una regola corrisponde
public struct MailFilterAction: Codable {
    public let type: MailFilterActionType
    public let value: String?

    /// Applica l'azione a un messaggio
    public func apply(to message: MailMessage) -> MailMessage {
        switch type {
        case .applyLabel:
            guard let label = value else { return message }
            var newLabels = message.labels
            if !newLabels.contains(label) {
                newLabels.append(label)
            }
            return MailMessage(
                id: message.id,
                threadId: message.threadId,
                subject: message.subject,
                bodyPlain: message.bodyPlain,
                bodyHTML: message.bodyHTML,
                snippet: message.snippet,
                from: message.from,
                to: message.to,
                cc: message.cc,
                bcc: message.bcc,
                date: message.date,
                labels: newLabels,
                flags: message.flags,
                attachments: message.attachments,
                providerId: message.providerId,
                providerThreadKey: message.providerThreadKey,
                size: message.size
            )

        case .removeLabel:
            guard let label = value else { return message }
            let newLabels = message.labels.filter { $0 != label }
            return MailMessage(
                id: message.id,
                threadId: message.threadId,
                subject: message.subject,
                bodyPlain: message.bodyPlain,
                bodyHTML: message.bodyHTML,
                snippet: message.snippet,
                from: message.from,
                to: message.to,
                cc: message.cc,
                bcc: message.bcc,
                date: message.date,
                labels: newLabels,
                flags: message.flags,
                attachments: message.attachments,
                providerId: message.providerId,
                providerThreadKey: message.providerThreadKey,
                size: message.size
            )

        case .markAsRead:
            let newFlags = MailMessageFlags(
                isRead: true,
                isStarred: message.flags.isStarred,
                isDeleted: message.flags.isDeleted,
                isDraft: message.flags.isDraft,
                isAnswered: message.flags.isAnswered,
                isForwarded: message.flags.isForwarded
            )
            return MailMessage(
                id: message.id,
                threadId: message.threadId,
                subject: message.subject,
                bodyPlain: message.bodyPlain,
                bodyHTML: message.bodyHTML,
                snippet: message.snippet,
                from: message.from,
                to: message.to,
                cc: message.cc,
                bcc: message.bcc,
                date: message.date,
                labels: message.labels,
                flags: newFlags,
                attachments: message.attachments,
                providerId: message.providerId,
                providerThreadKey: message.providerThreadKey,
                size: message.size
            )

        case .markAsImportant:
            var newLabels = message.labels
            let importantLabel = "IMPORTANT"
            if !newLabels.contains(importantLabel) {
                newLabels.append(importantLabel)
            }
            return MailMessage(
                id: message.id,
                threadId: message.threadId,
                subject: message.subject,
                bodyPlain: message.bodyPlain,
                bodyHTML: message.bodyHTML,
                snippet: message.snippet,
                from: message.from,
                to: message.to,
                cc: message.cc,
                bcc: message.bcc,
                date: message.date,
                labels: newLabels,
                flags: message.flags,
                attachments: message.attachments,
                providerId: message.providerId,
                providerThreadKey: message.providerThreadKey,
                size: message.size
            )

        case .archive:
            var newLabels = message.labels
            let archiveLabel = "ARCHIVE"
            if !newLabels.contains(archiveLabel) {
                newLabels.append(archiveLabel)
            }
            return MailMessage(
                id: message.id,
                threadId: message.threadId,
                subject: message.subject,
                bodyPlain: message.bodyPlain,
                bodyHTML: message.bodyHTML,
                snippet: message.snippet,
                from: message.from,
                to: message.to,
                cc: message.cc,
                bcc: message.bcc,
                date: message.date,
                labels: newLabels,
                flags: message.flags,
                attachments: message.attachments,
                providerId: message.providerId,
                providerThreadKey: message.providerThreadKey,
                size: message.size
            )
        }
    }

    public init(type: MailFilterActionType, value: String? = nil) {
        self.type = type
        self.value = value
    }
}

/// Tipo di azione per il filtro
public enum MailFilterActionType: String, Codable {
    case applyLabel
    case removeLabel
    case markAsRead
    case markAsImportant
    case archive
}
