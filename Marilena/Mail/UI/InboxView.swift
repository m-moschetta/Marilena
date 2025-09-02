//
//  InboxView.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  View principale dell'inbox che utilizza il nuovo sistema mail modulare
//  Mostra categorie, messaggi e permette la navigazione completa
//

import SwiftUI
import Combine

/// View principale dell'inbox
public struct InboxView: View {
    @StateObject private var viewModel: InboxViewModel
    @State private var selectedCategory: MailCategory?
    @State private var selectedMessage: MailMessage?
    @State private var showMessageDetail = false

    public init(domainService: MailDomainService) {
        _viewModel = StateObject(wrappedValue: InboxViewModel(domainService: domainService))
    }

    public var body: some View {
        NavigationSplitView {
            // Sidebar con categorie
            CategoryNavigationView(
                categories: viewModel.categories,
                selectedCategory: $selectedCategory,
                unreadCounts: viewModel.unreadCounts
            )
        } content: {
            // Lista messaggi
            if let category = selectedCategory {
                MessageListView(
                    category: category,
                    messages: viewModel.messages(for: category),
                    selectedMessage: $selectedMessage,
                    onMessageSelected: { message in
                        selectedMessage = message
                        showMessageDetail = true
                    },
                    onRefresh: {
                        Task {
                            await viewModel.refreshCategory(category)
                        }
                    }
                )
                .navigationTitle(category.displayName)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                // Placeholder quando nessuna categoria selezionata
                VStack(spacing: 20) {
                    Image(systemName: "mail.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Seleziona una categoria")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Scegli una categoria dalla sidebar per vedere i tuoi messaggi")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } detail: {
            // Dettagli messaggio
            if let message = selectedMessage {
                MessageDetailView(
                    message: message,
                    onReply: { replyType in
                        // TODO: Implementare risposta
                        print("Reply with type: \(replyType)")
                    },
                    onArchive: {
                        Task {
                            await viewModel.archiveMessage(message)
                        }
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteMessage(message)
                        }
                    }
                )
            } else {
                // Placeholder dettagli
                VStack(spacing: 20) {
                    Image(systemName: "mail")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Seleziona un messaggio")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Scegli un messaggio dalla lista per vedere i dettagli")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
            }
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text("Errore"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

/// ViewModel per InboxView
public final class InboxViewModel: ObservableObject {
    @Published public var categories: [MailCategory] = []
    @Published public var unreadCounts: [MailCategory: Int] = [:]
    @Published public var error: InboxError?

    private let domainService: MailDomainService
    private var cancellables = Set<AnyCancellable>()
    private var categoryMessages: [MailCategory: [MailMessage]] = [:]

    public init(domainService: MailDomainService) {
        self.domainService = domainService
        setupBindings()
    }

    private func setupBindings() {
        domainService.$unreadCount
            .sink { [weak self] count in
                // Aggiorna conteggi non letti per categorie
                self?.updateUnreadCounts()
            }
            .store(in: &cancellables)
    }

    public func loadInitialData() async {
        do {
            // Carica categorie predefinite
            categories = MailCategory.allCases

            // Simula caricamento iniziale (in produzione verrebbe dal domain service)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 secondi

            // Carica messaggi per categoria predefinita
            if let inbox = categories.first(where: { $0 == .inbox }) {
                selectedCategory = inbox
                await loadMessages(for: inbox)
            }

        } catch {
            self.error = InboxError(message: "Errore nel caricamento iniziale: \(error.localizedDescription)")
        }
    }

    public func messages(for category: MailCategory) -> [MailMessage] {
        return categoryMessages[category] ?? []
    }

    public func refreshCategory(_ category: MailCategory) async {
        await loadMessages(for: category)
    }

    public func archiveMessage(_ message: MailMessage) async {
        // TODO: Implementare archiviazione
        print("Archivia messaggio: \(message.id)")
    }

    public func deleteMessage(_ message: MailMessage) async {
        // TODO: Implementare eliminazione
        print("Elimina messaggio: \(message.id)")
    }

    private func loadMessages(for category: MailCategory) async {
        do {
            // Placeholder: in produzione chiamerebbe il domain service
            // Per ora crea messaggi di esempio
            let messages = createSampleMessages(for: category)
            categoryMessages[category] = messages

            // Aggiorna conteggi
            updateUnreadCounts()

        } catch {
            self.error = InboxError(message: "Errore nel caricamento messaggi: \(error.localizedDescription)")
        }
    }

    private func updateUnreadCounts() {
        for category in categories {
            let messages = categoryMessages[category] ?? []
            unreadCounts[category] = messages.filter { !$0.flags.isRead }.count
        }
    }

    private func createSampleMessages(for category: MailCategory) -> [MailMessage] {
        let sampleSenders = [
            ("GitHub", "noreply@github.com"),
            ("Apple", "news@apple.com"),
            ("Amazon", "orders@amazon.com"),
            ("LinkedIn", "notifications@linkedin.com"),
            ("Spotify", "music@spotify.com"),
            ("Netflix", "info@netflix.com")
        ]

        return (0..<20).map { index in
            let sender = sampleSenders[index % sampleSenders.count]
            let subject = generateSampleSubject(for: category, index: index)
            let isRead = Bool.random()

            return MailMessage(
                id: "msg_\(category.rawValue)_\(index)",
                threadId: "thread_\(index)",
                subject: subject,
                body: MailBody(plainText: "Contenuto del messaggio di esempio numero \(index + 1) per la categoria \(category.displayName)"),
                from: MailParticipant(email: sender.1, name: sender.0),
                to: [MailParticipant(email: "user@example.com", name: "Tu")],
                cc: [],
                bcc: [],
                date: Date().addingTimeInterval(-Double(index) * 3600), // Ogni ora indietro
                labels: [category.rawValue],
                flags: MailFlags(rawValue: isRead ? MailFlags.seen.rawValue : 0),
                attachments: index % 5 == 0 ? [createSampleAttachment()] : [],
                size: nil,
                providerMessageId: nil,
                inReplyTo: nil,
                references: []
            )
        }
    }

    private func generateSampleSubject(for category: MailCategory, index: Int) -> String {
        switch category {
        case .inbox:
            let subjects = [
                "Aggiornamento importante del progetto",
                "Conferma del tuo ordine",
                "Nuovo messaggio da un collega",
                "Promemoria riunione",
                "Conferma registrazione evento"
            ]
            return subjects[index % subjects.count]

        case .important:
            let subjects = [
                "URGENTE: Revisione codice richiesta",
                "Meeting con il cliente alle 14:00",
                "Approvazione budget richiesta",
                "Problema di sicurezza rilevato"
            ]
            return subjects[index % subjects.count]

        case .work:
            let subjects = [
                "Report settimanale vendite",
                "Aggiornamento progetto mobile",
                "Revisione documentazione API",
                "Meeting team sviluppo"
            ]
            return subjects[index % subjects.count]

        case .marketing:
            let subjects = [
                "Nuove funzionalità disponibili",
                "Offerta speciale per sviluppatori",
                "Tutorial: Come ottimizzare le performance",
                "Newsletter settimanale"
            ]
            return subjects[index % subjects.count]

        default:
            return "Messaggio di esempio #\(index + 1)"
        }
    }

    private func createSampleAttachment() -> MailAttachment {
        return MailAttachment(
            id: "att_\(UUID().uuidString)",
            filename: "document.pdf",
            mimeType: "application/pdf",
            size: 1024 * 500, // 500KB
            contentId: nil,
            isInline: false
        )
    }
}

/// Errore dell'Inbox
public struct InboxError: Identifiable {
    public let id = UUID()
    public let message: String
}

/// Estensioni per categorie
extension MailCategory {
    public var displayName: String {
        switch self {
        case .inbox: return "Posta in arrivo"
        case .important: return "Importante"
        case .personal: return "Personale"
        case .work: return "Lavoro"
        case .marketing: return "Marketing"
        case .notifications: return "Notifiche"
        case .bills: return "Fatture"
        case .social: return "Social"
        case .travel: return "Viaggi"
        case .finance: return "Finanza"
        }
    }

    public var iconName: String {
        switch self {
        case .inbox: return "tray"
        case .important: return "exclamationmark.triangle"
        case .personal: return "person"
        case .work: return "briefcase"
        case .marketing: return "megaphone"
        case .notifications: return "bell"
        case .bills: return "doc.text"
        case .social: return "person.2"
        case .travel: return "airplane"
        case .finance: return "banknote"
        }
    }

    public var color: Color {
        switch self {
        case .inbox: return .blue
        case .important: return .orange
        case .personal: return .green
        case .work: return .purple
        case .marketing: return .pink
        case .notifications: return .yellow
        case .bills: return .red
        case .social: return .cyan
        case .travel: return .mint
        case .finance: return .indigo
        }
    }
}
