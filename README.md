# 🎙️ Marilena - AI Voice Assistant

Marilena è un assistente vocale AI intelligente per iOS che combina registrazione audio avanzata, trascrizione in tempo reale e conversazioni intelligenti basate su contesto personalizzato.

## ✨ Caratteristiche Principali

### 🎯 **Contesto AI Avanzato**
- **Riassunto Intelligente**: Il sistema genera automaticamente un profilo comportamentale basato sulle tue conversazioni
- **Modifica Manuale**: Possibilità di modificare direttamente il contesto AI per personalizzare le risposte
- **Cronologia Completa**: Backup automatico di tutte le versioni del contesto (manuali e automatiche)
- **Aggiornamento Automatico**: Il contesto si aggiorna ogni 24 ore analizzando i nuovi messaggi

### 🎙️ **Registrazione Audio Professionale**
- **Interfaccia Moderna**: Design pulito con animazioni fluide e feedback visivo
- **Stati Visuali**: Indicatori di stato chiari con colori e animazioni appropriate
- **Controlli Intuitivi**: Pulsanti di registrazione con effetti pulsanti e highlight
- **Gestione Permessi**: Controllo intelligente dei permessi audio con pulsanti di configurazione

### 💬 **Chat AI Intelligente**
- **Conversazioni Naturali**: Chat fluide con l'AI basate sul tuo contesto personalizzato
- **Trascrizione Automatica**: Conversione automatica da audio a testo
- **Modelli Multiple**: Supporto per diversi modelli OpenAI (GPT-3.5, GPT-4)

### 👤 **Profilo Utente Completo**
- **Gestione Profilo**: Informazioni personali, bio, foto profilo
- **Profili Social**: Integrazione con i tuoi account social
- **Suggerimenti Intelligenti**: Consigli automatici per migliorare il profilo
- **Impostazioni Avanzate**: Controlli dettagliati per personalizzare l'esperienza

## 🚀 Tecnologie Utilizzate

- **SwiftUI**: Interface utente moderna e reattiva
- **Core Data**: Gestione dati locale con sincronizzazione CloudKit
- **AVFoundation**: Registrazione e riproduzione audio professionale
- **Speech Framework**: Trascrizione vocale in tempo reale
- **OpenAI API**: Integrazione con GPT per conversazioni intelligenti
- **Keychain Services**: Gestione sicura delle credenziali API

## 📱 Requisiti

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- Account OpenAI per l'API Key

## 🛠️ Installazione

1. **Clona il repository**
   ```bash
   git clone https://github.com/tuousername/marilena.git
   cd marilena
   ```

2. **Apri il progetto in Xcode**
   ```bash
   open Marilena.xcodeproj
   ```

3. **Configura l'API Key**
   - Vai in `SettingsView.swift`
   - Inserisci la tua OpenAI API Key nelle impostazioni dell'app

4. **Compila e Esegui**
   - Seleziona il tuo device/simulatore
   - Premi ⌘+R per compilare ed eseguire

## 🏗️ Architettura del Progetto

```
Marilena/
├── 📱 App Core
│   ├── MarilenaApp.swift         # Entry point dell'app
│   ├── ContentView.swift         # Vista principale con TabView
│   └── Persistence.swift         # Core Data stack
│
├── 🧠 AI & Context System
│   ├── ContestoAIService.swift       # Gestione automatica contesto
│   ├── ProfiloUtenteService.swift    # Gestione profilo e contesto
│   └── OpenAIService.swift           # Integrazione OpenAI API
│
├── 🎙️ Recording System
│   ├── AudioRecorderView.swift       # Interface registratore
│   ├── RecordingService.swift        # Logica registrazione audio
│   ├── RecordingsListView.swift      # Lista registrazioni
│   └── RecorderMainView.swift        # Vista principale registratore
│
├── 💬 Chat System
│   ├── ChatView.swift                # Interface chat AI
│   ├── ChatsListView.swift           # Lista conversazioni
│   └── TranscriptionChatView.swift   # Chat da trascrizioni
│
├── 👤 Profile System
│   ├── ProfiloView.swift              # Vista profilo utente
│   ├── ModificaProfiloView.swift      # Modifica dati profilo
│   └── SuggerimentiProfiloView.swift  # Suggerimenti miglioramento
│
├── 🔧 Utilities
│   ├── KeychainManager.swift          # Gestione credenziali sicure
│   ├── NotificationService.swift      # Notifiche push
│   └── SpeechTranscriptionService.swift # Trascrizione vocale
│
└── 📊 Data Model
    └── Marilena.xcdatamodeld/         # Modello Core Data
        ├── ProfiloUtente             # Entità profilo utente
        ├── ChatMarilena              # Entità conversazioni
        ├── MessaggioMarilena         # Entità messaggi chat
        ├── RegistrazioneAudio        # Entità registrazioni
        ├── Trascrizione              # Entità trascrizioni
        └── CronologiaContesto        # Entità cronologia contesto AI
```

## 🎯 Features in Dettaglio

### Sistema Contesto AI

Il cuore di Marilena è il suo sistema di contesto AI avanzato:

**Generazione Automatica**
- Analizza i messaggi dell'utente ogni 24 ore
- Crea un profilo comportamentale personalizzato
- Identifica preferenze, stili di comunicazione e interessi

**Modifica Manuale**
- Click-to-edit: tocca il contesto per modificarlo
- TextEditor completo con validazione
- Salvataggio automatico nella cronologia

**Sistema di Cronologia**
- Backup automatico di ogni modifica
- Distinzione tra aggiornamenti automatici e manuali
- Vista espandibile per confrontare versioni precedenti

### Interface Audio Avanzata

**Design Moderno**
- Gradient backgrounds dinamici
- Animazioni fluide con spring physics
- Feedback visivo in tempo reale

**Controlli Intelligenti**
- Pulsante di registrazione con anelli pulsanti
- Indicatori di stato con colori semantici
- Timer con display millisecondi

**Gestione Permessi**
- Controllo automatico permessi microfono
- Pulsante diretto per aprire Impostazioni iOS
- Feedback visivo dello stato dei permessi

## 🔧 Configurazione Avanzata

### OpenAI API Setup
1. Crea un account su [OpenAI Platform](https://platform.openai.com)
2. Genera una API Key
3. Nell'app: Profilo → Impostazioni → Inserisci API Key

### Core Data & CloudKit
- Sincronizzazione automatica tra dispositivi
- Backup offline completo
- Gestione conflitti automatica

### Personalizzazione UI
- Temi chiaro/scuro automatici
- Animazioni personalizzabili
- Layout responsive per tutti i device

## 🤝 Contribuire

1. Fork il progetto
2. Crea un branch feature (`git checkout -b feature/AmazingFeature`)
3. Commit le modifiche (`git commit -m 'Add some AmazingFeature'`)
4. Push al branch (`git push origin feature/AmazingFeature`)
5. Apri una Pull Request

## 📝 Licenza

Questo progetto è licenziato sotto la MIT License - vedi il file [LICENSE](LICENSE) per i dettagli.

## 🙏 Riconoscimenti

- **OpenAI** per l'API GPT
- **Apple** per i framework Speech e AVFoundation
- **SwiftUI Community** per l'ispirazione nel design

## 📞 Supporto

Per supporto e segnalazioni:
- 🐛 **Bug Reports**: [Issues](https://github.com/tuousername/marilena/issues)
- 💡 **Feature Requests**: [Discussions](https://github.com/tuousername/marilena/discussions)
- 📧 **Email**: mario@tuodominio.com

---

**Marilena** - Il tuo assistente AI personalizzato che ti ascolta e ti capisce davvero. 🎯✨ 