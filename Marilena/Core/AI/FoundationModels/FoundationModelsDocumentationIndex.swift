import Foundation

/// Utility che scarica e indicizza la documentazione ufficiale di Foundation Models.
public actor FoundationModelsDocumentationIndex {
    public static let shared = FoundationModelsDocumentationIndex()

    private struct Documentation: Decodable {
        let abstract: [RichText]?
        let primaryContentSections: [ContentSection]?
        let topicSections: [TopicSection]?

        struct ContentSection: Decodable {
            let kind: String?
            let content: [Content]?
        }

        struct TopicSection: Decodable {
            let title: String?
            let identifiers: [String]?
        }

        struct Content: Decodable {
            let type: String?
            let text: String?
            let level: Int?
            let inlineContent: [RichText]?
        }
    }

    private struct RichText: Decodable {
        let type: String?
        let text: String?
        let code: String?
    }

    private let documentationURL = URL(string: "https://developer.apple.com/tutorials/data/documentation/foundationmodels.json")!
    private let session: URLSession

    private var cachedSummary: String?
    private var cachedAt: Date?

    private init(session: URLSession = .shared) {
        self.session = session
    }

    /// Restituisce una versione testuale compatta della documentazione, utile per arricchire i prompt.
    public func summary(forceRefresh: Bool = false) async throws -> String {
        if let cachedSummary, let cachedAt, !forceRefresh, Date().timeIntervalSince(cachedAt) < 3600 {
            return cachedSummary
        }

        let (data, _) = try await session.data(from: documentationURL)
        let summary = try buildSummary(from: data)
        cachedSummary = summary
        cachedAt = Date()
        return summary
    }

    private func buildSummary(from data: Data) throws -> String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let document = try decoder.decode(Documentation.self, from: data)

        var segments: [String] = []

        if let abstract = document.abstract {
            let abstractText = abstract.compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " ")
            if !abstractText.isEmpty {
                segments.append("Abstract: \(abstractText)")
            }
        }

        if let sections = document.primaryContentSections {
            for section in sections where section.kind == "content" {
                for content in section.content ?? [] {
                    guard let type = content.type else { continue }
                    switch type {
                    case "heading":
                        if let text = content.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                            segments.append("## \(text)")
                        }
                    case "paragraph":
                        if let inline = content.inlineContent {
                            let paragraph = inline.compactMap { rich in
                                rich.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? rich.code
                            }.joined(separator: " ")
                            if !paragraph.isEmpty {
                                segments.append(paragraph)
                            }
                        }
                    default:
                        continue
                    }
                }
            }
        }

        if let topics = document.topicSections, !topics.isEmpty {
            let titles = topics.compactMap { $0.title?.trimmingCharacters(in: .whitespacesAndNewlines) }
            if !titles.isEmpty {
                segments.append("Topic Sections: \(titles.joined(separator: ", "))")
            }
        }

        // Limita la lunghezza per evitare prompt eccessivi.
        let joined = segments.joined(separator: "\n")
        if joined.count > 4000 {
            let index = joined.index(joined.startIndex, offsetBy: 4000)
            return String(joined[..<index])
        }

        return joined
    }
}
