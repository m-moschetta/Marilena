# TranscriptionModule - Modulo Trascrizione Audio Riusabile

## 📋 Panoramica

Il `TranscriptionModule` è un modulo SwiftUI completamente riutilizzabile per implementare funzionalità di trascrizione audio in qualsiasi app iOS. Fornisce un'interfaccia completa per la conversione di audio in testo utilizzando diversi framework.

## 🚀 Caratteristiche

### ✅ Funzionalità Core
- **Trascrizione audio** con framework multipli
- **Supporto multi-lingua** (italiano, inglese, spagnolo, francese, tedesco, portoghese)
- **Framework multipli**: Speech Analyzer (iOS 26+), Speech Framework (iOS 13+), Whisper API
- **Gestione sessioni** con salvataggio/caricamento
- **Statistiche avanzate** (tempo elaborazione, confidenza, parole, ecc.)
- **Gestione errori** robusta con fallback
- **UI moderna** con animazioni fluide

### 🔧 Configurazione Flessibile
- **Modalità multiple**: Auto, Speech Analyzer, Speech Framework, Whisper, Locale
- **Lingue supportate**: 6 lingue principali
- **Parametri configurabili**: timestamp, confidenza, segmenti
- **Timeout personalizzabili** per elaborazione lunga
- **Retry automatico** in caso di errori

### 📱 UI Componenti
- **ModularTranscriptionView**: Vista principale riutilizzabile
- **ModularTranscriptionResultView**: Visualizzazione risultati
- **ModularTranscriptionVolatileView**: Testo in tempo reale
- **ModularTranscriptionModeSelectionView**: Selezione modalità
- **ModularTranscriptionSettingsView**: Impostazioni e statistiche

## 📦 Struttura File

```
Core/AI/TranscriptionModule/
├── TranscriptionMessage.swift          # Modelli dati
├── ModularTranscriptionService.swift  # Servizio trascrizione
├── ModularTranscriptionView.swift     # Vista principale
└── README.md                          # Documentazione
```

## 🛠️ Utilizzo Base

### 1. Importazione

```swift
import SwiftUI

// Il TranscriptionModule è già integrato nel progetto
```

### 2. Utilizzo Semplice

```swift
struct MyAppView: View {
    var body: some View {
        NavigationView {
            ModularTranscriptionView(title: "Il Mio Trascrittore")
        }
    }
}
```

### 3. Configurazione Avanzata

```swift
let configuration = ModularTranscriptionConfiguration(
    mode: .auto,
    language: "it-IT",
    enableTimestamps: true,
    enableConfidence: true,
    enableSegments: true,
    maxProcessingTime: 300.0,
    retryCount: 3
)

ModularTranscriptionView(
    title: "Trascrizione Avanzata",
    configuration: configuration,
    showSettings: true
)
```

## 🎯 Framework Supportati

### Speech Analyzer (iOS 26+)
- **Vantaggi**: Framework più avanzato, migliore accuratezza
- **Caratteristiche**: Analisi in tempo reale, supporto multilingua avanzato
- **Fallback**: Automatico a Speech Framework se non disponibile

### Speech Framework (iOS 13+)
- **Vantaggi**: Supporto universale, stabile
- **Caratteristiche**: Riconoscimento offline, API consolidate
- **Compatibilità**: iOS 13+ con fallback automatico

### Whisper API (OpenAI)
- **Vantaggi**: Alta accuratezza, supporto lingue esteso
- **Caratteristiche**: Elaborazione cloud, modelli avanzati
- **Requisiti**: Connessione internet, API key OpenAI

## 📊 Modelli Dati

### ModularTranscriptionResult
```swift
public struct ModularTranscriptionResult {
    public let text: String                    // Testo trascritto
    public let confidence: Double              // Confidenza (0-1)
    public let timestamps: [TimeInterval: String] // Timestamp per segmenti
    public let detectedLanguage: String        // Lingua rilevata
    public let wordCount: Int                  // Numero parole
    public let framework: ModularTranscriptionFramework // Framework usato
    public let processingTime: TimeInterval    // Tempo elaborazione
    public let segments: [ModularTranscriptionSegment] // Segmenti dettagliati
}
```

### ModularTranscriptionConfiguration
```swift
public struct ModularTranscriptionConfiguration {
    public let mode: ModularTranscriptionMode  // Modalità trascrizione
    public let language: String                // Lingua target
    public let enableTimestamps: Bool          // Abilita timestamp
    public let enableConfidence: Bool          // Abilita confidenza
    public let enableSegments: Bool            // Abilita segmenti
    public let maxProcessingTime: TimeInterval // Timeout massimo
    public let retryCount: Int                 // Tentativi retry
}
```

## 🔧 Integrazione

### 1. Aggiunta al Progetto

Il modulo è già integrato nel progetto Marilena. Per usarlo in altre app:

1. Copia la cartella `Core/AI/TranscriptionModule/`
2. Aggiungi le dipendenze necessarie:
   - `Speech.framework`
   - `AVFoundation.framework`
   - `NaturalLanguage.framework`

### 2. Permessi Richiesti

Aggiungi al `Info.plist`:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>L'app utilizza il riconoscimento vocale per trascrivere audio</string>
<key>NSMicrophoneUsageDescription</key>
<string>L'app utilizza il microfono per registrare audio</string>
```

### 3. Gestione Errori

```swift
enum ModularTranscriptionError: Error, LocalizedError {
    case permissionDenied
    case audioFileNotFound
    case unsupportedAudioFormat
    case frameworkUnavailable
    case processingTimeout
    case networkError(Error)
    case transcriptionFailed(String)
    case invalidConfiguration
}
```

## 📈 Statistiche e Monitoraggio

### ModularTranscriptionStats
```swift
public struct ModularTranscriptionStats {
    public let totalSessions: Int
    public let successfulTranscriptions: Int
    public let averageProcessingTime: TimeInterval
    public let averageConfidence: Double
    public let mostUsedFramework: ModularTranscriptionFramework
    public let totalWords: Int
    public let averageWordsPerSession: Int
}
```

### Accesso Statistiche
```swift
let stats = transcriptionService.getStats()
print("Sessioni totali: \(stats.totalSessions)")
print("Tempo medio: \(stats.averageProcessingTime)s")
```

## 🎨 Personalizzazione UI

### Tema Colori
```swift
// Personalizza colori framework
extension ModularTranscriptionFramework {
    public var color: String {
        switch self {
        case .speechAnalyzer: return "purple"
        case .speechFramework: return "orange"
        case .whisperAPI: return "green"
        case .unavailable: return "gray"
        }
    }
}
```

### Icone Modalità
```swift
extension ModularTranscriptionMode {
    public var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .speechAnalyzer: return "brain.head.profile"
        case .speechFramework: return "waveform"
        case .whisper: return "cloud"
        case .local: return "device.phone.portrait"
        }
    }
}
```

## 🔄 Gestione Stato

### Stati Trascrizione
```swift
public enum ModularTranscriptionState {
    case idle           // In attesa
    case processing     // In elaborazione
    case completed      // Completata
    case error(Error)   // Errore
}
```

### Monitoraggio Progresso
```swift
@Published public var currentProgress: Double = 0.0
@Published public var volatileText: String = ""
@Published public var finalizedText: String = ""
```

## 🚀 Roadmap

### ✅ Completato
- [x] Modelli dati modulari
- [x] Servizio trascrizione riutilizzabile
- [x] Vista principale con UI moderna
- [x] Supporto framework multipli
- [x] Gestione errori robusta
- [x] Statistiche avanzate
- [x] Documentazione completa

### 🔄 In Sviluppo
- [ ] Integrazione Whisper API completa
- [ ] Supporto Speech Analyzer iOS 26+
- [ ] Esportazione risultati in formati multipli
- [ ] Batch processing per file multipli
- [ ] Integrazione con Core Data per persistenza

### 📋 Pianificato
- [ ] Supporto lingue aggiuntive
- [ ] Trascrizione in tempo reale
- [ ] Analisi sentiment del testo trascritto
- [ ] Integrazione con moduli AI per analisi avanzata
- [ ] Widget per trascrizioni rapide
- [ ] Sincronizzazione iCloud

## 🐛 Risoluzione Problemi

### Errori Comuni

1. **Permessi negati**
   - Verifica `NSSpeechRecognitionUsageDescription` in Info.plist
   - Richiedi permessi manualmente: `transcriptionService.requestPermissions()`

2. **Framework non disponibile**
   - Verifica versione iOS (Speech Framework richiede iOS 13+)
   - Controlla disponibilità: `SFSpeechRecognizer.isAvailable`

3. **Formato audio non supportato**
   - Usa formati: AAC, PCM, Apple Lossless
   - Verifica file: `AVAudioFile(forReading: url)`

4. **Timeout elaborazione**
   - Aumenta `maxProcessingTime` nella configurazione
   - Verifica connessione per Whisper API

### Debug

```swift
// Abilita log dettagliati
print("🎤 Framework selezionato: \(frameworkDescription)")
print("🎤 Permessi: \(isPermissionGranted)")
print("🎤 Stato sessione: \(currentSession?.state)")
```

## 📚 Esempi Avanzati

### Trascrizione Batch
```swift
func transcribeMultipleFiles(_ urls: [URL]) async {
    for url in urls {
        do {
            let result = try await transcriptionService.transcribeAudio(
                url: url,
                configuration: ModularTranscriptionConfiguration()
            )
            print("✅ Trascritto: \(url.lastPathComponent)")
        } catch {
            print("❌ Errore: \(error)")
        }
    }
}
```

### Configurazione Personalizzata
```swift
let customConfig = ModularTranscriptionConfiguration(
    mode: .speechAnalyzer,
    language: "en-US",
    enableTimestamps: true,
    enableConfidence: true,
    enableSegments: true,
    maxProcessingTime: 600.0, // 10 minuti
    retryCount: 5
)
```

### Integrazione con Chat
```swift
// Dopo trascrizione, invia a chat AI
if let result = transcriptionResult {
    await chatService.sendMessage(
        "Analizza questa trascrizione: \(result.text)"
    )
}
```

## 🤝 Contributi

Il modulo è progettato per essere facilmente estendibile:

1. **Nuovi Framework**: Aggiungi enum e implementazione
2. **Nuove Lingue**: Estendi array lingue supportate
3. **Nuove UI**: Crea viste personalizzate
4. **Nuove Funzionalità**: Estendi servizio e modelli

## 📄 Licenza

Questo modulo è parte del progetto Marilena e segue le stesse licenze del progetto principale. 