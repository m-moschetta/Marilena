//
//  MailClassificationEngine.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Engine di classificazione per categorizzare automaticamente le email
//  Supporta regole deterministiche e segnali ML
//

import Foundation
import Combine

/// Engine principale per la classificazione email
public final class MailClassificationEngine {

    // MARK: - Properties

    private let rulesEngine: MailRulesEngine
    private let signalsProcessor: MailSignalsProcessor
    private let storage: MailStorageProtocol
    private let queue = DispatchQueue(label: "com.marilena.mail.classification", qos: .utility)

    // MARK: - Initialization

    public init(storage: MailStorageProtocol) {
        self.storage = storage
        self.rulesEngine = MailRulesEngine()
        self.signalsProcessor = MailSignalsProcessor()
    }

    // MARK: - Public Methods

    /// Classifica una singola email
    public func classifyEmail(_ email: MailMessage, for accountId: String) async throws -> MailMessage {
        var classifiedEmail = email

        // Prima applica le regole deterministiche
        let ruleCategories = try await applyRules(to: email, accountId: accountId)

        // Poi applica i segnali ML se necessario
        let signalCategories = await processSignals(for: email)

        // Combina i risultati (regole hanno priorità sui segnali)
        let finalCategory = determineFinalCategory(ruleCategories: ruleCategories, signalCategories: signalCategories)

        // Applica la categoria finale
        if let category = finalCategory {
            classifiedEmail = applyCategory(category, to: email)
        }

        return classifiedEmail
    }

    /// Classifica un batch di email
    public func classifyEmails(_ emails: [MailMessage], for accountId: String) async throws -> [MailMessage] {
        try await withThrowingTaskGroup(of: MailMessage.self) { group in
            for email in emails {
                group.addTask {
                    try await self.classifyEmail(email, for: accountId)
                }
            }

            var classifiedEmails: [MailMessage] = []
            for try await classifiedEmail in group {
                classifiedEmails.append(classifiedEmail)
            }

            return classifiedEmails
        }
    }

    /// Applica regole di filtro personalizzate
    public func applyFilterRules(_ email: MailMessage, for accountId: String) async throws -> [MailFilterAction] {
        let rules = try await storage.loadFilterRules(for: accountId)
        return rulesEngine.evaluateRules(rules, for: email)
    }

    // MARK: - Private Methods

    private func applyRules(to email: MailMessage, accountId: String) async throws -> [MailCategory] {
        let rules = try await storage.loadFilterRules(for: accountId)
        let actions = rulesEngine.evaluateRules(rules, for: email)

        // Estrai le categorie dalle azioni di filtro
        return actions.compactMap { action in
            switch action {
            case .applyLabel(let labelId):
                // Converti label ID in categoria
                return MailCategory.fromLabelId(labelId)
            default:
                return nil
            }
        }
    }

    private func processSignals(for email: MailMessage) async -> [MailCategory] {
        // Implementazione segnali ML (placeholder)
        // In futuro: chiama servizio ML per scoring categorie
        signalsProcessor.analyzeSignals(for: email)
    }

    private func determineFinalCategory(ruleCategories: [MailCategory], signalCategories: [MailCategory]) -> MailCategory? {
        // Regole hanno priorità assoluta
        if let ruleCategory = ruleCategories.first {
            return ruleCategory
        }

        // Altrimenti usa il segnale con score più alto
        return signalCategories.first
    }

    private func applyCategory(_ category: MailCategory, to email: MailMessage) -> MailMessage {
        var updatedEmail = email

        // Aggiungi la label corrispondente alla categoria
        let labelId = category.toLabelId()
        if !updatedEmail.labels.contains(labelId) {
            updatedEmail.labels.append(labelId)
        }

        return updatedEmail
    }
}

// MARK: - Rules Engine

private class MailRulesEngine {

    func evaluateRules(_ rules: [MailFilterRule], for email: MailMessage) -> [MailFilterAction] {
        var actions: [MailFilterAction] = []

        // Ordina regole per priorità (più alta prima)
        let sortedRules = rules
            .filter { $0.isEnabled }
            .sorted { $0.priority > $1.priority }

        for rule in sortedRules {
            if evaluateRule(rule, for: email) {
                actions.append(contentsOf: rule.actions)
            }
        }

        return actions
    }

    private func evaluateRule(_ rule: MailFilterRule, for email: MailMessage) -> Bool {
        // Valuta tutte le condizioni (AND logico)
        for condition in rule.conditions {
            if !evaluateCondition(condition, for: email) {
                return false
            }
        }
        return true
    }

    private func evaluateCondition(_ condition: MailFilterCondition, for email: MailMessage) -> Bool {
        let fieldValue = getFieldValue(condition.field, from: email)

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
            return compareValues(fieldValue, condition.value) > 0
        case .lessThan:
            return compareValues(fieldValue, condition.value) < 0
        }
    }

    private func getFieldValue(_ field: MailFilterField, from email: MailMessage) -> String {
        switch field {
        case .from:
            return email.from.email
        case .to:
            return email.to.map { $0.email }.joined(separator: ",")
        case .cc:
            return email.cc.map { $0.email }.joined(separator: ",")
        case .subject:
            return email.subject
        case .body:
            return email.body.displayText
        case .hasAttachment:
            return email.attachments.isEmpty ? "false" : "true"
        case .size:
            return String(email.size ?? 0)
        case .date:
            return String(email.date.timeIntervalSince1970)
        }
    }

    private func compareValues(_ value1: String, _ value2: String) -> Int {
        // Implementazione di confronto per valori numerici/date
        if let num1 = Double(value1), let num2 = Double(value2) {
            return num1 > num2 ? 1 : (num1 < num2 ? -1 : 0)
        }
        return value1.compare(value2).rawValue
    }
}

// MARK: - Signals Processor

private class MailSignalsProcessor {

    func analyzeSignals(for email: MailMessage) -> [MailCategory] {
        var categories: [MailCategory] = []
        var scores: [MailCategory: Double] = [:]

        // Analizza il mittente
        analyzeSender(email.from, scores: &scores)

        // Analizza l'oggetto
        analyzeSubject(email.subject, scores: &scores)

        // Analizza il corpo
        analyzeBody(email.body.displayText, scores: &scores)

        // Analizza gli allegati
        analyzeAttachments(email.attachments, scores: &scores)

        // Analizza l'orario
        analyzeTime(email.date, scores: &scores)

        // Seleziona le categorie con score più alto
        let topCategories = scores
            .sorted { $0.value > $1.value }
            .prefix(2) // Max 2 categorie
            .map { $0.key }

        categories.append(contentsOf: topCategories)
        return categories
    }

    private func analyzeSender(_ sender: MailParticipant, scores: inout [MailCategory: Double]) {
        let email = sender.email.lowercased()
        let name = sender.name?.lowercased() ?? ""

        // Email aziendali
        if email.contains("@company.com") || email.contains("@business.com") {
            scores[.work] = (scores[.work] ?? 0) + 2.0
        }

        // Servizi finanziari
        if email.contains("@bank") || email.contains("@paypal") || email.contains("@stripe") {
            scores[.finance] = (scores[.finance] ?? 0) + 3.0
        }

        // Social media
        if email.contains("@facebook") || email.contains("@twitter") || email.contains("@linkedin") {
            scores[.social] = (scores[.social] ?? 0) + 2.0
        }

        // Shopping
        if email.contains("@amazon") || email.contains("@ebay") || email.contains("@shop") {
            scores[.shopping] = (scores[.shopping] ?? 0) + 2.0
        }

        // Promozioni
        if email.contains("noreply") || email.contains("no-reply") || email.contains("newsletter") {
            scores[.promotions] = (scores[.promotions] ?? 0) + 1.5
        }
    }

    private func analyzeSubject(_ subject: String, scores: inout [MailCategory: Double]) {
        let lowerSubject = subject.lowercased()

        // Parole chiave per categorie
        if lowerSubject.contains("invoice") || lowerSubject.contains("fattura") || lowerSubject.contains("payment") {
            scores[.finance] = (scores[.finance] ?? 0) + 2.0
        }

        if lowerSubject.contains("meeting") || lowerSubject.contains("riunione") || lowerSubject.contains("call") {
            scores[.work] = (scores[.work] ?? 0) + 1.5
        }

        if lowerSubject.contains("promotion") || lowerSubject.contains("offerta") || lowerSubject.contains("sconto") {
            scores[.promotions] = (scores[.promotions] ?? 0) + 2.0
        }
    }

    private func analyzeBody(_ body: String, scores: inout [MailCategory: Double]) {
        let lowerBody = body.lowercased()

        // Analizza lunghezza e contenuto
        if body.count < 100 {
            scores[.notifications] = (scores[.notifications] ?? 0) + 1.0
        }

        if lowerBody.contains("unsubscribe") || lowerBody.contains("newsletter") {
            scores[.promotions] = (scores[.promotions] ?? 0) + 1.5
        }
    }

    private func analyzeAttachments(_ attachments: [MailAttachment], scores: inout [MailCategory: Double]) {
        if !attachments.isEmpty {
            scores[.work] = (scores[.work] ?? 0) + 0.5
        }
    }

    private func analyzeTime(_ date: Date, scores: inout [MailCategory: Double]) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Email di lavoro tipicamente durante orari lavorativi
        if hour >= 9 && hour <= 17 {
            scores[.work] = (scores[.work] ?? 0) + 0.5
        }

        // Email personali spesso fuori orario
        if hour < 9 || hour > 17 {
            scores[.personal] = (scores[.personal] ?? 0) + 0.5
        }
    }
}

// MARK: - Mail Categories

/// Categorie di email supportate
public enum MailCategory: String, Codable, CaseIterable {
    case work = "work"
    case personal = "personal"
    case finance = "finance"
    case shopping = "shopping"
    case social = "social"
    case promotions = "promotions"
    case notifications = "notifications"
    case travel = "travel"

    public var displayName: String {
        switch self {
        case .work: return "Lavoro"
        case .personal: return "Personale"
        case .finance: return "Finanza"
        case .shopping: return "Shopping"
        case .social: return "Social"
        case .promotions: return "Promozioni"
        case .notifications: return "Notifiche"
        case .travel: return "Viaggi"
        }
    }

    public var iconName: String {
        switch self {
        case .work: return "briefcase"
        case .personal: return "person"
        case .finance: return "creditcard"
        case .shopping: return "bag"
        case .social: return "person.2"
        case .promotions: return "tag"
        case .notifications: return "bell"
        case .travel: return "airplane"
        }
    }

    public var color: String {
        switch self {
        case .work: return "#007AFF"
        case .personal: return "#34C759"
        case .finance: return "#FF9500"
        case .shopping: return "#FF3B30"
        case .social: return "#AF52DE"
        case .promotions: return "#FFCC00"
        case .notifications: return "#8E8E93"
        case .travel: return "#5AC8FA"
        }
    }

    /// Converte categoria in label ID
    func toLabelId() -> String {
        "category_\(rawValue)"
    }

    /// Crea categoria da label ID
    static func fromLabelId(_ labelId: String) -> MailCategory? {
        let components = labelId.split(separator: "_")
        if components.count == 2 && components[0] == "category",
           let category = MailCategory(rawValue: String(components[1])) {
            return category
        }
        return nil
    }
}
