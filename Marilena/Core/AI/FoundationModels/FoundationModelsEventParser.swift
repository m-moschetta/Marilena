import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct FoundationModelEventCandidate: Sendable {
    public var title: String?
    public var notes: String?
    public var location: String?
    public var attendees: [String]
    public var startDate: Date?
    public var endDate: Date?
    public var isAllDay: Bool
    public var timeZoneIdentifier: String?

    public init(
        title: String? = nil,
        notes: String? = nil,
        location: String? = nil,
        attendees: [String] = [],
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        timeZoneIdentifier: String? = nil
    ) {
        self.title = title
        self.notes = notes
        self.location = location
        self.attendees = attendees
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public enum FoundationModelEventParserError: Error {
    case emptyInput
}

public final class FoundationModelsEventParser: @unchecked Sendable {
    public static let shared = FoundationModelsEventParser()

    private let isoFormatter: ISO8601DateFormatter
    private let documentationIndex: FoundationModelsDocumentationIndex

    private init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        self.isoFormatter = formatter
        self.documentationIndex = .shared
    }

    public func parseEvent(from utterance: String, referenceDate: Date = Date()) async throws -> FoundationModelEventCandidate {
        let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FoundationModelEventParserError.emptyInput
        }

        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            if let candidate = try await generateCandidate(with: trimmed, referenceDate: referenceDate) {
                return candidate
            }
        }
        #endif

        return fallbackCandidate(for: trimmed, referenceDate: referenceDate)
    }

    #if canImport(FoundationModels)
    @available(iOS 18.0, macOS 15.0, *)
    private lazy var session: LanguageModelSession = {
        LanguageModelSession(instructions: Self.baseInstructions)
    }()

    @available(iOS 18.0, macOS 15.0, *)
    private func generateCandidate(with text: String, referenceDate: Date) async throws -> FoundationModelEventCandidate? {
        let documentation = (try? await documentationIndex.summary()) ?? ""
        let prompt = makePrompt(for: text, referenceDate: referenceDate, documentation: documentation)
        let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: 400)
        let response = try await session.respond(
            to: prompt,
            generating: FoundationEventSchema.self,
            options: options
        )
        return transform(schema: response.content)
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func makePrompt(for text: String, referenceDate: Date, documentation: String) -> Prompt {
        let current = isoFormatter.string(from: referenceDate)
        return Prompt(
            """
            Estrarre e normalizzare i dettagli per un evento di calendario a partire dall'input dell'utente.
            Data e ora attuale (ISO8601): \(current)
            Fornisci il risultato usando lo schema strutturato fornito.
            Riferimenti utili dalla documentazione ufficiale Foundation Models:
            \(documentation)
            Input utente: \(text)
            """
        )
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func transform(schema: FoundationEventSchema) -> FoundationModelEventCandidate {
        let start = parse(dateString: schema.startDate)
        let end = parse(dateString: schema.endDate)
        return FoundationModelEventCandidate(
            title: schema.title?.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: schema.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            location: schema.location?.trimmingCharacters(in: .whitespacesAndNewlines),
            attendees: schema.attendees ?? [],
            startDate: start,
            endDate: end,
            isAllDay: schema.isAllDay ?? false,
            timeZoneIdentifier: schema.timeZoneIdentifier
        )
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func parse(dateString: String?) -> Date? {
        guard let value = dateString?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if let date = isoFormatter.date(from: value) {
            return date
        }

        let fallbackFormatter = DateFormatter()
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        fallbackFormatter.timeZone = TimeZone.current
        fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = fallbackFormatter.date(from: value) {
            return date
        }

        return nil
    }

    @available(iOS 18.0, macOS 15.0, *)
    private static let baseInstructions: String = {
        """
        Sei un assistente che estrae eventi di calendario da richieste in linguaggio naturale.
        Devi interpretare data, orario, durata, partecipanti, luogo e note.
        Assumi che l'utente si riferisca al futuro immediato quando i riferimenti temporali non sono completi.
        Restituisci sempre orari in formato ISO8601 con il fuso orario locale se disponibile.
        """
    }()
    #endif

    private func fallbackCandidate(for text: String, referenceDate: Date) -> FoundationModelEventCandidate {
        var title = text
        var detectedDate: Date? = nil
        var location: String? = nil

        let lower = text.lowercased()
        let calendar = Calendar.current

        let keywords: [(String, Int)] = [
            ("oggi", 0),
            ("domani", 1),
            ("dopodomani", 2)
        ]

        for (keyword, offset) in keywords {
            if lower.contains(keyword) {
                detectedDate = calendar.date(byAdding: .day, value: offset, to: referenceDate)
                title = title.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
                break
            }
        }

        if let range = lower.range(of: " a ") ?? lower.range(of: " in ") ?? lower.range(of: " presso ") {
            let rawLocation = text[range.upperBound...]
            location = rawLocation.trimmingCharacters(in: .whitespaces)
            title = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        let start: Date
        let end: Date

        if let detected = detectedDate {
            start = detected
            end = calendar.date(byAdding: .hour, value: 1, to: detected) ?? detected.addingTimeInterval(3600)
        } else {
            start = referenceDate
            end = referenceDate.addingTimeInterval(3600)
        }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = "Nuovo evento"
        }

        return FoundationModelEventCandidate(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location,
            startDate: start,
            endDate: end,
            isAllDay: false
        )
    }
}

#if canImport(FoundationModels)
@available(iOS 18.0, macOS 15.0, *)
@Generable(description: "Risultato strutturato dell'estrazione di un evento di calendario.")
private struct FoundationEventSchema: Sendable, Codable {
    @Guide(description: "Titolo conciso dell'evento")
    var title: String?

    @Guide(description: "Data e ora d'inizio in ISO8601 completo")
    var startDate: String?

    @Guide(description: "Data e ora di fine in ISO8601 completo")
    var endDate: String?

    @Guide(description: "Indica se l'evento dura tutto il giorno")
    var isAllDay: Bool?

    @Guide(description: "Luogo dell'evento se specificato")
    var location: String?

    @Guide(description: "Eventuali note fornite dall'utente")
    var notes: String?

    @Guide(description: "Lista di partecipanti indicati dall'utente")
    var attendees: [String]?

    @Guide(description: "Fuso orario associato all'evento")
    var timeZoneIdentifier: String?
}
#endif
