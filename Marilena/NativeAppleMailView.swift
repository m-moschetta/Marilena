import SwiftUI
import WebKit
#if canImport(MessageUI)
import MessageUI
#endif
import Combine

// MARK: - Native Apple Mail View
/// Vista email completamente nativa che rispetta gli standard SwiftUI
/// Swipe back gesture nativo funziona automaticamente
struct NativeAppleMailView: View {
    let email: EmailMessage
    @ObservedObject var emailService: EmailService
    @ObservedObject var aiService: EmailAIService
    
    // RIMUOVENDO @Environment(\.dismiss) - non serve con navigazione nativa
    @Environment(\.colorScheme) private var colorScheme
    
    // AI States
    @State private var analysis: EmailAnalysis?
    @State private var summary: String?
    @State private var showingAI = false
    @State private var isAnalyzing = false
    
    // UI States 
    @State private var showingReplySheet = false
    @State private var showingForwardSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingCustomPrompt = false
    @State private var customPrompt = ""
    @State private var selectedDraft: EmailDraft?
    @State private var forwardData: (subject: String, body: String)?
    @State private var showingShareSheet = false
    @State private var showingActionSheet = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // MARK: - Email Header (Nativo)
                nativeEmailHeader
                
                // MARK: - AI Section (Opzionale)
                if showingAI {
                    aiAnalysisSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))
                        .animation(.easeInOut(duration: 0.3), value: showingAI)
                }
                
                // MARK: - Email Content
                emailContentSection
                
                // Spacer per evitare che il contenuto sia troppo vicino al bottom
                Color.clear.frame(height: 100)
            }
        }
        // NAVIGAZIONE COMPLETAMENTE NATIVA - NO CUSTOMIZZAZIONI CHE INTERFERISCONO
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // AI Toggle
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingAI.toggle()
                    }
                } label: {
                    Image(systemName: showingAI ? "brain.head.profile.fill" : "brain.head.profile")
                        .foregroundColor(showingAI ? .purple : .secondary)
                }
            }
            
            // Action Menu
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Reply Actions
                    Section("Risposta") {
                        Button {
                            showingReplySheet = true
                        } label: {
                            Label("Rispondi", systemImage: "arrowshape.turn.up.left")
                        }
                        
                        Button {
                            // Reply All - TODO: implementare
                        } label: {
                            Label("Rispondi a tutti", systemImage: "arrowshape.turn.up.left.2")
                        }
                        
                        Button {
                            forwardData = emailService.prepareForwardEmail(email)
                            showingForwardSheet = true
                        } label: {
                            Label("Inoltra", systemImage: "arrowshape.turn.up.right")
                        }
                    }
                    
                    // Other Actions
                    Section("Azioni") {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Condividi", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            // Move to folder - TODO: implementare
                        } label: {
                            Label("Sposta", systemImage: "folder")
                        }
                        
                        Button {
                            // Mark as flag - TODO: implementare  
                        } label: {
                            Label("Contrassegna", systemImage: "flag")
                        }
                    }
                    
                    // Destructive Actions
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            Task {
                await emailService.markEmailAsRead(email.id)
                await analyzeEmail()
            }
        }
        // MARK: - Sheets e Alerts
        .sheet(isPresented: $showingReplySheet) {
            if let draft = selectedDraft {
                ComposeEmailView(replyTo: email, preFilledDraft: draft)
            } else {
                ComposeEmailView(replyTo: email, preFilledDraft: nil)
            }
        }
        .sheet(isPresented: $showingForwardSheet) {
            if let forwardData = forwardData {
                ComposeEmailView(
                    initialSubject: forwardData.subject,
                    initialBody: forwardData.body
                )
            }
        }
        .sheet(isPresented: $showingCustomPrompt) {
            CustomPromptView(
                prompt: $customPrompt,
                onGenerate: generateCustomResponse,
                onCancel: { showingCustomPrompt = false }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            NativeShareSheet(email: email)
        }
        .alert("Elimina Email", isPresented: $showingDeleteAlert) {
            Button("Elimina", role: .destructive) {
                Task {
                    do {
                        try await emailService.deleteEmail(email.id)
                        // Con navigazione nativa, il back è automatico quando si elimina
                    } catch {
                        print("❌ Errore eliminazione email: \(error)")
                    }
                }
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Sei sicuro di voler eliminare questa email?")
        }
    }
    
    // MARK: - Email Header (Native Style)
    private var nativeEmailHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Subject
            Text(email.subject)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Sender and Date
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(email.from.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(email.from)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text("a me")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Analysis badges if available
                        if let analysis = analysis {
                            HStack(spacing: 4) {
                                Image(systemName: analysis.urgency.icon)
                                    .font(.caption2)
                                Text(analysis.urgency.displayName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(Color(analysis.urgency.color))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(analysis.urgency.color).opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Date and time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDate(email.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }
    
    // MARK: - AI Analysis Section
    private var aiAnalysisSection: some View {
        VStack(spacing: 16) {
            if let analysis = analysis {
                VStack(alignment: .leading, spacing: 12) {
                    // Summary if available
                    if let summary = summary {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "brain.head.profile.fill")
                                    .foregroundColor(.purple)
                                Text("Riassunto AI")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            Text(summary)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineLimit(4)
                        }
                    }
                    
                    // Quick Response Buttons (Native Style)
                    HStack(spacing: 12) {
                        Button("✅ Accetta") {
                            handleResponseType(.yes)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        
                        Button("❌ Rifiuta") {
                            handleResponseType(.no)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Button("✏️ Personalizza") {
                            showingCustomPrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.regularMaterial)
            }
        }
    }
    
    // MARK: - Email Content Section
    private var emailContentSection: some View {
        VStack(spacing: 0) {
            if EmailContentAnalyzer.isHTMLContent(email.body) {
                // HTML Content usando il nuovo renderer unificato
                EmailHTMLRenderer(email: email)
                    .padding(.horizontal, 0) // HTML renderer gestisce il padding internamente
            } else {
                // Plain Text Content
                VStack(alignment: .leading, spacing: 16) {
                    Text(email.body)
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func analyzeEmail() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        
        // Analyze
        if let result = await aiService.analyzeEmail(email) {
            await MainActor.run {
                self.analysis = result
            }
        }
        
        // Summarize
        if let summaryResult = await aiService.summarizeEmail(email) {
            await MainActor.run {
                self.summary = summaryResult
            }
        }
        
        isAnalyzing = false
    }
    
    private func handleResponseType(_ type: ResponseType) {
        Task {
            switch type {
            case .yes:
                if let draft = await aiService.generateDraft(
                    for: email,
                    context: "Genera una risposta professionale e positiva che accetta quanto proposto nell'email."
                ) {
                    selectedDraft = draft
                    showingReplySheet = true
                }
            case .no:
                if let draft = await aiService.generateDraft(
                    for: email,
                    context: "Genera una risposta professionale e cortese che rifiuta gentilmente quanto proposto nell'email."
                ) {
                    selectedDraft = draft
                    showingReplySheet = true
                }
            case .custom:
                showingCustomPrompt = true
            }
        }
    }
    
    private func generateCustomResponse() {
        Task {
            if let draft = await aiService.generateCustomResponse(
                for: email,
                basedOn: nil,
                withPrompt: customPrompt
            ) {
                selectedDraft = draft
                showingReplySheet = true
                showingCustomPrompt = false
                customPrompt = ""
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ieri"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Native Share Sheet 
struct NativeShareSheet: UIViewControllerRepresentable {
    let email: EmailMessage
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = [
            "Email: \(email.subject)",
            "Da: \(email.from)",
            "Data: \(formatDate(email.date))",
            "",
            email.body
        ]
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .postToFlickr,
            .postToVimeo
        ]
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// ResponseType è già definito in EmailDetailView.swift