// MARK: - Esempio Completo Integrazione Chat Module
// Questo file contiene tutto il codice necessario per integrare il modulo chat in un'altra app iOS

import SwiftUI
import CoreData
import Combine

// MARK: - 1. Configurazione App

@main
struct YourApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

// MARK: - 2. Configurazione Core Data

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "YourApp") // Cambia il nome del modello
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Errore caricamento Core Data: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// MARK: - 3. Configurazione API Keys

struct Config {
    static let openAIApiKey = "your-openai-key"
    static let anthropicApiKey = "your-anthropic-key"
    static let groqApiKey = "your-groq-key"
    static let perplexityApiKey = "your-perplexity-key"
}

// MARK: - 4. App Delegate (per configurazione iniziale)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configura le API keys
        KeychainManager.shared.saveAPIKey(Config.openAIApiKey, for: "openaiApiKey")
        KeychainManager.shared.saveAPIKey(Config.anthropicApiKey, for: "anthropicApiKey")
        KeychainManager.shared.saveAPIKey(Config.groqApiKey, for: "groqApiKey")
        KeychainManager.shared.saveAPIKey(Config.perplexityApiKey, for: "perplexityApiKey")
        
        return true
    }
}

// MARK: - 5. Vista Principale

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            ChatListView()
        }
        .environment(\.managedObjectContext, viewContext)
    }
}

// MARK: - 6. Lista Chat

struct ChatListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: ChatMarilena.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatMarilena.dataCreazione, ascending: false)]
    ) private var chats: FetchedResults<ChatMarilena>
    
    @State private var showingNewChat = false
    
    var body: some View {
        List {
            ForEach(chats, id: \.objectID) { chat in
                NavigationLink(destination: ModularChatView(chat: chat)) {
                    ChatRowView(chat: chat)
                }
            }
            .onDelete(perform: deleteChats)
        }
        .navigationTitle("Le Mie Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Nuova Chat") {
                    createNewChat()
                }
            }
        }
        .sheet(isPresented: $showingNewChat) {
            NewChatView()
        }
    }
    
    private func createNewChat() {
        let newChat = ChatMarilena(context: viewContext)
        newChat.id = UUID()
        newChat.titolo = "Nuova Chat"
        newChat.dataCreazione = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Errore salvataggio chat: \(error)")
        }
    }
    
    private func deleteChats(offsets: IndexSet) {
        withAnimation {
            offsets.map { chats[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Errore eliminazione chat: \(error)")
            }
        }
    }
}

// MARK: - 7. Riga Chat

struct ChatRowView: View {
    let chat: ChatMarilena
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chat.titolo ?? "Chat senza titolo")
                .font(.headline)
                .lineLimit(1)
            
            if let lastMessage = chat.messaggi?.lastObject as? MessaggioMarilena {
                Text(lastMessage.contenuto ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(chat.dataCreazione?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.caption2)
                    .foregroundColor(.tertiary)
                
                Spacer()
                
                if let messageCount = chat.messaggi?.count, messageCount > 0 {
                    Text("\(messageCount) messaggi")
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 8. Vista Nuova Chat

struct NewChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var chatTitle = ""
    @State private var selectedModel = "gpt-4o-mini"
    
    private let availableModels = [
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4.1",
        "gpt-4.1-mini",
        "claude-sonnet-4-20250514",
        "llama-3.3-70b-versatile"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Informazioni Chat") {
                    TextField("Titolo Chat", text: $chatTitle)
                    
                    Picker("Modello AI", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
                
                Section("Configurazione") {
                    HStack {
                        Text("Provider AI")
                        Spacer()
                        Text(getProviderName(for: selectedModel))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Token")
                        Spacer()
                        Text("4000")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Nuova Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Crea") {
                        createChat()
                    }
                    .disabled(chatTitle.isEmpty)
                }
            }
        }
    }
    
    private func getProviderName(for model: String) -> String {
        if model.contains("gpt") {
            return "OpenAI"
        } else if model.contains("claude") {
            return "Anthropic"
        } else if model.contains("llama") {
            return "Groq"
        }
        return "OpenAI"
    }
    
    private func createChat() {
        let newChat = ChatMarilena(context: viewContext)
        newChat.id = UUID()
        newChat.titolo = chatTitle.isEmpty ? "Nuova Chat" : chatTitle
        newChat.dataCreazione = Date()
        
        // Salva il modello selezionato
        UserDefaults.standard.set(selectedModel, forKey: "selected_model")
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Errore creazione chat: \(error)")
        }
    }
}

// MARK: - 9. Vista Impostazioni

struct SettingsView: View {
    @AppStorage("selected_model") private var selectedModel = "gpt-4o-mini"
    @AppStorage("selected_perplexity_model") private var selectedPerplexityModel = "sonar-pro"
    @AppStorage("max_tokens") private var maxTokens = 4000
    @AppStorage("temperature") private var temperature = 0.7
    
    var body: some View {
        NavigationView {
            Form {
                Section("Modelli AI") {
                    Picker("Modello Chat", selection: $selectedModel) {
                        Text("GPT-4o").tag("gpt-4o")
                        Text("GPT-4o Mini").tag("gpt-4o-mini")
                        Text("GPT-4.1").tag("gpt-4.1")
                        Text("Claude Sonnet").tag("claude-sonnet-4-20250514")
                        Text("Llama 3.3").tag("llama-3.3-70b-versatile")
                    }
                    
                    Picker("Modello Ricerca", selection: $selectedPerplexityModel) {
                        Text("Sonar").tag("sonar")
                        Text("Sonar Pro").tag("sonar-pro")
                        Text("Sonar Deep Research").tag("sonar-deep-research")
                    }
                }
                
                Section("Parametri") {
                    HStack {
                        Text("Max Token")
                        Spacer()
                        TextField("4000", value: $maxTokens, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Temperature")
                        Spacer()
                        TextField("0.7", value: $temperature, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Provider AI") {
                    ProviderStatusView(provider: "OpenAI", isConfigured: hasValidAPIKey(for: "openaiApiKey"))
                    ProviderStatusView(provider: "Anthropic", isConfigured: hasValidAPIKey(for: "anthropicApiKey"))
                    ProviderStatusView(provider: "Groq", isConfigured: hasValidAPIKey(for: "groqApiKey"))
                    ProviderStatusView(provider: "Perplexity", isConfigured: hasValidAPIKey(for: "perplexityApiKey"))
                }
            }
            .navigationTitle("Impostazioni")
        }
    }
    
    private func hasValidAPIKey(for key: String) -> Bool {
        return KeychainManager.shared.getAPIKey(for: key) != nil
    }
}

// MARK: - 10. Vista Status Provider

struct ProviderStatusView: View {
    let provider: String
    let isConfigured: Bool
    
    var body: some View {
        HStack {
            Text(provider)
            Spacer()
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isConfigured ? .green : .red)
        }
    }
}

// MARK: - 11. Servizio Chat Personalizzato

class CustomChatService: ObservableObject {
    @Published var messages: [ModularChatMessage] = []
    @Published var isProcessing = false
    @Published var error: String?
    
    private let chatService: ChatService
    
    init() {
        self.chatService = ChatService()
        setupObservers()
    }
    
    private func setupObservers() {
        // Osserva i cambiamenti del ChatService
        chatService.$messages
            .receive(on: DispatchQueue.main)
            .assign(to: &$messages)
        
        chatService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessing)
        
        chatService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }
    
    func sendMessage(_ text: String) async {
        await chatService.sendMessage(text)
    }
    
    func getStats() -> ConversationStats {
        return chatService.getConversationStats()
    }
}

// MARK: - 12. Vista Chat Personalizzata

struct CustomChatView: View {
    @StateObject private var chatService = CustomChatService()
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            // Lista messaggi
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatService.messages) { message in
                        MessageBubbleView(message: message)
                    }
                }
                .padding()
            }
            
            // Input messaggio
            HStack {
                TextField("Scrivi un messaggio...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Invia") {
                    Task {
                        await chatService.sendMessage(messageText)
                        messageText = ""
                    }
                }
                .disabled(messageText.isEmpty || chatService.isProcessing)
            }
            .padding()
        }
        .navigationTitle("Chat AI")
        .alert("Errore", isPresented: .constant(chatService.error != nil)) {
            Button("OK") {
                chatService.error = nil
            }
        } message: {
            Text(chatService.error ?? "")
        }
    }
}

// MARK: - 13. Vista Bolla Messaggio

struct MessageBubbleView: View {
    let message: ModularChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding()
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(12)
                
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
                    }
                }
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - 14. Test Unit

#if DEBUG
class ChatModuleTests: XCTestCase {
    var chatService: ChatService!
    
    override func setUp() {
        super.setUp()
        chatService = ChatService()
    }
    
    func testSendMessage() async {
        await chatService.sendMessage("Test message")
        XCTAssertEqual(chatService.messages.count, 2) // Messaggio utente + risposta AI
    }
    
    func testErrorHandling() {
        // Test gestione errori
        // Simula errore di rete
    }
}
#endif

// MARK: - 15. Info.plist Esempio

/*
Aggiungi queste chiavi al tuo Info.plist:

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
<key>NSSpeechRecognitionUsageDescription</key>
<string>L'app utilizza il riconoscimento vocale per trascrivere l'audio</string>
<key>NSMicrophoneUsageDescription</key>
<string>L'app utilizza il microfono per registrare l'audio</string>
*/

// MARK: - 16. Package Dependencies

/*
Aggiungi queste dipendenze al tuo Package.swift:

dependencies: [
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
]
*/

// MARK: - 17. Utilizzo Completo

/*
Per utilizzare il modulo chat nella tua app:

1. Copia tutti i file del modulo chat
2. Configura Core Data
3. Configura le API keys
4. Usa ModularChatView per la chat completa
5. Usa CustomChatView per una versione personalizzata

Esempio di utilizzo:

struct MyAppView: View {
    var body: some View {
        NavigationView {
            ChatListView()
        }
    }
}
*/

// MARK: - Fine Esempio 