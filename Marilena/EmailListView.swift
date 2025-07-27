import SwiftUI
import Combine

// MARK: - Email List View
// Vista principale per la lista delle email con integrazione AI

public struct EmailListView: View {
    @StateObject private var emailService = EmailService()
    @StateObject private var aiService = EmailAIService()
    
    @State private var selectedEmail: EmailMessage?
    @State private var showingEmailDetail = false
    @State private var showingLogin = false
    @State private var searchText = ""
    @State private var selectedCategory: EmailCategory?
    
    // MARK: - Computed Properties
    
    private var filteredEmails: [EmailMessage] {
        var emails = emailService.emails
        
        // Filtra per ricerca
        if !searchText.isEmpty {
            emails = emails.filter { email in
                email.subject.localizedCaseInsensitiveContains(searchText) ||
                email.from.localizedCaseInsensitiveContains(searchText) ||
                email.body.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filtra per categoria (se implementato)
        if let category = selectedCategory {
            // TODO: Implementare filtro per categoria
        }
        
        return emails
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            VStack {
                if emailService.isAuthenticated {
                    emailListContent
                } else {
                    loginContent
                }
            }
            .navigationTitle("Email")
            .searchable(text: $searchText, prompt: "Cerca email...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if emailService.isAuthenticated {
                        Button("Disconnetti") {
                            emailService.disconnect()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEmailDetail) {
            if let email = selectedEmail {
                EmailDetailView(email: email, aiService: aiService)
            }
        }
        .alert("Errore", isPresented: .constant(emailService.error != nil)) {
            Button("OK") {
                emailService.error = nil
            }
        } message: {
            Text(emailService.error ?? "")
        }
    }
    
    // MARK: - Email List Content
    
    private var emailListContent: some View {
        List {
            ForEach(filteredEmails) { email in
                EmailRowView(email: email) {
                    selectedEmail = email
                    showingEmailDetail = true
                }
            }
        }
        .refreshable {
            if let account = emailService.currentAccount {
                await emailService.loadEmails(for: account)
            }
        }
        .overlay {
            if emailService.isLoading {
                ProgressView("Caricamento email...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
    }
    
    // MARK: - Login Content
    
    private var loginContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Connetti il tuo account email")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Accedi al tuo account per iniziare a gestire le email con l'aiuto dell'AI")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button {
                    Task {
                        await emailService.authenticateWithGoogle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.circle.fill")
                        Text("Connetti Gmail")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(emailService.isLoading)
                
                Button {
                    Task {
                        await emailService.authenticateWithMicrosoft()
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.badge.fill")
                        Text("Connetti Outlook")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(emailService.isLoading)
            }
            .padding(.horizontal)
            
            if emailService.isLoading {
                ProgressView("Connessione in corso...")
                    .padding()
            }
        }
        .padding()
    }
}

// MARK: - Email Row View

public struct EmailRowView: View {
    let email: EmailMessage
    let onTap: () -> Void
    
    @State private var category: EmailCategory?
    @State private var urgency: EmailUrgency = .normal
    
    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(email.from)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(email.subject)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDate(email.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !email.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                HStack {
                    if let category = category {
                        Label(category.displayName, systemImage: category.iconName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    if urgency != .normal {
                        Label(urgency.displayName, systemImage: urgencyIcon)
                            .font(.caption)
                            .foregroundColor(urgencyColor)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            analyzeEmail()
        }
    }
    
    private func analyzeEmail() {
        // Analizza l'email per categoria e urgenza
        Task {
            // TODO: Implementare analisi AI per categoria e urgenza
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDate(date, equalTo: calendar.date(byAdding: .day, value: -1, to: now)!, toGranularity: .day) {
            return "Ieri"
        } else {
            formatter.dateFormat = "dd/MM"
        }
        
        return formatter.string(from: date)
    }
    
    private var urgencyIcon: String {
        switch urgency {
        case .high:
            return "exclamationmark.triangle.fill"
        case .medium:
            return "exclamationmark.circle.fill"
        case .low:
            return "checkmark.circle.fill"
        case .normal:
            return "circle.fill"
        }
    }
    
    private var urgencyColor: Color {
        switch urgency {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        case .normal:
            return .secondary
        }
    }
}

// MARK: - Email Detail View

public struct EmailDetailView: View {
    let email: EmailMessage
    @ObservedObject var aiService: EmailAIService
    
    @State private var showingDraft = false
    @State private var selectedDraft: EmailDraft?
    @State private var analysis: EmailAnalysis?
    @State private var summary: String?
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    emailHeader
                    
                    // Content
                    emailContent
                    
                    // AI Analysis
                    if let analysis = analysis {
                        aiAnalysisSection(analysis)
                    }
                    
                    // AI Actions
                    aiActionsSection
                    
                    // Generated Drafts
                    if !aiService.generatedDrafts.isEmpty {
                        draftsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        // Dismiss
                    }
                }
            }
        }
        .onAppear {
            analyzeEmail()
        }
        .alert("Errore AI", isPresented: .constant(aiService.error != nil)) {
            Button("OK") {
                aiService.error = nil
            }
        } message: {
            Text(aiService.error ?? "")
        }
    }
    
    // MARK: - Email Header
    
    private var emailHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(email.subject)
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Da:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(email.from)
                        .font(.body)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Data:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDate(email.date))
                        .font(.body)
                }
            }
            
            if !email.to.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(email.to.joined(separator: ", "))
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Email Content
    
    private var emailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contenuto")
                .font(.headline)
            
            Text(email.body)
                .font(.body)
                .lineSpacing(4)
        }
    }
    
    // MARK: - AI Analysis Section
    
    private func aiAnalysisSection(_ analysis: EmailAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analisi AI")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tono:")
                    Spacer()
                    Text(analysis.tone.capitalized)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Sentiment:")
                    Spacer()
                    Text(analysis.sentiment.capitalized)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Urgenza:")
                    Spacer()
                    Text(analysis.urgency.displayName)
                        .foregroundColor(urgencyColor(analysis.urgency))
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - AI Actions Section
    
    private var aiActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Azioni AI")
                .font(.headline)
            
            VStack(spacing: 8) {
                Button {
                    generateDraft()
                } label: {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                        Text("Genera Bozza di Risposta")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(aiService.isGenerating)
                
                Button {
                    generateMultipleDrafts()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Genera Multiple Bozze")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(aiService.isGenerating)
                
                if let summary = summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Riassunto")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(summary)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Drafts Section
    
    private var draftsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bozze Generate")
                .font(.headline)
            
            ForEach(aiService.generatedDrafts) { draft in
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.content)
                        .font(.body)
                        .lineLimit(6)
                    
                    HStack {
                        Button("Usa") {
                            selectedDraft = draft
                            showingDraft = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Modifica") {
                            // TODO: Implementare modifica
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text(formatDate(draft.generatedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func analyzeEmail() {
        Task {
            analysis = await aiService.analyzeEmail(email)
            summary = await aiService.summarizeEmail(email)
        }
    }
    
    private func generateDraft() {
        Task {
            _ = await aiService.generateDraft(for: email)
        }
    }
    
    private func generateMultipleDrafts() {
        Task {
            _ = await aiService.generateMultipleDrafts(for: email, count: 3)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
    
    private func urgencyColor(_ urgency: EmailUrgency) -> Color {
        switch urgency {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        case .normal:
            return .secondary
        }
    }
} 