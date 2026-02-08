import SwiftUI
import WebKit
#if canImport(MessageUI)
import MessageUI
#endif

// MARK: - Unified Email Viewer
/// Viewer email unificato e nativo che combina il meglio di tutte le implementazioni
/// - Design pulito e consistente
/// - Navigazione nativa iOS perfetta
/// - AI Panel modulare
/// - Componenti riutilizzabili

struct UnifiedEmailViewer: View {
    let email: EmailMessage
    @ObservedObject var emailService: EmailService
    @ObservedObject var aiService: EmailAIService
    
    // MARK: - States
    @State private var showingReplySheet = false
    @State private var showingForwardSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingComposeWithDraft = false
    @State private var showingMoveSheet = false
    
    // AI States
    @State private var analysis: EmailAnalysis?
    @State private var summary: String?
    @State private var showingAI = false
    @State private var isAnalyzing = false
    @State private var selectedDraft: EmailDraft?
    @State private var forwardData: (subject: String, body: String)?
    
    // UI
    @Environment(\.colorScheme) private var colorScheme
    @State private var showBottomBar = true
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // MARK: - Email Header
                emailHeaderSection
                
                // MARK: - AI Panel (Collapsible)
                if showingAI {
                    aiPanelSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
                
                // MARK: - Email Content
                emailContentSection
                
                // Spacer per bottom bar
                Color.clear.frame(height: 80)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Leading: AI Toggle
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingAI.toggle()
                    }
                } label: {
                    Image(systemName: showingAI ? "sparkles" : "sparkles")
                        .foregroundColor(showingAI ? .purple : .secondary)
                        .symbolEffect(.bounce, value: showingAI)
                }
                .accessibilityLabel(showingAI ? "Nascondi AI" : "Mostra AI")
            }
            
            // Trailing: Actions Menu
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Reply Section
                    Section("Risposta") {
                        Button {
                            showingReplySheet = true
                        } label: {
                            Label("Rispondi", systemImage: "arrowshape.turn.up.left")
                        }
                        
                        Button {
                            // Reply All
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
                    
                    // Actions Section
                    Section("Azioni") {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Condividi", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            showingMoveSheet = true
                        } label: {
                            Label("Sposta", systemImage: "folder")
                        }
                        
                        Button {
                            // Toggle flag
                        } label: {
                            Label("Contrassegna", systemImage: "flag")
                        }
                        
                        Button {
                            // Archive
                            Task {
                                await emailService.archiveEmail(email.id)
                            }
                        } label: {
                            Label("Archivia", systemImage: "archivebox")
                        }
                    }
                    
                    // Destructive Section
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
        .safeAreaInset(edge: .bottom) {
            // Bottom Action Bar
            bottomActionBar
        }
        .onAppear {
            Task {
                await emailService.markEmailAsRead(email.id)
                await analyzeEmail()
            }
        }
        // MARK: - Sheets
        .sheet(isPresented: $showingReplySheet) {
            if let draft = selectedDraft {
                ModernComposeView(
                    replyTo: email,
                    initialTo: email.from,
                    initialSubject: "Re: \(email.subject)",
                    initialBody: draft.content
                )
            } else {
                ModernComposeView(
                    replyTo: email,
                    initialTo: email.from,
                    initialSubject: "Re: \(email.subject)"
                )
            }
        }
        .sheet(isPresented: $showingForwardSheet) {
            if let forwardData = forwardData {
                ModernComposeView(
                    initialSubject: forwardData.subject,
                    initialBody: forwardData.body
                )
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [email.subject, email.body])
        }
        // MARK: - Alerts
        .alert("Elimina Email", isPresented: $showingDeleteAlert) {
            Button("Elimina", role: .destructive) {
                Task {
                    do {
                        try await emailService.deleteEmail(email.id)
                    } catch {
                        print("❌ Errore eliminazione: \(error)")
                    }
                }
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Sei sicuro di voler eliminare questa email?")
        }
    }
    
    // MARK: - Email Header Section
    private var emailHeaderSection: some View {
        VStack(alignment: .leading, spacing: EmailDesign.Spacing.md) {
            // Subject
            Text(email.subject)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Sender Row
            HStack(spacing: EmailDesign.Spacing.md) {
                // Avatar
                UnifiedEmailAvatarView(email: email, size: EmailDesign.Avatar.size)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(extractDisplayName(from: email.from))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: EmailDesign.Spacing.sm) {
                        Text("a me")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let analysis = analysis {
                            UrgencyBadge(urgency: analysis.urgency)
                        }
                    }
                }
                
                Spacer()
                
                // Date
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDate(email.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(email.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, EmailDesign.Spacing.lg)
        .padding(.vertical, EmailDesign.Spacing.md)
        .background(.regularMaterial)
    }
    
    // MARK: - AI Panel Section
    private var aiPanelSection: some View {
        VStack(spacing: EmailDesign.Spacing.md) {
            // AI Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .symbolEffect(.pulse)
                    
                    Text("Assistente AI")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation {
                        showingAI.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // Analysis Cards
            if let analysis = analysis {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    UnifiedAnalysisCard(
                        title: "Urgenza",
                        value: analysis.urgency.displayName,
                        icon: analysis.urgency.icon,
                        color: Color(analysis.urgency.color)
                    )
                    
                    UnifiedAnalysisCard(
                        title: "Categoria",
                        value: analysis.category.displayName,
                        icon: analysis.category.icon,
                        color: analysis.category.color
                    )
                }
            }
            
            // Summary
            if let summary = summary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Riassunto")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text(summary)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: EmailDesign.CornerRadius.md))
            }
            
            // Quick Actions
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Accetta",
                    icon: "checkmark.circle.fill",
                    color: .green
                ) {
                    generateQuickResponse(type: .positive)
                }
                
                QuickActionButton(
                    title: "Rifiuta",
                    icon: "xmark.circle.fill",
                    color: .red
                ) {
                    generateQuickResponse(type: .negative)
                }
                
                QuickActionButton(
                    title: "Personalizza",
                    icon: "pencil.circle.fill",
                    color: .blue
                ) {
                    // Show custom prompt
                }
            }
        }
        .padding(.horizontal, EmailDesign.Spacing.lg)
        .padding(.vertical, EmailDesign.Spacing.md)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Email Content Section
    private var emailContentSection: some View {
        VStack(spacing: 0) {
            if EmailContentAnalyzer.isHTMLContent(email.body) {
                EmailHTMLRenderer(email: email)
                    .padding(.horizontal, EmailDesign.Spacing.md)
            } else {
                Text(email.body)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, EmailDesign.Spacing.lg)
                    .padding(.vertical, EmailDesign.Spacing.md)
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack(spacing: 0) {
            // Reply
            UnifiedBottomBarButton(
                icon: "arrowshape.turn.up.left",
                label: "Rispondi",
                color: .blue
            ) {
                showingReplySheet = true
            }
            
            Divider()
                .frame(height: 24)
            
            // Forward
            UnifiedBottomBarButton(
                icon: "arrowshape.turn.up.right",
                label: "Inoltra",
                color: .indigo
            ) {
                forwardData = emailService.prepareForwardEmail(email)
                showingForwardSheet = true
            }
            
            Divider()
                .frame(height: 24)
            
            // Archive
            UnifiedBottomBarButton(
                icon: "archivebox",
                label: "Archivia",
                color: .green
            ) {
                Task {
                    await emailService.archiveEmail(email.id)
                }
            }
            
            Divider()
                .frame(height: 24)
            
            // Delete
            UnifiedBottomBarButton(
                icon: "trash",
                label: "Elimina",
                color: .red
            ) {
                showingDeleteAlert = true
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.separator)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }
    
    // MARK: - Helper Methods
    private func analyzeEmail() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        
        if let result = await aiService.analyzeEmail(email) {
            await MainActor.run {
                self.analysis = result
            }
        }
        
        if let summaryResult = await aiService.summarizeEmail(email) {
            await MainActor.run {
                self.summary = summaryResult
            }
        }
        
        isAnalyzing = false
    }
    
    private func generateQuickResponse(type: UnifiedQuickResponseType) {
        Task {
            let context: String
            switch type {
            case .positive:
                context = "Genera una risposta professionale e positiva che accetta quanto proposto."
            case .negative:
                context = "Genera una risposta educata ma che rifiuta gentilmente la richiesta."
            case .professional:
                context = "Genera una risposta professionale e formale."
            }
            
            if let draft = await aiService.generateDraft(for: email, context: context) {
                await MainActor.run {
                    selectedDraft = draft
                    showingReplySheet = true
                }
            }
        }
    }
    
    private func extractDisplayName(from email: String) -> String {
        if let range = email.range(of: "<") {
            let displayName = String(email[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            return displayName.isEmpty ? email : displayName
        }
        return email
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types
enum UnifiedQuickResponseType {
    case positive, negative, professional
}

// MARK: - Reusable Components

struct UnifiedEmailAvatarView: View {
    let email: EmailMessage
    var size: CGFloat = 40
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var initials: String {
        let from = email.from
        let name: String
        
        if let range = from.range(of: "<") {
            name = String(from[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else {
            name = from
        }
        
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1)).uppercased()
            let second = String(components[1].prefix(1)).uppercased()
            return first + second
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

struct UrgencyBadge: View {
    let urgency: EmailUrgency
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: urgency.icon)
                .font(.caption2)
            Text(urgency.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(Color(urgency.color))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(urgency.color).opacity(0.1))
        .clipShape(Capsule())
    }
}

struct UnifiedAnalysisCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: EmailDesign.CornerRadius.sm))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct UnifiedBottomBarButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Design System

enum EmailDesign {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
    }
    
    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
    
    enum Avatar {
        static let size: CGFloat = 40
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        UnifiedEmailViewer(
            email: EmailMessage(
                id: "1",
                accountId: "default",
                from: "Mario Rossi <mario@example.com>",
                to: ["me@example.com"],
                subject: "Test Email Subject",
                body: "This is a test email body content.",
                date: Date(),
                isRead: false,
                hasAttachments: false
            ),
            emailService: EmailService(),
            aiService: EmailAIService()
        )
    }
}
