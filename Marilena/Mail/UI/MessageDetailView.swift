//
//  MessageDetailView.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  View per i dettagli completi del messaggio con azioni di risposta,
//  inoltro, archiviazione e eliminazione
//

import SwiftUI

/// View per i dettagli del messaggio
public struct MessageDetailView: View {
    public let message: MailMessage
    public let onReply: (ReplyType) -> Void
    public let onArchive: () -> Void
    public let onDelete: () -> Void

    @State private var showReplyOptions = false
    @State private var showMoreActions = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header del messaggio
                MessageHeaderView(message: message)

                // Corpo del messaggio
                MessageBodyView(message: message)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                // Allegati
                if !message.attachments.isEmpty {
                    AttachmentsView(attachments: message.attachments)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Menu azioni
                Menu {
                    Button {
                        onReply(.reply)
                    } label: {
                        Label("Rispondi", systemImage: "arrowshape.turn.up.left")
                    }

                    Button {
                        onReply(.replyAll)
                    } label: {
                        Label("Rispondi a tutti", systemImage: "arrowshape.turn.up.left.2")
                    }

                    Button {
                        onReply(.forward)
                    } label: {
                        Label("Inoltra", systemImage: "arrowshape.turn.up.right")
                    }

                    Divider()

                    Button {
                        // TODO: Implementare stella
                        print("Toggle stella")
                    } label: {
                        Label("Aggiungi stella", systemImage: "star")
                    }

                    Button {
                        // TODO: Implementare sposta
                        print("Sposta")
                    } label: {
                        Label("Sposta", systemImage: "folder")
                    }

                    Divider()

                    Button {
                        onArchive()
                    } label: {
                        Label("Archivia", systemImage: "archivebox")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                }
            }
        }
    }
}

/// Header del messaggio con mittente, destinatari, oggetto, data
private struct MessageHeaderView: View {
    let message: MailMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Oggetto
            Text(message.subject)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Mittente
            VStack(alignment: .leading, spacing: 4) {
                Text("Da:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    AvatarView(participant: message.from, size: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.from.displayName)
                            .font(.system(size: 16, weight: .medium))

                        Text(message.from.email)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Destinatari
            if !message.to.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    RecipientsListView(recipients: message.to)
                }
                .padding(.horizontal, 20)
            }

            // CC
            if !message.cc.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CC:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    RecipientsListView(recipients: message.cc)
                }
                .padding(.horizontal, 20)
            }

            // Data
            HStack {
                Text(message.date.formatted(date: .long, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Spacer()

                // Bandiere
                HStack(spacing: 8) {
                    if message.flags.contains(.flagged) {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.orange)
                    }

                    if !message.attachments.isEmpty {
                        Image(systemName: "paperclip")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Separatore
            Divider()
        }
        .background(Color(.secondarySystemBackground))
    }
}

/// Corpo del messaggio
private struct MessageBodyView: View {
    let message: MailMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let htmlContent = message.body.htmlText {
                // TODO: Implementare rendering HTML
                Text(htmlContent)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
            } else if let plainContent = message.body.plainText {
                Text(plainContent)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
            } else {
                Text("Contenuto non disponibile")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

/// Lista destinatari
private struct RecipientsListView: View {
    let recipients: [MailParticipant]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recipients, id: \.email) { recipient in
                    RecipientChipView(recipient: recipient)
                }
            }
        }
    }
}

/// Chip singolo destinatario
private struct RecipientChipView: View {
    let recipient: MailParticipant

    var body: some View {
        HStack(spacing: 6) {
            AvatarView(participant: recipient, size: 24)

            Text(recipient.displayName)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            if recipient.name != nil {
                Text("(\(recipient.email))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

/// Lista allegati
private struct AttachmentsView: View {
    let attachments: [MailAttachment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allegati (\(attachments.count))")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            ForEach(attachments, id: \.id) { attachment in
                AttachmentRowView(attachment: attachment)
            }
        }
    }
}

/// Riga singolo allegato
private struct AttachmentRowView: View {
    let attachment: MailAttachment

    var body: some View {
        HStack(spacing: 12) {
            // Icona allegato
            Image(systemName: iconName(for: attachment.mimeType))
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)

            // Dettagli allegato
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Text("\(attachment.size.formattedFileSize)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Pulsante download
            Button {
                // TODO: Implementare download
                print("Download: \(attachment.filename)")
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private func iconName(for mimeType: String) -> String {
        if mimeType.contains("pdf") {
            return "doc.text"
        } else if mimeType.contains("image") {
            return "photo"
        } else if mimeType.contains("video") {
            return "video"
        } else if mimeType.contains("audio") {
            return "waveform"
        } else if mimeType.contains("zip") || mimeType.contains("rar") {
            return "doc.zipper"
        } else {
            return "doc"
        }
    }
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

/// Tipo di risposta
public enum ReplyType {
    case reply
    case replyAll
    case forward
}

/// Estensioni per formattazione
extension Int {
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self))
    }
}

/// Preview per i dettagli messaggio
struct MessageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MessageDetailView(
                message: createSampleMessage(),
                onReply: { _ in print("Reply") },
                onArchive: { print("Archive") },
                onDelete: { print("Delete") }
            )
        }
        .previewLayout(.fixed(width: 400, height: 600))
    }

    static func createSampleMessage() -> MailMessage {
        return MailMessage(
            id: "msg_sample",
            threadId: "thread_sample",
            subject: "Esempio di messaggio con allegati",
            body: MailBody(
                plainText: """
                Ciao,

                Questo è un messaggio di esempio per dimostrare la visualizzazione dei dettagli.

                Include testo normale e potrebbe contenere anche HTML in futuro.

                Cordiali saluti,
                Sistema Marilena
                """,
                htmlText: nil
            ),
            from: MailParticipant(email: "marilena@example.com", name: "Sistema Marilena"),
            to: [
                MailParticipant(email: "user@example.com", name: "Utente"),
                MailParticipant(email: "admin@example.com", name: "Amministratore")
            ],
            cc: [MailParticipant(email: "support@example.com", name: "Supporto")],
            bcc: [],
            date: Date().addingTimeInterval(-3600),
            labels: ["inbox"],
            flags: MailFlags(rawValue: 0),
            attachments: [
                MailAttachment(
                    id: "att_1",
                    filename: "documento.pdf",
                    mimeType: "application/pdf",
                    size: 1024 * 200, // 200KB
                    contentId: nil,
                    isInline: false
                ),
                MailAttachment(
                    id: "att_2",
                    filename: "immagine.jpg",
                    mimeType: "image/jpeg",
                    size: 1024 * 1024, // 1MB
                    contentId: nil,
                    isInline: false
                )
            ],
            size: nil,
            providerMessageId: nil,
            inReplyTo: nil,
            references: []
        )
    }
}
