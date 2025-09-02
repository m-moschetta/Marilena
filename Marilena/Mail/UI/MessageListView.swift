//
//  MessageListView.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  View per mostrare la lista dei messaggi con funzionalità di selezione
//  e azioni rapide (lettura, archiviazione, eliminazione)
//

import SwiftUI

/// View per la lista dei messaggi
public struct MessageListView: View {
    public let category: MailCategory
    public let messages: [MailMessage]
    @Binding public var selectedMessage: MailMessage?
    public let onMessageSelected: (MailMessage) -> Void
    public let onRefresh: () -> Void

    @State private var searchText = ""
    @State private var isRefreshing = false

    public var body: some View {
        VStack(spacing: 0) {
            // Barra di ricerca
            SearchBar(text: $searchText)
                .padding(.horizontal)
                .padding(.vertical, 8)

            // Lista messaggi
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredMessages, id: \.id) { message in
                        MessageRow(
                            message: message,
                            isSelected: selectedMessage?.id == message.id,
                            onTap: {
                                selectedMessage = message
                                onMessageSelected(message)
                            },
                            onSwipeAction: { action in
                                handleSwipeAction(action, for: message)
                            }
                        )
                        .id(message.id)
                    }
                }
            }
            .refreshable {
                isRefreshing = true
                onRefresh()
                // Simula caricamento
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isRefreshing = false
                }
            }
            .overlay {
                if filteredMessages.isEmpty {
                    EmptyMessageListView(
                        category: category,
                        searchText: searchText
                    )
                }
            }
        }
    }

    private var filteredMessages: [MailMessage] {
        if searchText.isEmpty {
            return messages
        } else {
            return messages.filter { message in
                message.subject.localizedCaseInsensitiveContains(searchText) ||
                message.from.displayName.localizedCaseInsensitiveContains(searchText) ||
                message.body.displayText?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }

    private func handleSwipeAction(_ action: MessageSwipeAction, for message: MailMessage) {
        switch action {
        case .archive:
            // TODO: Implementare archiviazione
            print("Archivia: \(message.id)")
        case .delete:
            // TODO: Implementare eliminazione
            print("Elimina: \(message.id)")
        case .markAsRead:
            // TODO: Implementare marca come letto
            print("Marca come letto: \(message.id)")
        case .markAsUnread:
            // TODO: Implementare marca come non letto
            print("Marca come non letto: \(message.id)")
        }
    }
}

/// Riga singola messaggio
private struct MessageRow: View {
    let message: MailMessage
    let isSelected: Bool
    let onTap: () -> Void
    let onSwipeAction: (MessageSwipeAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Avatar mittente
                AvatarView(participant: message.from, size: 40)

                // Contenuto messaggio
                VStack(alignment: .leading, spacing: 4) {
                    // Mittente e data
                    HStack {
                        Text(message.from.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)

                        Spacer()

                        Text(message.date.relativeTimeString)
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }

                    // Oggetto
                    Text(message.subject)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Anteprima corpo
                    if let preview = message.body.displayText?.prefix(100) {
                        Text(String(preview) + (preview.count >= 100 ? "..." : ""))
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                            .lineLimit(2)
                    }

                    // Allegati e bandiere
                    HStack(spacing: 8) {
                        if !message.attachments.isEmpty {
                            Image(systemName: "paperclip")
                                .font(.system(size: 12))
                                .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary)
                        }

                        if message.flags.contains(.flagged) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }

                        Spacer()

                        // Stelletta
                        Button {
                            // TODO: Implementare toggle stella
                        } label: {
                            Image(systemName: message.flags.contains(.flagged) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(message.flags.contains(.flagged) ? .orange : .secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            )
            .contentShape(Rectangle())

            // Separatore
            if !isSelected {
                Divider()
                    .padding(.leading, 68) // Allinea con l'avatar
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onSwipeAction(.archive)
            } label: {
                Label("Archivia", systemImage: "archivebox")
            }
            .tint(.blue)

            Button(role: .destructive) {
                onSwipeAction(.delete)
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if message.flags.isRead {
                Button {
                    onSwipeAction(.markAsUnread)
                } label: {
                    Label("Non letto", systemImage: "envelope.badge")
                }
                .tint(.gray)
            } else {
                Button {
                    onSwipeAction(.markAsRead)
                } label: {
                    Label("Letto", systemImage: "envelope.open")
                }
                .tint(.green)
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

/// Azioni di swipe sui messaggi
private enum MessageSwipeAction {
    case archive
    case delete
    case markAsRead
    case markAsUnread
}

/// Avatar circolare per il mittente
private struct AvatarView: View {
    let participant: MailParticipant
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)

            Text(participant.displayName.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

/// Barra di ricerca
private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Cerca messaggi", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

/// View per lista messaggi vuota
private struct EmptyMessageListView: View {
    let category: MailCategory
    let searchText: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(emptyTitle)
                .font(.title2)
                .foregroundColor(.primary)

            Text(emptyMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyIcon: String {
        searchText.isEmpty ? "tray" : "magnifyingglass"
    }

    private var emptyTitle: String {
        searchText.isEmpty ? "Nessun messaggio" : "Nessun risultato"
    }

    private var emptyMessage: String {
        if searchText.isEmpty {
            switch category {
            case .inbox:
                return "La tua casella di posta è vuota. I nuovi messaggi appariranno qui."
            case .important:
                return "Nessun messaggio importante al momento."
            default:
                return "Nessun messaggio in questa categoria."
            }
        } else {
            return "Nessun messaggio trovato per \"\(searchText)\""
        }
    }
}

/// Estensioni per date relative
extension Date {
    var relativeTimeString: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.second, .minute, .hour, .day, .weekOfYear], from: self, to: now)

        if let weeks = components.weekOfYear, weeks > 0 {
            return "\(weeks)w"
        } else if let days = components.day, days > 0 {
            return days == 1 ? "ieri" : "\(days)g"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "ora"
        }
    }
}

/// Preview per la lista messaggi
struct MessageListView_Previews: PreviewProvider {
    static var previews: some View {
        MessageListView(
            category: .inbox,
            messages: createSampleMessages(),
            selectedMessage: .constant(nil),
            onMessageSelected: { _ in },
            onRefresh: {}
        )
        .previewLayout(.fixed(width: 400, height: 600))
    }

    static func createSampleMessages() -> [MailMessage] {
        return (0..<5).map { index in
            MailMessage(
                id: "msg_\(index)",
                threadId: "thread_\(index)",
                subject: "Messaggio di esempio #\(index + 1)",
                body: MailBody(plainText: "Questo è il contenuto del messaggio numero \(index + 1). È un messaggio di esempio per la preview."),
                from: MailParticipant(email: "sender\(index)@example.com", name: "Mittente \(index + 1)"),
                to: [MailParticipant(email: "user@example.com", name: "Tu")],
                cc: [],
                bcc: [],
                date: Date().addingTimeInterval(-Double(index) * 3600),
                labels: ["inbox"],
                flags: index % 2 == 0 ? MailFlags(rawValue: MailFlags.seen.rawValue) : MailFlags(rawValue: 0),
                attachments: index % 3 == 0 ? [
                    MailAttachment(
                        id: "att_\(index)",
                        filename: "document.pdf",
                        mimeType: "application/pdf",
                        size: 1024 * 100,
                        contentId: nil,
                        isInline: false
                    )
                ] : [],
                size: nil,
                providerMessageId: nil,
                inReplyTo: nil,
                references: []
            )
        }
    }
}
