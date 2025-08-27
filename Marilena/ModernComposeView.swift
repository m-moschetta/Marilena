import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

// MARK: - Modern Compose View with AI Assistant
/// Vista di composizione email moderna con assistente AI integrato

struct ModernComposeView: View {
    let replyTo: EmailMessage?
    let initialTo: String
    let initialSubject: String
    let initialBody: String
    
    @StateObject private var emailService = EmailService()
    @StateObject private var aiService = EmailAIService()
    @Environment(\.dismiss) private var dismiss
    
    // Email composition states
    @State private var to: String
    @State private var cc: String = ""
    @State private var bcc: String = ""
    @State private var subject: String
    @State private var emailBody: String
    @State private var showingCCBCC = false
    
    // AI states
    @State private var showingAIAssistant = true
    @State private var isSmartComposeEnabled = true
    
    // UI states
    @State private var isSending = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingAttachments = false
    @State private var attachments: [ComposeEmailAttachment] = []
    
    // Keyboard and focus
    @FocusState private var focusedField: Field?
    
    enum Field {
        case to, cc, bcc, subject, body
    }
    
    // Initializers
    init(replyTo: EmailMessage? = nil, 
         initialTo: String = "", 
         initialSubject: String = "", 
         initialBody: String = "") {
        self.replyTo = replyTo
        self.initialTo = initialTo
        self.initialSubject = initialSubject
        self.initialBody = initialBody
        
        _to = State(initialValue: initialTo)
        _subject = State(initialValue: initialSubject)
        _emailBody = State(initialValue: initialBody)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Email Form
                ScrollView {
                    VStack(spacing: 0) {
                        emailFormSection
                        
                        // MARK: - AI Assistant
                        if showingAIAssistant {
                            ModernAIComposeAssistant(
                                emailBody: $emailBody,
                                subject: $subject,
                                aiService: aiService,
                                recipientEmail: to,
                                isReply: replyTo != nil,
                                originalEmail: replyTo
                            )
                        }
                        
                        // MARK: - Smart Suggestions
                        if isSmartComposeEnabled {
                            smartSuggestionsSection
                        }
                        
                        // MARK: - Attachments
                        if !attachments.isEmpty {
                            attachmentsSection
                        }
                        
                        // Bottom spacing
                        Color.clear.frame(height: 100)
                    }
                }
                
                // MARK: - Bottom Toolbar
                bottomToolbar
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Nuova Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Invia") {
                        Task {
                            await sendEmail()
                        }
                    }
                    .disabled(!canSendEmail || isSending)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
        .alert("Errore Invio", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Email Form Section
    private var emailFormSection: some View {
        VStack(spacing: 0) {
            // To field
            emailFieldRow(
                title: "A:",
                text: $to,
                placeholder: "Destinatario",
                focused: $focusedField,
                field: .to
            )
            
            // CC/BCC toggle
            if !showingCCBCC {
                HStack {
                    Button("Aggiungi CC/BCC") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingCCBCC = true
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            // CC/BCC fields
            if showingCCBCC {
                emailFieldRow(
                    title: "CC:",
                    text: $cc,
                    placeholder: "Copia Carbone",
                    focused: $focusedField,
                    field: .cc
                )
                
                emailFieldRow(
                    title: "BCC:",
                    text: $bcc,
                    placeholder: "Copia Carbone Nascosta",
                    focused: $focusedField,
                    field: .bcc
                )
            }
            
            // Subject field
            emailFieldRow(
                title: "Oggetto:",
                text: $subject,
                placeholder: "Oggetto email",
                focused: $focusedField,
                field: .subject
            )
            
            Divider()
                .padding(.horizontal, 16)
            
            // Body field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Messaggio:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    // AI toggle
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                            .font(.system(size: 12))
                            .foregroundStyle(showingAIAssistant ? .blue : .gray)
                        
                        Toggle("", isOn: $showingAIAssistant)
                            .labelsHidden()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                TextEditor(text: $emailBody)
                    .font(.body)
                    .focused($focusedField, equals: .body)
                    .frame(minHeight: 200)
                    .padding(.horizontal, 16)
                    .onChange(of: emailBody) { oldValue, newValue in
                        if isSmartComposeEnabled && newValue.count > oldValue.count {
                            // Trigger smart suggestions
                            triggerSmartSuggestions()
                        }
                    }
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private func emailFieldRow(
        title: String,
        text: Binding<String>,
        placeholder: String,
        focused: FocusState<Field?>.Binding,
        field: Field
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 80, alignment: .leading)
                
                TextField(placeholder, text: text)
                    .font(.body)
                    .focused(focused, equals: field)
                    .textFieldStyle(.plain)
                    .submitLabel(.next)
                    .onSubmit {
                        moveToNextField()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Smart Suggestions Section
    private var smartSuggestionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Suggerimenti Intelligenti")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                
                Toggle("", isOn: $isSmartComposeEnabled)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            if isSmartComposeEnabled {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    smartSuggestionCard(
                        title: "Saluto",
                        suggestion: getSalutoSuggestion(),
                        icon: "hand.wave.fill",
                        color: .blue
                    )
                    
                    smartSuggestionCard(
                        title: "Chiusura",
                        suggestion: getChiusuraSuggestion(),
                        icon: "checkmark.seal.fill",
                        color: .green
                    )
                    
                    smartSuggestionCard(
                        title: "Cortesia",
                        suggestion: "Grazie per il tempo dedicato",
                        icon: "heart.fill",
                        color: .pink
                    )
                    
                    smartSuggestionCard(
                        title: "Follow-up",
                        suggestion: "Resto in attesa di un vostro riscontro",
                        icon: "clock.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .animation(.easeInOut(duration: 0.3), value: isSmartComposeEnabled)
    }
    
    private func smartSuggestionCard(title: String, suggestion: String, icon: String, color: Color) -> some View {
        Button {
            if emailBody.isEmpty {
                emailBody = suggestion
            } else {
                emailBody += "\n\n" + suggestion
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(suggestion)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Attachments Section
    private var attachmentsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundStyle(.blue)
                Text("Allegati (\(attachments.count))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            ForEach(attachments, id: \.id) { attachment in
                attachmentRow(attachment)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private func attachmentRow(_ attachment: ComposeEmailAttachment) -> some View {
        HStack {
            Image(systemName: attachment.iconName)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(attachment.sizeDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                removeAttachment(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            Button {
                showingAttachments = true
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }
            
            Button {
                // Format text
            } label: {
                Image(systemName: "textformat")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }
            
            Button {
                // Insert link
            } label: {
                Image(systemName: "link")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            if isSending {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Invio in corso...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Computed Properties
    
    private var canSendEmail: Bool {
        !to.isEmpty && !subject.isEmpty && !emailBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialState() {
        if let replyTo = replyTo {
            to = replyTo.from
            if !subject.hasPrefix("Re:") {
                subject = "Re: \(replyTo.subject)"
            }
            
            if emailBody.isEmpty {
                emailBody = "\n\n---\nIl \(formatDate(replyTo.date)) \(replyTo.from) ha scritto:\n> \(replyTo.body.prefix(200))..."
            }
        }
        
        // Focus on appropriate field
        if to.isEmpty {
            focusedField = .to
        } else if subject.isEmpty {
            focusedField = .subject
        } else {
            focusedField = .body
        }
    }
    
    private func moveToNextField() {
        switch focusedField {
        case .to:
            focusedField = showingCCBCC ? .cc : .subject
        case .cc:
            focusedField = .bcc
        case .bcc:
            focusedField = .subject
        case .subject:
            focusedField = .body
        case .body:
            focusedField = nil
        case .none:
            break
        }
    }
    
    private func getSalutoSuggestion() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Buongiorno"
        case 12..<18: return "Buon pomeriggio"
        default: return "Buonasera"
        }
    }
    
    private func getChiusuraSuggestion() -> String {
        let formal = ["Cordiali saluti", "Distinti saluti", "Con stima"]
        let casual = ["Grazie", "A presto", "Buona giornata"]
        
        // Simple heuristic: if recipient has formal domain or subject is formal
        let isFormal = to.contains("@company.") || to.contains("@azienda.") || subject.contains("offerta") || subject.contains("contratto")
        
        return isFormal ? formal.randomElement() ?? "Cordiali saluti" : casual.randomElement() ?? "Grazie"
    }
    
    private func triggerSmartSuggestions() {
        // Implement smart suggestions logic
        // This could analyze the current text and suggest completions
    }
    
    private func removeAttachment(_ attachment: ComposeEmailAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
    
    private func sendEmail() async {
        isSending = true
        
        do {
            try await emailService.sendEmail(to: to, subject: subject, body: emailBody)
            
            await MainActor.run {
                isSending = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSending = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Compose Email Attachment Model
struct ComposeEmailAttachment: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    let mimeType: String
    let size: Int
    
    var iconName: String {
        if mimeType.hasPrefix("image/") {
            return "photo.fill"
        } else if mimeType.hasPrefix("video/") {
            return "video.fill"
        } else if mimeType == "application/pdf" {
            return "doc.fill"
        } else {
            return "doc.fill"
        }
    }
    
    var sizeDescription: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - EmailMessage Extension for Attachments
extension EmailMessage {
    init(id: String, from: String, to: [String], cc: [String]? = nil, bcc: [String]? = nil, 
         subject: String, body: String, date: Date, isRead: Bool, attachments: [Data] = []) {
        self.init(id: id, from: from, to: to, subject: subject, body: body, date: date, isRead: isRead, hasAttachments: !attachments.isEmpty)
    }
}

// MARK: - Preview
#Preview {
    ModernComposeView()
}