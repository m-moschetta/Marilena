//
//  MailSignalsProcessor.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Processore di segnali per classificazione euristica e ML
//  Analizza pattern e comportamenti per suggerire categorie
//

import Foundation

/// Processore di segnali per classificazione intelligente
public final class MailSignalsProcessor {

    // MARK: - Properties

    private let queue = DispatchQueue(label: "com.marilena.mail.signals", qos: .background)
    private var signalPatterns: [String: MailSignalPattern] = [:]

    // MARK: - Initialization

    public init() {
        setupDefaultPatterns()
    }

    // MARK: - Public Methods

    /// Processa i segnali per un messaggio
    public func processSignals(for message: MailMessage) async -> [MailCategory: Double] {
        return await withCheckedContinuation { continuation in
            queue.async {
                var scores: [MailCategory: Double] = [:]

                // Analizza pattern del mittente
                if let senderCategory = self.analyzeSenderPattern(message.from.email) {
                    scores[senderCategory, default: 0] += 0.3
                }

                // Analizza pattern dell'oggetto
                if let subjectCategory = self.analyzeSubjectPattern(message.subject) {
                    scores[subjectCategory, default: 0] += 0.4
                }

                // Analizza ora di invio
                if let timeCategory = self.analyzeTimePattern(message.date) {
                    scores[timeCategory, default: 0] += 0.2
                }

                // Analizza dimensione e allegati
                if let sizeCategory = self.analyzeSizePattern(message) {
                    scores[sizeCategory, default: 0] += 0.1
                }

                // Normalizza i punteggi
                let normalizedScores = self.normalizeScores(scores)

                continuation.resume(returning: normalizedScores)
            }
        }
    }

    /// Aggiorna i pattern basati sul feedback dell'utente
    public func updatePattern(from message: MailMessage, with category: MailCategory, confidence: Double) {
        queue.async {
            let sender = message.from.email
            let subject = message.subject

            // Aggiorna pattern del mittente
            self.updateSenderPattern(sender, category: category, confidence: confidence)

            // Aggiorna pattern dell'oggetto
            self.updateSubjectPattern(subject, category: category, confidence: confidence)
        }
    }

    // MARK: - Private Methods

    private func setupDefaultPatterns() {
        // Pattern per email di lavoro
        signalPatterns["work-hours"] = MailSignalPattern(
            category: .work,
            senderDomains: ["company.com", "office.com", "business.org"],
            subjectKeywords: ["meeting", "project", "deadline", "report", "agenda"],
            timeRanges: [TimeRange(start: "09:00", end: "17:00")],
            weight: 0.8
        )

        // Pattern per email personali
        signalPatterns["personal"] = MailSignalPattern(
            category: .personal,
            senderDomains: ["gmail.com", "yahoo.com", "hotmail.com"],
            subjectKeywords: ["hello", "how are you", "family", "friends"],
            timeRanges: [TimeRange(start: "18:00", end: "23:00")],
            weight: 0.6
        )

        // Pattern per marketing
        signalPatterns["marketing"] = MailSignalPattern(
            category: .marketing,
            senderDomains: ["newsletter", "promo", "marketing"],
            subjectKeywords: ["offer", "discount", "sale", "special", "promotion"],
            timeRanges: [],
            weight: 0.7
        )

        // Pattern per notifiche
        signalPatterns["notifications"] = MailSignalPattern(
            category: .notifications,
            senderDomains: ["noreply", "notification", "alert"],
            subjectKeywords: ["update", "notification", "alert", "status", "confirmation"],
            timeRanges: [],
            weight: 0.9
        )

        // Pattern per fatture
        signalPatterns["bills"] = MailSignalPattern(
            category: .bills,
            senderDomains: ["billing", "invoice", "payment"],
            subjectKeywords: ["invoice", "bill", "payment", "receipt", "fattura"],
            timeRanges: [],
            weight: 0.85
        )
    }

    private func analyzeSenderPattern(_ email: String) -> MailCategory? {
        let domain = extractDomain(from: email)

        for pattern in signalPatterns.values {
            if pattern.senderDomains.contains(where: { domain.contains($0) }) {
                return pattern.category
            }
        }

        return nil
    }

    private func analyzeSubjectPattern(_ subject: String) -> MailCategory? {
        let lowerSubject = subject.lowercased()

        for pattern in signalPatterns.values {
            for keyword in pattern.subjectKeywords {
                if lowerSubject.contains(keyword) {
                    return pattern.category
                }
            }
        }

        return nil
    }

    private func analyzeTimePattern(_ date: Date) -> MailCategory? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Lavoro: 9-17
        if hour >= 9 && hour <= 17 {
            return .work
        }

        // Personale: sera/notte
        if hour >= 18 || hour <= 6 {
            return .personal
        }

        return nil
    }

    private func analyzeSizePattern(_ message: MailMessage) -> MailCategory? {
        let size = message.size ?? 0

        // Email grandi spesso sono marketing o allegati di lavoro
        if size > 100000 { // > 100KB
            if message.attachments?.isEmpty == false {
                return .work
            } else {
                return .marketing
            }
        }

        // Email piccole spesso sono notifiche
        if size < 1000 { // < 1KB
            return .notifications
        }

        return nil
    }

    private func updateSenderPattern(_ sender: String, category: MailCategory, confidence: Double) {
        let domain = extractDomain(from: sender)

        // Trova o crea pattern per questa categoria
        let patternKey = "\(category.rawValue)-sender"
        var pattern = signalPatterns[patternKey] ?? MailSignalPattern(
            category: category,
            senderDomains: [],
            subjectKeywords: [],
            timeRanges: [],
            weight: 0.5
        )

        // Aggiungi dominio se non presente
        if !pattern.senderDomains.contains(domain) {
            pattern.senderDomains.append(domain)
            pattern.weight = min(1.0, pattern.weight + confidence * 0.1)
        }

        signalPatterns[patternKey] = pattern
    }

    private func updateSubjectPattern(_ subject: String, category: MailCategory, confidence: Double) {
        let words = extractKeywords(from: subject)

        let patternKey = "\(category.rawValue)-subject"
        var pattern = signalPatterns[patternKey] ?? MailSignalPattern(
            category: category,
            senderDomains: [],
            subjectKeywords: [],
            timeRanges: [],
            weight: 0.5
        )

        // Aggiungi parole chiave nuove
        for word in words {
            if !pattern.subjectKeywords.contains(word) && word.count > 3 {
                pattern.subjectKeywords.append(word)
                pattern.weight = min(1.0, pattern.weight + confidence * 0.05)
            }
        }

        signalPatterns[patternKey] = pattern
    }

    private func normalizeScores(_ scores: [MailCategory: Double]) -> [MailCategory: Double] {
        let total = scores.values.reduce(0, +)
        guard total > 0 else { return [:] }

        return scores.mapValues { $0 / total }
    }

    private func extractDomain(from email: String) -> String {
        let components = email.split(separator: "@")
        return components.count > 1 ? String(components[1]) : ""
    }

    private func extractKeywords(from subject: String) -> [String] {
        let words = subject
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }

        return Array(Set(words)) // Rimuovi duplicati
    }
}

// MARK: - Supporting Types

/// Pattern di segnale per classificazione
private struct MailSignalPattern {
    var category: MailCategory
    var senderDomains: [String]
    var subjectKeywords: [String]
    var timeRanges: [TimeRange]
    var weight: Double
}

/// Range temporale
private struct TimeRange {
    let start: String
    let end: String
}
