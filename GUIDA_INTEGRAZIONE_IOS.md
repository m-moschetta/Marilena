# Guida Integrazione Gateway LLM Multi-Provider per iOS

## 📋 Panoramica

Questa guida fornisce tutte le informazioni necessarie per integrare il gateway LLM multi-provider in un'app iOS. Il gateway supporta 4 provider AI: **OpenAI**, **Groq**, **Anthropic** e **Mistral**.

### 🔗 Endpoint Gateway
```
https://llm-proxy-gateway.mariomos94.workers.dev
```

## 🚀 Setup Rapido

### 1. Aggiungi il Client alla tua App

Copia i file `ModelCatalog.swift` e `ModelCatalogExample.swift` nel tuo progetto Xcode. Il sistema include:
- Gestione automatica dei provider
- Supporto streaming e non-streaming
- Gestione errori completa
- Modelli predefiniti per ogni provider

### 2. Inizializzazione Base

```swift
import Foundation

// Inizializza il client
let llmClient = LLMGatewayClient(
    baseURL: "https://llm-proxy-gateway.mariomos94.workers.dev"
)
```

### 3. Fallback/Forzatura via Cloudflare

- Se nelle impostazioni dell’app non sono state inserite API key per i provider (OpenAI, Anthropic, Groq), le chiamate vengono instradate automaticamente tramite il gateway Cloudflare: `https://llm-proxy-gateway.mariomos94.workers.dev`.
- Quando le API key sono configurate, l’app usa direttamente i provider ufficiali.
- Non è richiesta alcuna configurazione aggiuntiva lato iOS per il fallback; è già integrato nei servizi (`OpenAIService`, `GroqService`, `AnthropicService`).

Opzionale: puoi forzare l’uso del gateway anche quando le chiavi sono presenti, attivando il toggle “Forza uso Gateway Cloudflare” nelle Impostazioni → Instradamento.

Nota: il gateway è compatibile con l’API OpenAI `/v1/chat/completions` (anche in modalità `stream: true`) e seleziona il provider in base al modello richiesto.

### Streaming Fallback (senza API keys)

Con le chiavi mancanti, lo streaming è supportato via gateway. A livello codice è disponibile un helper già integrato:

```swift
// Fallback streaming quando non ci sono API keys
CloudflareGatewayClient.shared.streamChat(
    messages: [OpenAIMessage(role: "user", content: "Scrivi una poesia breve")],
    model: "llama-3.1-70b-versatile",
    onChunk: { delta in
        print(delta, terminator: "")
    },
    onComplete: {
        print("\nCompletato")
    },
    onError: { error in
        print("Errore: \(error.localizedDescription)")
    }
)
```

Se successivamente configuri le chiavi, l’app userà automaticamente i provider nativi, mantenendo le funzionalità di streaming dove supportate.

## 🤖 Provider e Modelli Supportati

### OpenAI
- **Modello predefinito**: `gpt-4o`
- **Modelli disponibili**: `gpt-4o`, `gpt-4o-mini`, `gpt-4-turbo`, `gpt-3.5-turbo`
- **Caratteristiche**: Eccellente per uso generale, ragionamento complesso

### Groq
- **Modello predefinito**: `llama-3.1-70b-versatile`
- **Modelli disponibili**: `llama-3.1-70b-versatile`, `llama-3.1-8b-instant`, `mixtral-8x7b-32768`
- **Caratteristiche**: Velocità elevata, ottimo per applicazioni real-time

### Anthropic (Claude)
- **Modello predefinito**: `claude-3-sonnet-20240229`
- **Modelli disponibili**: `claude-3-sonnet-20240229`, `claude-3-haiku-20240307`, `claude-3-opus-20240229`
- **Caratteristiche**: Eccellente per analisi, sicurezza, conversazioni lunghe

### Mistral
- **Modello predefinito**: `mistral-large-latest`
- **Modelli disponibili**: `mistral-large-latest`, `mistral-medium-latest`, `mistral-small-latest`
- **Caratteristiche**: Bilanciato, buone prestazioni multilingue

## 💻 Esempi di Implementazione

### Esempio 1: Chat Semplice con Provider Specifico

```swift
class ChatViewController: UIViewController {
    private let llmClient = LLMGatewayClient(
        baseURL: "https://llm-proxy-gateway.mariomos94.workers.dev"
    )
    
    func sendMessage(_ text: String, provider: AIProvider) {
        Task {
            do {
                let messages = [
                    ChatMessage(role: "user", content: text)
                ]
                
                let response = try await llmClient.sendChatCompletion(
                    messages: messages,
                    provider: provider
                )
                
                if let reply = response.choices.first?.message?.content {
                    DispatchQueue.main.async {
                        self.displayMessage(reply)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
}
```

### Esempio 2: Chat con Streaming

```swift
func sendStreamingMessage(_ text: String) {
    let messages = [
        ChatMessage(role: "user", content: text)
    ]
    
    llmClient.sendStreamingChatCompletion(
        messages: messages,
        provider: .groq, // Groq è ottimo per streaming veloce
        onChunk: { [weak self] chunk in
            DispatchQueue.main.async {
                self?.appendToCurrentMessage(chunk)
            }
        },
        onComplete: { [weak self] in
            DispatchQueue.main.async {
                self?.markMessageComplete()
            }
        },
        onError: { [weak self] error in
            DispatchQueue.main.async {
                self?.showError(error.localizedDescription)
            }
        }
    )
}
```

### Esempio 3: Selezione Dinamica del Provider

```swift
class ProviderSelectionView: UIView {
    @IBOutlet weak var providerPicker: UIPickerView!
    @IBOutlet weak var modelPicker: UIPickerView!
    
    private var selectedProvider: AIProvider = .openai
    private var selectedModel: String = ""
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupPickers()
    }
    
    private func setupPickers() {
        // Popola picker con tutti i provider
        let providers = AIProvider.allCases
        
        // Aggiorna modelli quando cambia provider
        selectedModel = selectedProvider.defaultModel
    }
    
    func sendMessageWithSelectedProvider(_ text: String) {
        let messages = [ChatMessage(role: "user", content: text)]
        
        Task {
            do {
                let response = try await llmClient.sendChatCompletion(
                    messages: messages,
                    provider: selectedProvider,
                    model: selectedModel
                )
                
                // Gestisci risposta...
            } catch {
                // Gestisci errore...
            }
        }
    }
}
```

### Esempio 4: Conversazione Multi-Turn

```swift
class ConversationManager {
    private let llmClient = LLMGatewayClient(
        baseURL: "https://llm-proxy-gateway.mariomos94.workers.dev"
    )
    private var conversationHistory: [ChatMessage] = []
    
    func addUserMessage(_ text: String) {
        conversationHistory.append(
            ChatMessage(role: "user", content: text)
        )
    }
    
    func getAIResponse(provider: AIProvider = .openai) async throws -> String {
        let response = try await llmClient.sendChatCompletion(
            messages: conversationHistory,
            provider: provider
        )
        
        if let aiReply = response.choices.first?.message?.content {
            // Aggiungi risposta AI alla cronologia
            conversationHistory.append(
                ChatMessage(role: "assistant", content: aiReply)
            )
            return aiReply
        }
        
        throw LLMError.invalidResponse
    }
    
    func clearConversation() {
        conversationHistory.removeAll()
    }
}
```

## 🔧 Configurazione Avanzata

### Politica di Cache dei Modelli

Il `ModelCatalog` implementa una cache intelligente per evitare chiamate API eccessive:

- **Cache Duration**: 24 ore (86400 secondi)
- **Aggiornamento Automatico**: Disabilitato per default
- **Refresh Manuale**: Disponibile con due modalità

```swift
// Refresh normale - rispetta la cache di 24 ore
await modelCatalog.refreshModels(for: .openai)

// Force refresh - ignora la cache (usare con parsimonia)
await modelCatalog.forceRefreshModels(for: .openai)

// Refresh di tutti i provider
await modelCatalog.refreshAllModels()
await modelCatalog.forceRefreshAllModels() // Force per tutti
```

**Raccomandazioni**:
- Usa il refresh normale nella maggior parte dei casi
- Il force refresh solo quando necessario (nuovi modelli rilasciati)
- Evita refresh automatici frequenti per rispettare i rate limits

### Gestione Errori Personalizzata

```swift
extension LLMError {
    var userFriendlyMessage: String {
        switch self {
        case .networkError:
            return "Problema di connessione. Verifica la tua connessione internet."
        case .httpError(let code):
            switch code {
            case 429:
                return "Troppe richieste. Riprova tra qualche secondo."
            case 500...599:
                return "Problema temporaneo del servizio. Riprova più tardi."
            default:
                return "Errore del servizio (\(code))"
            }
        case .invalidResponse:
            return "Risposta non valida dal servizio."
        default:
            return "Si è verificato un errore imprevisto."
        }
    }
}
```

### Timeout e Retry Logic

```swift
class RobustLLMClient {
    private let client: LLMGatewayClient
    private let maxRetries = 3
    private let timeoutInterval: TimeInterval = 30
    
    init(baseURL: String) {
        self.client = LLMGatewayClient(baseURL: baseURL)
    }
    
    func sendMessageWithRetry(
        messages: [ChatMessage],
        provider: AIProvider,
        attempt: Int = 1
    ) async throws -> ChatResponse {
        do {
            return try await client.sendChatCompletion(
                messages: messages,
                provider: provider
            )
        } catch {
            if attempt < maxRetries {
                // Attendi prima del retry
                try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                return try await sendMessageWithRetry(
                    messages: messages,
                    provider: provider,
                    attempt: attempt + 1
                )
            }
            throw error
        }
    }
}
```

## 📱 Integrazione UI

### SwiftUI Example

```swift
struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var selectedProvider: AIProvider = .openai
    @State private var isLoading = false
    
    private let llmClient = LLMGatewayClient(
        baseURL: "https://llm-proxy-gateway.mariomos94.workers.dev"
    )
    
    var body: some View {
        VStack {
            // Provider Selector
            Picker("Provider", selection: $selectedProvider) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Messages List
            ScrollView {
                LazyVStack {
                    ForEach(messages.indices, id: \.self) { index in
                        MessageBubble(message: messages[index])
                    }
                }
            }
            
            // Input Area
            HStack {
                TextField("Scrivi un messaggio...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Invia") {
                    sendMessage()
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
    }
    
    private func sendMessage() {
        let userMessage = ChatMessage(role: "user", content: inputText)
        messages.append(userMessage)
        
        let messageText = inputText
        inputText = ""
        isLoading = true
        
        Task {
            do {
                let response = try await llmClient.sendChatCompletion(
                    messages: [userMessage],
                    provider: selectedProvider
                )
                
                if let aiReply = response.choices.first?.message?.content {
                    DispatchQueue.main.async {
                        self.messages.append(
                            ChatMessage(role: "assistant", content: aiReply)
                        )
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    // Gestisci errore
                    self.isLoading = false
                }
            }
        }
    }
}
```

## 🔒 Sicurezza e Best Practices

### 1. Gestione Sicura delle Credenziali
- ✅ Il gateway gestisce tutte le API keys lato server
- ✅ Nessuna chiave API esposta nell'app iOS
- ✅ Comunicazione HTTPS end-to-end

### 2. Rate Limiting
```swift
class RateLimitedClient {
    private var lastRequestTime: Date = Date.distantPast
    private let minimumInterval: TimeInterval = 1.0 // 1 secondo tra richieste
    
    func sendMessage(_ text: String) async throws {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < minimumInterval {
            let waitTime = minimumInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
        // Procedi con la richiesta...
    }
}
```

### 3. Caching delle Risposte
```swift
class CachedLLMClient {
    private var responseCache: [String: ChatResponse] = [:]
    
    func getCachedResponse(for messages: [ChatMessage]) -> ChatResponse? {
        let key = messages.map { "\($0.role):\($0.content)" }.joined(separator: "|")
        return responseCache[key]
    }
    
    func cacheResponse(_ response: ChatResponse, for messages: [ChatMessage]) {
        let key = messages.map { "\($0.role):\($0.content)" }.joined(separator: "|")
        responseCache[key] = response
    }
}
```

## 🧪 Testing

### Unit Test Example
```swift
import XCTest
@testable import YourApp

class LLMClientTests: XCTestCase {
    var client: LLMGatewayClient!
    
    override func setUp() {
        super.setUp()
        client = LLMGatewayClient(
            baseURL: "https://llm-proxy-gateway.mariomos94.workers.dev"
        )
    }
    
    func testOpenAIProvider() async throws {
        let messages = [
            ChatMessage(role: "user", content: "Test message")
        ]
        
        let response = try await client.sendChatCompletion(
            messages: messages,
            provider: .openai
        )
        
        XCTAssertFalse(response.choices.isEmpty)
        XCTAssertNotNil(response.choices.first?.message?.content)
    }
    
    func testProviderDetection() {
        let provider = client.getProviderForModel("gpt-4o")
        XCTAssertEqual(provider, .openai)
        
        let claudeProvider = client.getProviderForModel("claude-3-sonnet-20240229")
        XCTAssertEqual(claudeProvider, .anthropic)
    }
}
```

## 📊 Monitoraggio e Analytics

### Tracking Usage
```swift
class AnalyticsLLMClient {
    private let client: LLMGatewayClient
    
    func sendMessageWithAnalytics(
        messages: [ChatMessage],
        provider: AIProvider
    ) async throws -> ChatResponse {
        let startTime = Date()
        
        do {
            let response = try await client.sendChatCompletion(
                messages: messages,
                provider: provider
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Log success metrics
            Analytics.track("llm_request_success", properties: [
                "provider": provider.rawValue,
                "duration": duration,
                "tokens_used": response.usage?.totalTokens ?? 0
            ])
            
            return response
        } catch {
            // Log error metrics
            Analytics.track("llm_request_error", properties: [
                "provider": provider.rawValue,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
}
```

## 🚨 Troubleshooting

### Problemi Comuni

1. **Errore 502/503**: Il provider potrebbe essere temporaneamente non disponibile
   - **Soluzione**: Implementa retry logic o fallback ad altro provider

2. **Timeout**: Richieste troppo lunghe
   - **Soluzione**: Usa streaming per risposte lunghe

3. **Rate Limiting**: Troppe richieste
   - **Soluzione**: Implementa debouncing e rate limiting client-side

### Debug Mode
```swift
#if DEBUG
class DebugLLMClient: LLMGatewayClient {
    override func sendChatCompletion(
        messages: [ChatMessage],
        model: String,
        maxTokens: Int?,
        temperature: Double?
    ) async throws -> ChatResponse {
        print("🚀 Sending request to model: \(model)")
        print("📝 Messages: \(messages)")
        
        let response = try await super.sendChatCompletion(
            messages: messages,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature
        )
        
        print("✅ Response received: \(response.choices.count) choices")
        return response
    }
}
#endif
```

## 📞 Supporto

- **Gateway URL**: `https://llm-proxy-gateway.mariomos94.workers.dev`
- **Documentazione API**: Compatibile con OpenAI API v1
- **Codice sorgente**: Disponibile nel repository del progetto

---

**Nota**: Questa guida copre tutti gli aspetti dell'integrazione. Per implementazioni specifiche o problemi, consulta il codice di esempio fornito nei file `ModelCatalog.swift` e `ModelCatalogExample.swift`.
