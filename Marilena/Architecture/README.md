# 🏗️ Architettura Refactoring per iPad

## Panoramica

Questo refactoring separa completamente la logica dall'interfaccia, permettendo di creare interfacce diverse per iPhone e iPad mantenendo la stessa struttura dati e logica di business.

## 🎯 Obiettivi

1. **Separazione Logica-Interfaccia**: La logica è completamente separata dall'interfaccia
2. **Riutilizzabilità**: Gli stessi ViewModel possono essere usati per interfacce diverse
3. **Adattabilità**: L'app si adatta automaticamente a iPhone e iPad
4. **Manutenibilità**: Codice più pulito e facile da mantenere
5. **Estendibilità**: Facile aggiungere nuove interfacce (macOS, watchOS, etc.)

## 📁 Struttura Architetturale

### Core Components

```
Marilena/Architecture/
├── AppCoordinator.swift          # Gestione navigazione e stato
├── ViewProtocols.swift           # Protocolli per standardizzare le viste
├── BaseViewModel.swift           # ViewModel base con implementazioni comuni
├── DeviceAdapter.swift           # Adattamento per diversi dispositivi
├── IPadLayouts.swift            # Layout specifici per iPad
└── README.md                    # Questa documentazione
```

## 🔧 Componenti Principali

### 1. AppCoordinator
- **Ruolo**: Gestisce la navigazione e lo stato dell'app
- **Responsabilità**: 
  - Routing tra le diverse viste
  - Gestione dello stato globale
  - Coordinamento tra servizi
  - Gestione errori centralizzata

### 2. ViewProtocols
- **Ruolo**: Standardizza le interfacce delle viste
- **Protocolli Principali**:
  - `BaseViewProtocol`: Base per tutte le viste
  - `ListViewProtocol`: Per liste di elementi
  - `DetailViewProtocol`: Per viste di dettaglio
  - `ChatViewProtocol`: Per interfacce chat
  - `RecordingViewProtocol`: Per registrazione audio
  - `ErrorHandlingProtocol`: Gestione errori
  - `LoadingProtocol`: Stati di caricamento

### 3. BaseViewModel
- **Ruolo**: ViewModel base con implementazioni comuni
- **Funzionalità**:
  - Gestione errori
  - Stati di caricamento
  - Validazione dati
  - Formattazione
  - Logging
  - Persistenza dati

### 4. DeviceAdapter
- **Ruolo**: Adatta l'interfaccia per diversi dispositivi
- **Funzionalità**:
  - Rilevamento dispositivo (iPhone/iPad/mac)
  - Dimensioni adattive
  - Spacing adattivo
  - Font adattivi
  - Animazioni adattive

### 5. IPadLayouts
- **Ruolo**: Layout specifici per iPad
- **Layout Disponibili**:
  - `IPadSplitView`: Vista divisa
  - `IPadThreeColumnLayout`: Layout a tre colonne
  - `IPadAdaptiveNavigationLayout`: Navigazione adattiva
  - `IPadGridLayout`: Griglia adattiva
  - `IPadAdaptiveListLayout`: Lista adattiva

## 🎨 Pattern Architetturali

### MVVM + Coordinator
```
View → ViewModel → Coordinator → Services
```

### Dependency Injection
- I ViewModel ricevono le dipendenze tramite inizializzatore
- I servizi sono iniettati tramite Coordinator
- Le viste ricevono i ViewModel tramite EnvironmentObject

### Protocol-Oriented Programming
- Tutte le viste implementano protocolli standard
- Facilita il testing e la riutilizzabilità
- Permette implementazioni diverse per lo stesso protocollo

## 📱 Adattamento Dispositivo

### iPhone Layout
- TabView con navigazione stack
- Interfaccia compatta
- Animazioni veloci
- Haptic feedback medio

### iPad Layout
- SplitView con sidebar
- Interfaccia espansa
- Animazioni più lente
- Haptic feedback leggero
- Layout a colonne multiple

## 🔄 Flusso Dati

```
User Action → View → ViewModel → Coordinator → Service → Core Data
     ↑                                                           ↓
     ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
```

## 🧪 Testing

### ViewModel Testing
```swift
class ChatViewModelTests: XCTestCase {
    var viewModel: ChatViewModel!
    var mockCoordinator: MockAppCoordinator!
    
    override func setUp() {
        mockCoordinator = MockAppCoordinator()
        viewModel = ChatViewModel(chat: mockChat, context: mockContext, coordinator: mockCoordinator)
    }
    
    func testSendMessage() {
        viewModel.messageText = "Test message"
        viewModel.sendMessage()
        
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertTrue(mockCoordinator.didCallSendMessage)
    }
}
```

### Protocol Testing
```swift
class MockChatView: ChatViewProtocol {
    var coordinator: AppCoordinator
    var messages: [ChatMessage] = []
    var isLoading: Bool = false
    var messageText: String = ""
    
    func sendMessage() { /* Mock implementation */ }
    func searchWithPerplexity() { /* Mock implementation */ }
    func selectModel(_ model: String) { /* Mock implementation */ }
}
```

## 🚀 Implementazione

### 1. Creare un nuovo ViewModel
```swift
class MyViewModel: BaseViewModel {
    @Published var items: [MyItem] = []
    
    override func loadData() {
        // Implementazione specifica
    }
}
```

### 2. Creare una nuova vista
```swift
struct MyView: BaseViewProtocol {
    @StateObject var viewModel: MyViewModel
    var coordinator: AppCoordinator { viewModel.coordinator }
    
    var body: some View {
        IPadAdaptiveListLayout {
            ForEach(viewModel.items) { item in
                MyItemRow(item: item)
            }
        }
        .adaptive()
    }
}
```

### 3. Aggiungere al Coordinator
```swift
// In AppCoordinator
func openMyView() {
    navigate(to: .myView)
}

// In AppRoute
case myView
```

## 📊 Vantaggi

### Per lo Sviluppatore
- **Codice più pulito**: Separazione chiara delle responsabilità
- **Testing più facile**: ViewModel testabili indipendentemente
- **Riutilizzabilità**: Stessa logica per interfacce diverse
- **Manutenibilità**: Modifiche localizzate

### Per l'Utente
- **Interfaccia ottimizzata**: Adattata al dispositivo
- **Performance migliore**: Logica ottimizzata
- **UX consistente**: Comportamento prevedibile
- **Accessibilità**: Supporto nativo per accessibility

## 🔮 Estensioni Future

### macOS Support
```swift
// In DeviceAdapter
case mac
// Implementare layout specifici per macOS
```

### watchOS Support
```swift
// In DeviceAdapter
case watch
// Implementare layout specifici per watchOS
```

### tvOS Support
```swift
// In DeviceAdapter
case tv
// Implementare layout specifici per tvOS
```

## 🛠️ Best Practices

### 1. Sempre usare i protocolli
```swift
// ✅ Corretto
struct MyView: BaseViewProtocol {
    var coordinator: AppCoordinator { viewModel.coordinator }
}

// ❌ Sbagliato
struct MyView: View {
    @StateObject var coordinator: AppCoordinator
}
```

### 2. Usare i layout adattivi
```swift
// ✅ Corretto
IPadAdaptiveListLayout {
    // Content
}

// ❌ Sbagliato
List {
    // Content
}
```

### 3. Gestire gli errori centralmente
```swift
// ✅ Corretto
viewModel.showError("Errore specifico")

// ❌ Sbagliato
// Gestione errori dispersa nelle viste
```

### 4. Usare il DeviceAdapter
```swift
// ✅ Corretto
.adaptive()
.adaptiveButton()
.adaptiveCard()

// ❌ Sbagliato
.padding(16)
.cornerRadius(12)
```

## 📝 Note di Implementazione

### Migrazione Graduale
1. Implementare l'architettura per nuove funzionalità
2. Migrare le viste esistenti una alla volta
3. Testare ogni migrazione
4. Rimuovere il codice legacy

### Performance
- I ViewModel sono `@MainActor` per performance ottimali
- Uso di `Combine` per reattività
- Caching intelligente dei dati

### Sicurezza
- Validazione input centralizzata
- Sanitizzazione dati
- Gestione sicura delle API keys

## 🎯 Prossimi Passi

1. **Implementare ViewModel per tutte le viste esistenti**
2. **Creare layout iPad specifici per ogni sezione**
3. **Aggiungere test per tutti i ViewModel**
4. **Ottimizzare performance per iPad**
5. **Implementare supporto per macOS**

---

*Questa architettura permette di mantenere la stessa logica e struttura dati mentre si creano interfacce completamente diverse per iPhone e iPad.* 