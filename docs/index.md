# Marilena – Documentazione Progetto

Benvenuto nella documentazione ufficiale di Marilena, l’assistente AI personale per iOS!

---

## 🚀 Introduzione
Marilena è un’app iOS che integra registrazione audio avanzata, trascrizione automatica, chat AI multimodello e ricerca online. Il progetto è pensato per essere facilmente estendibile sia da sviluppatori umani che da AI.

---

## 🏗️ Architettura
- **SwiftUI** per l’interfaccia utente modulare e reattiva
- **Core Data** per la persistenza di registrazioni e trascrizioni
- **AIProviderManager** per la selezione dinamica dei provider AI (OpenAI, Anthropic, Groq, Perplexity)
- **SpeechTranscriptionService** per la trascrizione audio (SpeechAnalyzer iOS 26+, Speech Framework, Whisper API)
- **PromptManager** per la gestione centralizzata dei prompt AI

---

## 🧠 Tecnologie Moderne
- **iOS 26+**: SpeechAnalyzer, GlassEffectContainer, compatibilità avanzata
- **OpenAI GPT-4.1, o3, o3 mini, o4 mini**: modelli AI di ultima generazione
- **Anthropic Claude**: modelli Opus 4, Sonnet 4, ecc.
- **Perplexity**: ricerca online, modelli Sonar, Llama, Mixtral
- **Groq**: supporto per modelli open-source (Llama 3, Mixtral)

---

## ❓ FAQ
- **Serve una API key?** Sì, per le funzioni AI avanzate (chat, trascrizione cloud, ricerca online).
- **Come cambio modello AI?** Da Impostazioni, scegli provider e modello. Il limite token si aggiorna in automatico.
- **Come faccio una ricerca online?** Premi il mappamondo nella chat AI.
- **L’app è pronta per iOS 26?** Sì, già compatibile e aggiornata.
- **Posso contribuire?** Sì! Segui la guida qui sotto.

---

## 🤝 Guida Rapida Contributor
1. Clona il repo: `git clone https://github.com/m-moschetta/Marilena.git`
2. Apri in Xcode: `open Marilena.xcodeproj`
3. Configura le API key nelle impostazioni app
4. Crea un branch: `git checkout -b feature/il-tuo-nome-feature`
5. Sviluppa, commenta, aggiorna la documentazione
6. Commit e push: `git add . && git commit -m "feature" && git push origin feature/il-tuo-nome-feature`
7. Apri una Pull Request

---

## 📊 Flusso Architetturale
```mermaid
graph TD;
    A[Utente preme "Registra"] --> B[AudioRecorderView avvia registrazione]
    B --> C[RecordingService salva audio in Core Data]
    C --> D[SpeechTranscriptionService avvia trascrizione]
    D -->|iOS 26+| E[SpeechAnalyzer]
    D -->|iOS 13-25| F[Speech Framework]
    D -->|API| G[Whisper/OpenAI]
    E & F & G --> H[Trascrizione salvata in Core Data]
    H --> I[UI aggiornata automaticamente con @FetchRequest]
    I --> J[L’utente può avviare chat AI sulla trascrizione]
    J --> K[AIProviderManager seleziona provider migliore]
    K --> L[OpenAIService/AnthropicService/PerplexityService/GroqService]
    L --> M[Risposta AI mostrata in ChatView]
```

---

Per dettagli, esempi di codice e approfondimenti consulta il [README](../README.md) o apri una issue! 