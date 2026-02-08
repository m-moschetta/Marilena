import SwiftUI
import CoreData

/// Vista per un singolo messaggio nella chat
struct ChatMessageRow: View {
    let messaggio: MessaggioMarilena
    let onSendToAI: (String) -> Void
    let onSearchWithPerplexity: (String) -> Void
    let onSendEmail: ((String, String) -> Void)? // emailId, content
    let onAddToCalendar: ((String) -> Void)?

    @State private var isEditing = false
    @State private var editedText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingCanvas = false

    // Helper per identificare se è un draft di risposta email
    private var isEmailResponseDraft: Bool {
        return messaggio.tipo == "email_response_draft"
    }

    // Helper per identificare se è un messaggio di conferma invio
    private var isEmailConfirmation: Bool {
        return messaggio.tipo == "email_confirmation"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if messaggio.isUser {
                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if isEditing {
                        editModeView
                    } else {
                        messageBubble
                    }

                    timestampView
                }
                .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
                .contextMenu {
                    Button("Modifica") {
                        startEditing()
                    }
                    Button("Apri in un canvas") {
                        editedText = messaggio.contenuto ?? ""
                        showingCanvas = true
                    }
                    Button("Copia Messaggio") {
                        UIPasteboard.general.string = messaggio.contenuto ?? ""
                    }
                    Button("Cerca online") {
                        onSearchWithPerplexity(messaggio.contenuto ?? "")
                    }
                    ShareLink(item: messaggio.contenuto ?? "") {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                }
                .sheet(isPresented: $showingCanvas) {
                    MessageEditCanvas(
                        originalText: messaggio.contenuto ?? "",
                        editedText: $editedText,
                        onSendToAI: { text in
                            onSendToAI(text)
                            showingCanvas = false
                        },
                        onSearchWithPerplexity: { text in
                        onSearchWithPerplexity(text)
                        showingCanvas = false
                    },
                    onAddToCalendar: { text in
                        onAddToCalendar?(text)
                        showingCanvas = false
                    },
                    onSave: {
                        saveEditedMessage()
                        showingCanvas = false
                    },
                    onCancel: {
                            showingCanvas = false
                        },
                        onSendEmail: isEmailResponseDraft ? { text in
                            if let emailId = messaggio.emailId {
                                onSendEmail?(emailId, text)
                                showingCanvas = false
                            }
                        } : nil
                    )
                }

            } else {
                // Avatar AI
                aiAvatar

                VStack(alignment: .leading, spacing: 6) {
                    if isEditing {
                        editModeView
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            // Badge per draft email
                            if isEmailResponseDraft {
                                emailDraftBadge
                            }

                            // Badge per conferma email
                            if isEmailConfirmation {
                                emailConfirmationBadge
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text(messaggio.contenuto ?? "")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(createMessageBackground())
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                
                                // Indicatore routing (mostrato quando si forza il gateway)
                                if UserDefaults.standard.bool(forKey: "force_gateway") {
                                    HStack(spacing: 6) {
                                        Image(systemName: "cloud.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text("via Cloudflare")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 4)
                                }
                            }
                            // Haptic Touch per email drafts
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        if isEmailResponseDraft {
                                            hapticFeedback(.medium)
                                            hapticFeedback(.heavy, delay: 0.1)
                                            editedText = messaggio.contenuto ?? ""
                                            showingCanvas = true
                                        }
                                    }
                            )
                            .onTapGesture {
                                if isEmailResponseDraft {
                                    hapticFeedback(.light)
                                }
                            }
                        }
                    }

                    timestampView
                }
                .frame(maxWidth: .infinity * 0.75, alignment: .leading)
                .contextMenu {
                    Button("Modifica") {
                        startEditing()
                    }
                    Button("Apri in un canvas") {
                        editedText = messaggio.contenuto ?? ""
                        showingCanvas = true
                    }
                    Button("Copia Messaggio") {
                        UIPasteboard.general.string = messaggio.contenuto ?? ""
                    }
                    Button("Cerca online") {
                        onSearchWithPerplexity(messaggio.contenuto ?? "")
                    }
                    ShareLink(item: messaggio.contenuto ?? "") {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                }
                .sheet(isPresented: $showingCanvas) {
                    MessageEditCanvas(
                        originalText: messaggio.contenuto ?? "",
                        editedText: $editedText,
                        onSendToAI: { text in
                            onSendToAI(text)
                            showingCanvas = false
                        },
                        onSearchWithPerplexity: { text in
                            onSearchWithPerplexity(text)
                            showingCanvas = false
                        },
                        onAddToCalendar: { text in
                            onAddToCalendar?(text)
                            showingCanvas = false
                        },
                        onSave: {
                            saveEditedMessage()
                            showingCanvas = false
                        },
                        onCancel: {
                            showingCanvas = false
                        },
                        onSendEmail: isEmailResponseDraft ? { text in
                            if let emailId = messaggio.emailId {
                                onSendEmail?(emailId, text)
                                showingCanvas = false
                            }
                        } : nil
                    )
                }

                Spacer()
            }
        }
        .id(messaggio.objectID)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)

            Text("M")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var messageBubble: some View {
        Text(messaggio.contenuto ?? "")
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private var editModeView: some View {
        VStack(spacing: 8) {
            TextField("Modifica messaggio...", text: $editedText, axis: .vertical)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .onSubmit {
                    saveEditedMessage()
                    isEditing = false
                    isTextFieldFocused = false
                }
                .onAppear {
                    isTextFieldFocused = true
                }

            // Pulsanti di azione per la modifica
            HStack(spacing: 8) {
                Button(action: {
                    onSendToAI(editedText)
                    isEditing = false
                    isTextFieldFocused = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                        Text("Invia all'AI")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: {
                    UIPasteboard.general.string = editedText
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.caption)
                        Text("Copia")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: {
                    onSearchWithPerplexity(editedText)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe.americas.fill")
                            .font(.caption)
                        Text("Cerca")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }


    @ViewBuilder
    private var emailDraftBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "envelope.arrow.triangle.branch")
                .font(.caption2)
            Text("Bozza Email")
                .font(.caption2)
                .fontWeight(.medium)

            HStack(spacing: 2) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 10))
                Text("Tieni premuto")
                    .font(.system(size: 10))
            }
            .foregroundColor(.blue.opacity(0.7))
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isEmailResponseDraft)
        )
    }

    @ViewBuilder
    private var emailConfirmationBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
            Text("Marilena Assistente")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var timestampView: some View {
        if let data = messaggio.dataCreazione {
            Text(data, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Helper Functions

    private func startEditing() {
        editedText = messaggio.contenuto ?? ""
        isEditing = true
    }

    private func saveEditedMessage() {
        guard !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        messaggio.contenuto = editedText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try messaggio.managedObjectContext?.save()
        } catch {
            print("Errore salvataggio messaggio modificato: \(error)")
        }

        isEditing = false
        isTextFieldFocused = false
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle, delay: Double = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }

    @ViewBuilder
    private func createMessageBackground() -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                isEmailResponseDraft ? Color.blue.opacity(0.05) :
                isEmailConfirmation ? Color.green.opacity(0.05) :
                Color(.systemGray6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isEmailResponseDraft ? Color.blue.opacity(0.3) :
                        isEmailConfirmation ? Color.green.opacity(0.3) :
                        Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}
