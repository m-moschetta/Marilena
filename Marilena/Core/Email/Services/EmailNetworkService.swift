import Foundation

/// Servizio dedicato alle chiamate di rete per le email
public final class EmailNetworkService {

    // MARK: - Private Properties
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 2.0

    // MARK: - Public Methods

    /// Fetch emails da Gmail API
    public func fetchEmailsFromGmail(accessToken: String, maxResults: Int = 20) async throws -> [EmailMessage] {
        await waitForRateLimit()

        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=\(maxResults)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.networkError("Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw EmailError.networkError("Gmail API error: \(httpResponse.statusCode)")
        }

        let gmailResponse = try JSONDecoder().decode(GmailMessageList.self, from: data)

        var messages: [EmailMessage] = []
        guard let gmailMessages = gmailResponse.messages else {
            return messages
        }

        for message in gmailMessages.prefix(maxResults) {
            if let email = await fetchGmailMessageDetails(messageId: message.id, accessToken: accessToken) {
                messages.append(email)
            }
        }

        return messages
    }

    /// Fetch emails da Microsoft Graph
    public func fetchEmailsFromMicrosoft(accessToken: String, maxResults: Int = 20) async throws -> [EmailMessage] {
        await waitForRateLimit()

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages?$top=\(maxResults)&$orderby=receivedDateTime desc")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.networkError("Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw EmailError.networkError("Microsoft Graph error: \(httpResponse.statusCode)")
        }

        let graphResponse = try JSONDecoder().decode(MicrosoftGraphResponse.self, from: data)
        let messages = graphResponse.value.map { graphMessage in
            EmailMessage(
                id: graphMessage.id,
                from: graphMessage.from?.emailAddress?.address ?? "Unknown",
                to: graphMessage.toRecipients?.map { $0.emailAddress?.address ?? "" } ?? [],
                subject: graphMessage.subject ?? "No Subject",
                body: graphMessage.body?.content ?? "",
                date: parseMicrosoftGraphDate(graphMessage.receivedDateTime),
                isRead: graphMessage.isRead ?? false,
                hasAttachments: graphMessage.hasAttachments ?? false
            )
        }

        return messages
    }

    /// Invia email tramite Gmail API
    public func sendEmailViaGmail(to: String, subject: String, body: String, account: EmailAccount) async throws {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let message = createRFC2822Message(to: to, subject: subject, body: body, from: account.email)
        let encodedMessage = message.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let emailData: [String: Any] = ["raw": encodedMessage ?? ""]
        let jsonData = try JSONSerialization.data(withJSONObject: emailData)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.sendFailed
        }

        guard httpResponse.statusCode == 200 else {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Gmail API error: \(errorResponse)")
            throw EmailError.sendFailed
        }
    }

    /// Invia email tramite Microsoft Graph
    public func sendEmailViaMicrosoft(to: String, subject: String, body: String, account: EmailAccount) async throws {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/sendMail")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let emailData: [String: Any] = [
            "message": [
                "subject": subject,
                "body": [
                    "contentType": "HTML",
                    "content": body
                ],
                "toRecipients": [
                    ["emailAddress": ["address": to]]
                ]
            ],
            "saveToSentItems": true
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: emailData)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.sendFailed
        }

        guard httpResponse.statusCode == 202 else {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Microsoft Graph error: \(errorResponse)")
            throw EmailError.sendFailed
        }
    }

    /// Marca email come letta su Gmail
    public func markAsReadGmail(emailId: String, account: EmailAccount) async throws {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(emailId)/modify")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["removeLabelIds": ["UNREAD"]]
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EmailError.serverError
        }
    }

    /// Marca email come letta su Microsoft
    public func markAsReadMicrosoft(emailId: String, account: EmailAccount) async throws {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages/\(emailId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["isRead": true]
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EmailError.serverError
        }
    }

    /// Elimina email da Gmail
    public func deleteFromGmail(emailId: String, account: EmailAccount) async throws {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(emailId)/trash")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EmailError.deleteFailed
        }
    }

    /// Elimina email da Microsoft
    public func deleteFromMicrosoft(emailId: String, account: EmailAccount) async throws {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages/\(emailId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw EmailError.deleteFailed
        }
    }

    // MARK: - Private Methods

    private func waitForRateLimit() async {
        guard let lastRequest = lastRequestTime else {
            lastRequestTime = Date()
            return
        }

        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        if timeSinceLastRequest < minimumRequestInterval {
            let waitTime = minimumRequestInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }

        lastRequestTime = Date()
    }

    private func fetchGmailMessageDetails(messageId: String, accessToken: String) async -> EmailMessage? {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let gmailMessage = try JSONDecoder().decode(GmailMessage.self, from: data)

            let from = gmailMessage.payload?.headers?.first { $0.name.lowercased() == "from" }?.value ?? "Unknown"
            let subject = gmailMessage.payload?.headers?.first { $0.name.lowercased() == "subject" }?.value ?? "No Subject"
            let dateString = gmailMessage.payload?.headers?.first { $0.name.lowercased() == "date" }?.value

            let body = decodeGmailBody(gmailMessage.payload)

            return EmailMessage(
                id: gmailMessage.id,
                from: from,
                to: [],
                subject: subject,
                body: body,
                date: parseGmailDate(dateString),
                isRead: !gmailMessage.labelIds.contains("UNREAD"),
                hasAttachments: gmailMessage.payload?.parts?.contains { $0.filename?.isEmpty == false } ?? false
            )

        } catch {
            return nil
        }
    }

    private func decodeGmailBody(_ payload: GmailMessagePayload?) -> String {
        func decodeB64(_ s: String) -> String? {
            let normalized = s
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let padding = (4 - normalized.count % 4) % 4
            let padded = normalized + String(repeating: "=", count: padding)
            guard let data = Data(base64Encoded: padded) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        func extract(from node: GmailMessagePayload?) -> (html: String?, text: String?) {
            guard let node = node else { return (nil, nil) }
            var html: String? = nil
            var text: String? = nil

            if let data = node.body?.data, !data.isEmpty {
                if node.mimeType?.lowercased().contains("text/html") == true {
                    html = decodeB64(data)
                } else if node.mimeType?.lowercased().contains("text/plain") == true {
                    text = decodeB64(data)
                }
            }

            if let parts = node.parts {
                for part in parts {
                    let child = extract(from: part)
                    if html == nil { html = child.html }
                    if text == nil { text = child.text }
                }
            }

            return (html, text)
        }

        let result = extract(from: payload)
        return result.html ?? result.text ?? ""
    }

    private func parseGmailDate(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        return formatter.date(from: dateString) ?? Date()
    }

    private func parseMicrosoftGraphDate(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString) ?? Date()
    }

    private func createRFC2822Message(to: String, subject: String, body: String, from: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")

        let date = dateFormatter.string(from: Date())

        return """
        From: \(from)
        To: \(to)
        Subject: \(subject)
        Date: \(date)
        MIME-Version: 1.0
        Content-Type: text/html; charset=UTF-8

        \(body)
        """
    }
}

// Note: Gmail and Microsoft Graph types are defined in SharedTypes.swift
