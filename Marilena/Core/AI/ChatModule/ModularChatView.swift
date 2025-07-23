import SwiftUI
import Combine

// MARK: - Modular Chat View (Riusabile)
// Vista di chat modulare e riutilizzabile

public struct ModularChatView: View {
    @StateObject private var chatService: ChatService
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingSettings = false
    
    // MARK: - Configuration
    private let title: String
    private let showSettings: Bool
    private let customConfiguration: ChatConfiguration?
    
    // MARK: - Initialization
    
    public init(
        title: String = "Chat AI",
        configuration: ChatConfiguration? = nil,
        showSettings: Bool = true
    ) {
        self.title = title
        self.customConfiguration = configuration
        self.showSettings = showSettings
        
        self._chatService = StateObject(wrappedValue: ChatService(configuration: configuration))
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Messages
            messagesView
            
            // Input
            messageInputView
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if showSettings {
                    settingsButton
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            ChatSettingsView(chatService: chatService)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 8) {
            if let error = chatService.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            if chatService.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Elaborazione in corso...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatService.messages) { message in
                        MessageBubbleView(message: message)
                    }
                    
                    if chatService.isProcessing {
                        ModularTypingIndicatorView()
                    }
                }
                .padding()
            }
            .onChange(of: chatService.messages.count) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatService.isProcessing) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // MARK: - Message Input View
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                // Text field
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.systemGray6))
                        .frame(height: calculateTextEditorHeight())
                    
                    if messageText.isEmpty {
                        Text("Scrivi un messaggio...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $messageText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .focused($isTextFieldFocused)
                        .disabled(chatService.isProcessing)
                        .scrollContentBackground(.hidden)
                        .frame(height: calculateTextEditorHeight())
                        .onSubmit {
                            sendMessage()
                        }
                }
                .animation(.easeOut(duration: 0.2), value: messageText.count)
                
                // Send button
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isProcessing ? 
                                  Color(.systemGray4) : Color.blue)
                            .frame(width: 44, height: 44)
                        
                        if chatService.isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isProcessing)
                .scaleEffect(chatService.isProcessing ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chatService.isProcessing)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Settings Button
    
    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !chatService.isProcessing else { return }
        
        Task {
            await chatService.sendMessage(trimmedText)
            messageText = ""
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatService.messages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func calculateTextEditorHeight() -> CGFloat {
        let minHeight: CGFloat = 44
        let maxHeight: CGFloat = 120
        let lineHeight: CGFloat = 20
        let lines = messageText.components(separatedBy: "\n").count
        let calculatedHeight = CGFloat(lines) * lineHeight + 24
        
        return max(minHeight, min(calculatedHeight, maxHeight))
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ModularChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                messageContent
                    .background(Color.blue)
                    .foregroundColor(.white)
            } else {
                messageContent
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                Spacer()
            }
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.content)
                .font(.body)
                .multilineTextAlignment(.leading)
            
            if let metadata = message.metadata {
                HStack {
                    if let model = metadata.model {
                        Text(model)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let processingTime = metadata.processingTime {
                        Text(String(format: "%.1fs", processingTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cornerRadius(18)
    }
}

// MARK: - Typing Indicator View

struct ModularTypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0 + animationOffset)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(18)
            
            Spacer()
        }
        .onAppear {
            animationOffset = 0.3
        }
    }
}

// MARK: - Chat Settings View

struct ChatSettingsView: View {
    @ObservedObject var chatService: ChatService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Statistiche") {
                    let stats = chatService.getConversationStats()
                    
                    HStack {
                        Text("Messaggi totali")
                        Spacer()
                        Text("\(stats.totalMessages)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Messaggi utente")
                        Spacer()
                        Text("\(stats.userMessages)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Messaggi assistente")
                        Spacer()
                        Text("\(stats.assistantMessages)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Token totali")
                        Spacer()
                        Text("\(stats.totalTokens)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Tempo medio elaborazione")
                        Spacer()
                        Text(String(format: "%.1fs", stats.averageProcessingTime))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Azioni") {
                    Button("Esporta conversazione") {
                        let export = chatService.exportConversation()
                        // TODO: Implementare condivisione
                        print("📤 Esportazione: \(export)")
                    }
                    
                    Button("Cancella conversazione", role: .destructive) {
                        chatService.clearMessages()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Impostazioni Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ModularChatView(title: "Chat AI Demo")
    }
} 