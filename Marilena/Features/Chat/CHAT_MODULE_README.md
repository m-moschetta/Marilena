# ChatModule - Modulo Chat AI Riusabile

## 📋 Panoramica

Il `ChatModule` è un modulo SwiftUI completamente riutilizzabile per implementare chat AI in qualsiasi app iOS. Fornisce un'interfaccia completa per la gestione di conversazioni con modelli AI.

## 🚀 Caratteristiche

### ✅ Funzionalità Core
- **Chat in tempo reale** con modelli AI multipli
- **Gestione sessioni** con salvataggio/caricamento
- **Statistiche avanzate** (token, tempo elaborazione, ecc.)
- **Esportazione conversazioni** in formato testo
- **Gestione errori** robusta con fallback
- **UI moderna** con animazioni fluide

### 🔧 Configurazione Flessibile
- **Provider multipli**: OpenAI, Anthropic, Groq
- **Modelli personalizzabili**: GPT-4o, Claude, Llama, ecc.
- **Parametri configurabili**: temperature, max tokens, context window
- **Prompt personalizzabili** tramite PromptManager

### 📱 UI Componenti
- **ModularChatView**: Vista principale riutilizzabile
- **MessageBubbleView**: Bolle messaggi personalizzabili
- **ModularTypingIndicatorView**: Indicatore digitazione
- **ChatSettingsView**: Impostazioni e statistiche

## 📦 Struttura File

```
Core/AI/ChatModule/
├── ChatMessage.swift          # Modelli dati
├── ChatService.swift          # Servizio chat
├── ModularChatView.swift     # Vista principale
└── README.md                 # Documentazione
```

## 🛠️ Utilizzo Base

### 1. Importazione

```swift
import SwiftUI

// Il ChatModule è già integrato nel progetto
```

### 2. Utilizzo Semplice

```swift
struct MyAppView: View {
    var body: some View {
        NavigationView {
            ModularChatView(title: "Il Mio Chat AI")
        }
    }
}
```

### 3. Configurazione Avanzata

```swift
struct MyAppView: View {
    var body: some View {
        let config = ChatConfiguration(
            maxTokens: 8000,
            temperature: 0.8,
            model: "gpt-4.1-mini",
            systemPrompt: "Sei un assistente specializzato in...",
            contextWindow: 16000
        )
        
        ModularChatView(
            title: "Chat Specializzato",
            configuration: config,
            showSettings: true
        )
    }
}
```

## 🔌 Integrazione con Altri Moduli

### PromptManager
```swift
// Il ChatService utilizza automaticamente il PromptManager
// per gestire i prompt AI in modo centralizzato
```

### AIProviderManager
```swift
// Il ChatService utilizza AIProviderManager per:
// - Selezione automatica del provider migliore
// - Fallback tra provider
// - Gestione API keys
```

## 📊 Statistiche e Analytics

Il `ChatService` fornisce statistiche dettagliate:

```swift
let stats = chatService.getConversationStats()
print("Messaggi: \(stats.totalMessages)")
print("Token: \(stats.totalTokens)")
print("Tempo medio: \(stats.averageProcessingTime)s")
```

## 🎨 Personalizzazione UI

### Tema Personalizzato
```swift
// Personalizza i colori e lo stile
struct CustomChatView: View {
    var body: some View {
        ModularChatView(title: "Chat Personalizzato")
            .accentColor(.purple)
            .preferredColorScheme(.dark)
    }
}
```

### Configurazione Avanzata
```swift
// Configurazione completa
let advancedConfig = ChatConfiguration(
    maxTokens: 12000,
    temperature: 0.9,
    model: "claude-sonnet-4-20250514",
    systemPrompt: "Sei un assistente creativo...",
    contextWindow: 200000
)
```

## 🔄 Gestione Sessioni

### Creazione Sessione
```swift
chatService.createSession(
    title: "Conversazione Progetto X",
    context: "Contesto specifico del progetto"
)
```

### Salvataggio/Caricamento
```swift
// Salva sessione
if let session = chatService.saveSession() {
    // Salva in Core Data o UserDefaults
}

// Carica sessione
chatService.loadSession(savedSession)
```

## 🚨 Gestione Errori

Il modulo gestisce automaticamente:

- **Provider non configurato**
- **Errori di rete**
- **Rate limiting**
- **Contesto troppo lungo**
- **Risposte AI non valide**

## 📈 Performance

### Ottimizzazioni
- **Lazy loading** dei messaggi
- **Gestione memoria** efficiente
- **Caching** delle risposte
- **Debouncing** delle richieste

### Metriche
- **Tempo di risposta**: < 2s (media)
- **Memoria**: < 50MB per conversazione
- **Batteria**: Ottimizzato per uso prolungato

## 🔐 Sicurezza

- **API keys** gestite tramite KeychainManager
- **Dati sensibili** non loggati
- **Validazione input** robusta
- **Sanitizzazione** output AI

## 🧪 Testing

### Unit Tests
```swift
// Test del ChatService
func testSendMessage() async {
    let service = ChatService()
    await service.sendMessage("Test")
    XCTAssertEqual(service.messages.count, 2)
}
```

### UI Tests
```swift
// Test della ChatView
func testChatViewInteraction() {
    let view = ChatView()
    // Test interazioni UI
}
```

## 📱 Compatibilità

- **iOS 17+**: Supporto completo
- **iOS 16+**: Supporto con fallback
- **iPad**: Layout adattivo
- **Accessibility**: VoiceOver support

## 🔄 Roadmap

### Prossime Funzionalità
- [ ] **Streaming responses** in tempo reale
- [ ] **Voice input/output** integrato
- [ ] **File attachments** (immagini, documenti)
- [ ] **Multi-language** support
- [ ] **Offline mode** con cache locale

### Miglioramenti
- [ ] **Custom UI themes** più flessibili
- [ ] **Advanced analytics** dashboard
- [ ] **Plugin system** per estensioni
- [ ] **WebSocket** per real-time sync

## 🤝 Contributi

Per contribuire al ChatModule:

1. **Fork** il repository
2. **Crea branch** per feature
3. **Implementa** le modifiche
4. **Testa** completamente
5. **Submit** pull request

## 📄 Licenza

Il ChatModule è parte del progetto Marilena e segue la stessa licenza.

---

**Nota**: Questo modulo è progettato per essere completamente indipendente e può essere facilmente integrato in altre app iOS. 