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
    @State private var showingEmailSettings = false
    
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
        if selectedCategory != nil {
            // TODO: Implementare filtro per categoria
        }
        
        return emails
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if emailService.isAuthenticated {
                    emailListContent
                } else {
                    loginContent
                }
            }
            .navigationTitle(emailService.currentAccount?.email ?? "Email")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Cerca email...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if emailService.isAuthenticated {
                        Button("Impostazioni") {
                            showingEmailSettings = true
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationDestination(isPresented: $showingEmailDetail) {
                if let email = selectedEmail {
                    EmailDetailView(email: email, aiService: aiService)
                }
            }
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
    
    // MARK: - Email List Content
    
    private var emailListContent: some View {
        VStack(spacing: 0) {
            // Email list - iOS 26 style
            emailList
        }
    }
    

    
    private var emailList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredEmails) { email in
                    EmailRowView(email: email) {
                        selectedEmail = email
                        showingEmailDetail = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 1)
                }
            }
            .padding(.top, 8)
        }
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
                    Text("Caricamento email...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
            
            if filteredEmails.isEmpty && !emailService.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Nessuna email trovata")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Le tue email appariranno qui")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Login Content
    
    private var loginContent: some View {
        VStack(spacing: 0) {
            // Header con icona e titolo
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    Text("Connetti il tuo account email")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Accedi al tuo account per iniziare a gestire le email con l'aiuto dell'AI")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Pulsanti di connessione
            VStack(spacing: 16) {
                // Pulsante Gmail
                Button {
                    Task {
                        await emailService.authenticateWithGoogle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.title2)
                        Text("Connetti Gmail")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .foregroundColor(.white)
                }
                .disabled(emailService.isLoading)
                .scaleEffect(emailService.isLoading ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: emailService.isLoading)
                
                // Pulsante Outlook
                Button {
                    Task {
                        await emailService.authenticateWithMicrosoft()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.title2)
                        Text("Connetti Outlook")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange)
                            .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .foregroundColor(.white)
                }
                .disabled(emailService.isLoading)
                .scaleEffect(emailService.isLoading ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: emailService.isLoading)
            }
            .padding(.horizontal, 24)
            
            // Indicatore di caricamento
            if emailService.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Connessione in corso...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
            }
            
            Spacer()
            
            // Footer con informazioni
            VStack(spacing: 8) {
                Text("Le tue email sono protette e sicure")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Label("Crittografia", systemImage: "lock.shield")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Label("Privacy", systemImage: "eye.slash")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
            HStack(spacing: 16) {
                // Unread indicator - iOS 26 style
                VStack {
                    if !email.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                    }
                    Spacer()
                }
                .frame(width: 10)
                
                // Main content
                VStack(alignment: .leading, spacing: 6) {
                    // Sender and date
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(email.from)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
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
                            
                            // Urgency indicator
                            if urgency != .normal {
                                Image(systemName: urgencyIcon)
                                    .font(.caption)
                                    .foregroundColor(urgencyColor)
                            }
                        }
                    }
                    
                    // Email preview
                    Text(email.body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Category tag
                    if let category = category {
                        HStack {
                            Text(category.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(category.color.opacity(0.15))
                                )
                                .foregroundColor(category.color)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
            )

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
// La definizione di EmailDetailView è stata spostata in EmailDetailView.swift 