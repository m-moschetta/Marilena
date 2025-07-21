# Marilena – Documentazione Tecnica e Architetturale

## Indice
1. [Panoramica](#panoramica)
2. [Architettura Generale](#architettura-generale)
3. [Tecnologie Utilizzate](#tecnologie-utilizzate)
4. [Logiche Principali](#logiche-principali)
5. [Dettagli sulle Integrazioni Moderne](#dettagli-sulle-integrazioni-moderne)
    - [iOS 26 e Speech Framework](#ios-26-e-speech-framework)
    - [Modelli AI OpenAI, Anthropic, Perplexity, Groq](#modelli-ai-openai-anthropic-perplexity-groq)
6. [Gestione Stato, Persistenza e Core Data](#gestione-stato-persistenza-e-core-data)
7. [Estendibilità e Notepad per Sviluppi Futuri](#estendibilita-e-notepad-per-sviluppi-futuri)
8. [Collaborazione e Contributi](#collaborazione-e-contributi)
9. [Risorse e Link Utili](#risorse-e-link-utili)

---

## 1. Panoramica
Marilena è un assistente AI personale per iOS, focalizzato su trascrizione audio, analisi, chat AI multimodello e ricerca online. L’app integra le tecnologie più moderne (iOS 26, SpeechAnalyzer, modelli AI di ultima generazione) e offre un’architettura modulare, facilmente estendibile sia da sviluppatori umani che da AI.

---

## 2. Architettura Generale
- **SwiftUI** per l’interfaccia utente, con viste modulari e reactive.
- **Core Data** per la persistenza di registrazioni e trascrizioni.
- **AIProviderManager**: gestisce la selezione dinamica dei provider AI (OpenAI, Anthropic, Groq, Perplexity) in base alle API key e alle preferenze utente.
- **Servizi AI separati**: ogni provider ha un proprio service (`OpenAIService`, `AnthropicService`, `PerplexityService`, ecc.) con logica di fallback e gestione errori.
- **SpeechTranscriptionService**: gestisce la trascrizione audio, selezionando automaticamente il miglior framework disponibile (SpeechAnalyzer iOS 26+, Speech Framework, Whisper API, ecc.).
- **PromptManager**: centralizza tutti i prompt AI, facilitando la personalizzazione e l’estensione.

---

## 3. Tecnologie Utilizzate
- **iOS 18+**: compatibilità garantita, con supporto avanzato per iOS 26 (SpeechAnalyzer, GlassEffectContainer, ecc.).
- **Speech Framework**: trascrizione audio locale, fallback automatico se SpeechAnalyzer non disponibile.
- **SpeechAnalyzer (iOS 26+)**: trascrizione avanzata, segmentazione, analisi semantica e temporale.
- **OpenAI GPT-4.1, o3, o3 mini, o4 mini**: modelli di chat e trascrizione di ultima generazione, con gestione dinamica dei token e temperature.
- **Anthropic Claude (Opus 4, Sonnet 4, ecc.)**: modelli AI per chat avanzata, con supporto streaming e contesti estesi.
- **Perplexity**: ricerca online, modelli Sonar, Llama, Mixtral, con limiti token e web search integrata (ricerca online premendo il mappamondo nell’app).
- **Groq**: supporto per modelli open-source (Llama 3, Mixtral, ecc.), selezionabili tramite AIProviderManager.
- **Keychain**: gestione sicura delle API key.

---

## 4. Logiche Principali
- **Selezione automatica provider**: AIProviderManager sceglie il provider migliore in base a API key e modello selezionato.
- **Gestione token dinamica**: il limite di token si adatta al modello selezionato (fino a 200.000 token per Claude, 128.000 per GPT-4.1, 32.768 per Sonar, ecc.).
- **Persistenza reattiva**: le liste di registrazioni e trascrizioni sono reattive grazie a `@FetchRequest` e proprietà `@Published`.
- **Fallback intelligente**: se una tecnologia non è disponibile (es. SpeechAnalyzer su iOS <26), viene usato automaticamente il framework migliore disponibile.
- **Gestione permessi**: richiesta e verifica permessi microfono e trascrizione all’avvio.
- **Prompt centralizzati**: tutti i prompt AI sono gestiti in un unico file, facilmente estendibile.

---

## 5. Dettagli sulle Integrazioni Moderne
### iOS 26 e Speech Framework
- **SpeechAnalyzer (iOS 26+)**: consente trascrizione avanzata, segmentazione, analisi semantica, gestione risultati volatili e finalizzati, e supporto multilingua.
- **Speech Framework**: fallback per iOS 13-25, con supporto on-device e cloud recognition.
- **Selettore automatico**: l’utente può scegliere manualmente il framework o lasciare la selezione automatica.
- **Compatibilità**: il codice è pronto per iOS 26, con fallback automatico e commenti per facilitare l’estensione futura.

### Modelli AI OpenAI, Anthropic, Perplexity, Groq
- **OpenAI**: supporto per GPT-4.1, o3, o3 mini, o4 mini, con gestione dinamica di max tokens e temperature. I limiti sono aggiornati ai modelli 2024 (fino a 128.000 token per GPT-4.1, 32.000 per o3/o4 mini).
- **Anthropic**: supporto per Claude Opus 4, Sonnet 4, 3.7, 3.5 Haiku, con contesti fino a 200.000 token e streaming.
- **Perplexity**: modelli Sonar, Llama, Mixtral, con limiti di 32.768 token e web search integrata (ricerca online premendo il mappamondo nell’app).
- **Groq**: supporto per modelli open-source (Llama 3, Mixtral, ecc.), selezionabili tramite AIProviderManager.
- **Gestione API key**: tutte le chiavi sono salvate in Keychain, con fallback e test di connessione.

---

## 6. Gestione Stato, Persistenza e Core Data
- **Registrazioni e trascrizioni** sono entità Core Data, collegate tra loro.
- **Le viste** usano `@FetchRequest` per aggiornamento automatico.
- **Le operazioni di cancellazione, modifica e creazione** sono propagate in tempo reale all’interfaccia.
- **TranscriptionService** aggiorna lo stato tramite proprietà `@Published` e Combine.

---

## 7. Estendibilità e Notepad per Sviluppi Futuri
- **PromptManager**: aggiungi nuovi prompt AI semplicemente estendendo il file.
- **Nuovi provider**: per aggiungere un nuovo provider AI, crea un nuovo service e aggiorna AIProviderManager.
- **SpeechAnalyzer**: pronto per estensioni future (es. analisi semantica, speaker diarization, ecc.).
- **TODO e idee**:
    - Integrazione modelli multimodali (immagini, video)
    - Supporto a nuovi modelli open-source (es. Gemma, Command R+)
    - Miglioramento UI/UX con SwiftUI 6 e GlassEffectContainer (iOS 26+)
    - Analisi sentiment e topic detection avanzata
    - Integrazione con servizi esterni (es. Google, Azure, HuggingFace)
    - Supporto a plugin AI e automazioni

---

## 8. Collaborazione e Contributi
- **Codice commentato e modulare**: ogni file contiene commenti architetturali e note sulle tecnologie usate.
- **Pull request e issue**: usa GitHub per proporre modifiche, segnalare bug o suggerire nuove funzionalità.
- **Documentazione aggiornata**: questa documentazione è pensata anche per AI non aggiornate, con riferimenti espliciti alle tecnologie moderne (iOS 26, SpeechAnalyzer, modelli AI 2024, ecc.).
- **Best practice**: segui le convenzioni Swift, usa proprietà reattive e preferisci l’estensione modulare.

---

## 9. Risorse e Link Utili
- [Apple Speech Framework](https://developer.apple.com/documentation/speech)
- [Apple SpeechAnalyzer (iOS 26+)](https://developer.apple.com/documentation/speechanalyzer)
- [OpenAI API](https://platform.openai.com/docs/models)
- [Anthropic Claude API](https://docs.anthropic.com/claude/docs/models-overview)
- [Perplexity API](https://docs.perplexity.ai/)
- [Groq API](https://console.groq.com/docs)
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)

---

**Nota per AI e sviluppatori:**
Questa documentazione è aggiornata a giugno 2024 e include riferimenti a tecnologie di ultima generazione. Se stai lavorando con una AI non aggiornata, consulta sempre le sezioni dedicate alle tecnologie moderne e i commenti architetturali nel codice per evitare errori di compatibilità o implementazioni obsolete. 