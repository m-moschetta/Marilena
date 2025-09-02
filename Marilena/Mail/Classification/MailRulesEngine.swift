//
//  MailRulesEngine.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Engine per l'applicazione di regole deterministiche di classificazione
//  Supporta condizioni composte AND/OR e priorità delle regole
//

import Foundation

/// Engine per l'applicazione di regole deterministiche
public final class MailRulesEngine {

    // MARK: - Properties

    private var rules: [MailFilterRule] = []
    private let queue = DispatchQueue(label: "com.marilena.mail.rules", qos: .userInitiated)

    // MARK: - Initialization

    public init() {
        setupDefaultRules()
    }

    // MARK: - Public Methods

    /// Applica tutte le regole attive a un messaggio
    public func applyRules(to message: MailMessage, accountId: String) async throws -> [MailCategory] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var categories: [MailCategory] = []
                var appliedRules: Set<String> = []

                // Ordina le regole per priorità (più alta prima)
                let sortedRules = self.rules.sorted { $0.priority > $1.priority }

                for rule in sortedRules {
                    // Salta se la regola è già stata applicata da una regola di priorità più alta
                    if appliedRules.contains(rule.id) {
                        continue
                    }

                    if self.evaluateRule(rule, for: message) {
                        // Applica le azioni della regola
                        if let category = self.applyRuleActions(rule, to: message) {
                            categories.append(category)
                            appliedRules.insert(rule.id)
                        }
                    }
                }

                continuation.resume(returning: categories)
            }
        }
    }

    /// Aggiunge una nuova regola
    public func addRule(_ rule: MailFilterRule) {
        queue.async {
            self.rules.append(rule)
            self.rules.sort { $0.priority > $1.priority }
        }
    }

    /// Rimuove una regola
    public func removeRule(withId ruleId: String) {
        queue.async {
            self.rules.removeAll { $0.id == ruleId }
        }
    }

    /// Aggiorna una regola esistente
    public func updateRule(_ rule: MailFilterRule) {
        queue.async {
            if let index = self.rules.firstIndex(where: { $0.id == rule.id }) {
                self.rules[index] = rule
                self.rules.sort { $0.priority > $1.priority }
            }
        }
    }

    // MARK: - Private Methods

    private func setupDefaultRules() {
        // Regola per email importanti (da VIP)
        let vipRule = MailFilterRule(
            id: "vip-emails",
            name: "Email VIP",
            conditions: [
                MailFilterCondition(
                    field: .from,
                    filterOperator: .contains,
                    value: "@company.com"
                )
            ],
            actions: [.applyCategory(.important)],
            priority: 100,
            isEnabled: true
        )

        // Regola per notifiche di sistema
        let systemRule = MailFilterRule(
            id: "system-notifications",
            name: "Notifiche Sistema",
            conditions: [
                MailFilterCondition(
                    field: .from,
                    filterOperator: .contains,
                    value: "noreply@"
                ),
                MailFilterCondition(
                    field: .subject,
                    filterOperator: .contains,
                    value: "notification"
                )
            ],
            actions: [.applyCategory(.notifications)],
            priority: 90,
            isEnabled: true
        )

        // Regola per email di marketing
        let marketingRule = MailFilterRule(
            id: "marketing-emails",
            name: "Marketing",
            conditions: [
                MailFilterCondition(
                    field: .from,
                    filterOperator: .contains,
                    value: "@newsletter"
                )
            ],
            actions: [.applyCategory(.marketing)],
            priority: 80,
            isEnabled: true
        )

        // Regola per fatture
        let invoiceRule = MailFilterRule(
            id: "invoice-emails",
            name: "Fatture",
            conditions: [
                MailFilterCondition(
                    field: .subject,
                    filterOperator: .contains,
                    value: "fattura"
                ),
                MailFilterCondition(
                    field: .subject,
                    filterOperator: .contains,
                    value: "invoice"
                )
            ],
            actions: [.applyCategory(.bills)],
            priority: 85,
            isEnabled: true
        )

        rules = [vipRule, systemRule, marketingRule, invoiceRule]
    }

    private func evaluateRule(_ rule: MailFilterRule, for message: MailMessage) -> Bool {
        // Per ora implementiamo AND semplice (tutte le condizioni devono essere vere)
        // TODO: Implementare condizioni composte AND/OR
        for condition in rule.conditions {
            if !evaluateCondition(condition, for: message) {
                return false
            }
        }
        return true
    }

    private func evaluateCondition(_ condition: MailFilterCondition, for message: MailMessage) -> Bool {
        let fieldValue = getFieldValue(condition.field, from: message)

        switch condition.filterOperator {
        case .contains:
            return fieldValue.lowercased().contains(condition.value.lowercased())
        case .notContains:
            return !fieldValue.lowercased().contains(condition.value.lowercased())
        case .equals:
            return fieldValue.lowercased() == condition.value.lowercased()
        case .notEquals:
            return fieldValue.lowercased() != condition.value.lowercased()
        case .startsWith:
            return fieldValue.lowercased().hasPrefix(condition.value.lowercased())
        case .endsWith:
            return fieldValue.lowercased().hasSuffix(condition.value.lowercased())
        case .greaterThan:
            // Per ora supporto solo confronto stringa
            return fieldValue > condition.value
        case .lessThan:
            return fieldValue < condition.value
        }
    }

    private func getFieldValue(_ field: MailFilterField, from message: MailMessage) -> String {
        switch field {
        case .from:
            return message.from.email
        case .to:
            return message.to.map { $0.email }.joined(separator: ", ")
        case .cc:
            return message.cc?.map { $0.email }.joined(separator: ", ") ?? ""
        case .bcc:
            return message.bcc?.map { $0.email }.joined(separator: ", ") ?? ""
        case .subject:
            return message.subject
        case .body:
            return message.bodyPlain ?? ""
        case .hasAttachment:
            return message.attachments?.isEmpty == false ? "true" : "false"
        case .date:
            return message.date.description
        case .size:
            return "\(message.size ?? 0)"
        }
    }

    private func applyRuleActions(_ rule: MailFilterRule, to message: MailMessage) -> MailCategory? {
        for action in rule.actions {
            switch action {
            case .applyCategory(let category):
                return category
            case .applyLabel(let label):
                // TODO: Implementare applicazione label
                break
            case .moveToFolder(let folder):
                // TODO: Implementare spostamento folder
                break
            case .markAsRead:
                // TODO: Implementare mark as read
                break
            case .archive:
                // TODO: Implementare archiviazione
                break
            case .delete:
                // TODO: Implementare cancellazione
                break
            case .forward(let address):
                // TODO: Implementare forward
                break
            }
        }
        return nil
    }
}

// MARK: - Supporting Types

/// Campo su cui applicare la condizione
public enum MailFilterField {
    case from
    case to
    case cc
    case bcc
    case subject
    case body
    case hasAttachment
    case date
    case size
}

/// Operatore per la condizione
public enum MailFilterOperator {
    case contains
    case notContains
    case equals
    case notEquals
    case startsWith
    case endsWith
    case greaterThan
    case lessThan
}

/// Azione da applicare quando la regola matcha
public enum MailFilterAction {
    case applyCategory(MailCategory)
    case applyLabel(String)
    case moveToFolder(String)
    case markAsRead
    case archive
    case delete
    case forward(String)
}

/// Regola di filtro completa
public struct MailFilterRule: Identifiable, Codable {
    public let id: String
    public let name: String
    public let conditions: [MailFilterCondition]
    public let actions: [MailFilterAction]
    public let priority: Int
    public let isEnabled: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        conditions: [MailFilterCondition],
        actions: [MailFilterAction],
        priority: Int,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.conditions = conditions
        self.actions = actions
        self.priority = priority
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Condizione del filtro
public struct MailFilterCondition: Codable {
    public let field: MailFilterField
    public let filterOperator: MailFilterOperator
    public let value: String

    public init(field: MailFilterField, filterOperator: MailFilterOperator, value: String) {
        self.field = field
        self.filterOperator = filterOperator
        self.value = value
    }
}

/// Categoria email
public enum MailCategory: String, Codable {
    case inbox = "inbox"
    case important = "important"
    case personal = "personal"
    case work = "work"
    case marketing = "marketing"
    case notifications = "notifications"
    case bills = "bills"
    case social = "social"
    case travel = "travel"
    case finance = "finance"
}
