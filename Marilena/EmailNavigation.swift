import SwiftUI

// MARK: - Email Navigation Extension
/// Estensione per configurare la navigazione email con UnifiedEmailViewer

public struct EmailNavigationModifier: ViewModifier {
    private let emailService: EmailService
    private let aiService: EmailAIService

    public init(emailService: EmailService, aiService: EmailAIService) {
        self.emailService = emailService
        self.aiService = aiService
    }
    
    public func body(content: Content) -> some View {
        content
            .navigationDestination(for: EmailMessage.self) { email in
                UnifiedEmailViewer(
                    email: email,
                    emailService: emailService,
                    aiService: aiService
                )
            }
            .navigationDestination(for: EmailConversation.self) { conversation in
                // Per conversazioni, mostra il primo messaggio
                if let firstEmail = conversation.messages.first {
                    UnifiedEmailViewer(
                        email: firstEmail,
                        emailService: emailService,
                        aiService: aiService
                    )
                } else {
                    EmptyEmailView()
                }
            }
    }
}

public extension View {
    /// Aggiunge la navigazione email con UnifiedEmailViewer
    func withEmailNavigation(emailService: EmailService, aiService: EmailAIService) -> some View {
        modifier(EmailNavigationModifier(emailService: emailService, aiService: aiService))
    }
}

// MARK: - Empty Email View

struct EmptyEmailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Conversazione vuota")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Non ci sono messaggi in questa conversazione")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        Text("Test Navigation")
            .withEmailNavigation(
                emailService: EmailService(),
                aiService: EmailAIService()
            )
    }
}
