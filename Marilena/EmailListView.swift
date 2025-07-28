import SwiftUI
import Combine

// MARK: - iOS 26 Enhanced Email List View
// Vista principale modernizzata per iOS 26 con Liquid Glass e SwipeActions native

public struct EmailListView: View {
    @StateObject private var emailService = EmailService()
    @StateObject private var aiService = EmailAIService()
    
    @State private var selectedEmail: EmailMessage?
    @State private var showingEmailDetail = false
    @State private var showingLogin = false
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedCategory: EmailCategory?
    @State private var useAppleMailStyle = true
    @State private var showingEmailSettings = false
    
    // iOS 26 States
    @State private var showingComposeSheet = false
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Helper Functions
    private func destinationView(for email: EmailMessage) -> some View {
        Group {
            if useAppleMailStyle {
                AppleMailDetailView(
                    email: email,
                    emailService: emailService,
                    aiService: aiService
                )
            } else {
                EmailDetailView(
                    email: email,
                    aiService: aiService
                )
            }
        }
    }
    
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
        
        return emails
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if emailService.isAuthenticated {
                    modernEmailListContent
                } else {
                    loginContent
                }
            }
            .navigationTitle(emailService.currentAccount?.email ?? "Email")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Cerca email...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if emailService.isAuthenticated {
                        Button {
                            showingEmailSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .foregroundStyle(.blue.gradient)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if emailService.isAuthenticated {
                        Button {
                            showingComposeSheet = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .foregroundStyle(.blue.gradient)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingComposeSheet) {
            ComposeEmailView()
        }
        .sheet(isPresented: $showingEmailSettings) {
            EmailSettingsView()
        }
        .alert("Errore", isPresented: .constant(emailService.error != nil)) {
            Button("OK") {
                emailService.error = nil
            }
        } message: {
            Text(emailService.error ?? "")
        }
        .onAppear {
            // Ripristina l'autenticazione all'avvio
            Task {
                await emailService.restoreAuthentication()
            }
        }
    }
    
    // MARK: - Modern Email List Content (iOS 26)
    
    private var modernEmailListContent: some View {
        List {
            ForEach(filteredEmails) { email in
                NavigationLink(destination: destinationView(for: email)) {
                    ModernEmailRowView(email: email)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                // iOS 26 SwipeActions
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    // Mark as Read/Unread
                    Button {
                        Task {
                            await toggleReadStatus(for: email)
                        }
                    } label: {
                        Label(
                            email.isRead ? "Non letta" : "Letta", 
                            systemImage: email.isRead ? "envelope.badge" : "envelope.open"
                        )
                    }
                    .tint(.blue)
                    
                    // Pin Email
                    Button {
                        pinEmail(email)
                    } label: {
                        Label("Pin", systemImage: "pin.fill")
                    }
                    .tint(.orange)
                    
                    // Archive
                    Button {
                        archiveEmail(email)
                    } label: {
                        Label("Archivia", systemImage: "archivebox.fill")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Delete
                    Button(role: .destructive) {
                        Task {
                            await deleteEmail(email)
                        }
                    } label: {
                        Label("Elimina", systemImage: "trash.fill")
                    }
                    
                    // Forward
                    Button {
                        forwardEmail(email)
                    } label: {
                        Label("Inoltra", systemImage: "arrowshape.turn.up.right.fill")
                    }
                    .tint(.indigo)
                    
                    // Reply
                    Button {
                        replyToEmail(email)
                    } label: {
                        Label("Rispondi", systemImage: "arrowshape.turn.up.left.fill")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            if let account = emailService.currentAccount {
                await emailService.loadEmails(for: account)
            }
        }
        .overlay {
            if emailService.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .foregroundStyle(.blue)
                    Text("Caricamento email...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .liquidGlass(.subtle)
            }
            
            if filteredEmails.isEmpty && !emailService.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Nessuna email trovata")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("Le tue email appariranno qui")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - SwipeAction Functions
    
    private func toggleReadStatus(for email: EmailMessage) async {
        hapticFeedback.impactOccurred()
        await emailService.markEmailAsRead(email.id)
    }
    
    private func pinEmail(_ email: EmailMessage) {
        hapticFeedback.impactOccurred()
        // TODO: Implementare pin functionality
        print("📌 Pin email: \(email.subject)")
    }
    
    private func archiveEmail(_ email: EmailMessage) {
        hapticFeedback.impactOccurred()
        // TODO: Implementare archive functionality
        print("📦 Archive email: \(email.subject)")
    }
    
    private func deleteEmail(_ email: EmailMessage) async {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        do {
            try await emailService.deleteEmail(email.id)
        } catch {
            print("❌ Error deleting email: \(error)")
        }
    }
    
    private func forwardEmail(_ email: EmailMessage) {
        hapticFeedback.impactOccurred()
        // TODO: Show compose sheet with forward data
        print("↪️ Forward email: \(email.subject)")
    }
    
    private func replyToEmail(_ email: EmailMessage) {
        hapticFeedback.impactOccurred()
        // TODO: Show compose sheet with reply data
        print("↩️ Reply to email: \(email.subject)")
    }
    
    // MARK: - Login Content
    
    private var loginContent: some View {
        VStack(spacing: 30) {
            // Icon iOS 26 style
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.multicolor)
            
            VStack(spacing: 12) {
                Text("Accedi alla tua Email")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Connetti il tuo account email per iniziare")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                // Google Login - iOS 26 style
                Button {
                    Task {
                        await emailService.authenticateWithGoogle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.circle")
                            .font(.title2)
                        Text("Accedi con Google")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    .liquidGlass(.prominent)
                }
                
                // Microsoft Login - iOS 26 style
                Button {
                    Task {
                        await emailService.authenticateWithMicrosoft()
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.circle")
                            .font(.title2)
                        Text("Accedi con Microsoft")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 12))
                    .liquidGlass(.prominent)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .liquidGlass(.subtle)
    }
}

// MARK: - Modern Email Row View (iOS 26)
private struct ModernEmailRowView: View {
    let email: EmailMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Read indicator - iOS 26 style
            Circle()
                .fill(email.isRead ? Color.clear : .blue)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Email type indicator with SF Symbols 7
                    Image(systemName: email.emailType.icon)
                        .font(.caption)
                        .foregroundStyle(email.emailType.color)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text(email.emailType == .sent ? "A: \(email.to.first ?? "")" : email.from)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(formatDate(email.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(email.subject)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(email.body.stripHTML())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .liquidGlass(.subtle)
        .contentShape(Rectangle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
        } else if Calendar.current.isDateInYesterday(date) {
            return "Ieri"
        } else {
            formatter.dateStyle = .short
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - String Extension for HTML Stripping
extension String {
    func stripHTML() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
} 