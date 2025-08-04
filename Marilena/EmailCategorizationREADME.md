# Email Categorization with OpenAI

## Panoramica

Il sistema di categorizzazione automatica delle email utilizza **OpenAI GPT-4.1 nano** per classificare automaticamente le email in 4 categorie principali basandosi su mittente, oggetto e anteprima del contenuto.

## Categorie

### 📋 Lavoro (`work`)
- Email professionali
- Riunioni e meeting
- Comunicazioni con clienti/colleghi
- Progetti e documenti di lavoro
- **Icona:** `briefcase.fill`
- **Colore:** Blu

### 👤 Personale (`personal`)
- Email da amici e famiglia
- Comunicazioni personali
- Eventi sociali
- **Icona:** `person.fill`
- **Colore:** Verde

### 🔔 Notifiche (`notifications`)
- Newsletter e aggiornamenti
- Conferme di ordini/servizi
- Notifiche automatiche
- Aggiornamenti di sistema
- **Icona:** `bell.fill`
- **Colore:** Arancione

### 📢 Promo/Spam (`promotional`)
- Email promozionali
- Offerte e sconti
- Marketing
- Spam
- **Icona:** `megaphone.fill`
- **Colore:** Rosso

## Come Funziona

### 1. Categorizzazione Automatica
- Le email vengono categorizzate automaticamente quando caricate
- Utilizza OpenAI GPT-4.1 nano per l'analisi intelligente
- Processa in background per non bloccare l'UI
- Gestisce rate limiting e retry automatici

### 2. Categorizzazione Manuale
```swift
// Categorizza una singola email manualmente
await emailService.categorizeEmail(emailId)
```

### 3. Filtri per Categoria
```swift
// Ottieni email per categoria specifica
let workEmails = emailService.emailsForCategory(.work)

// Ottieni conteggi per tutte le categorie
let counts = emailService.getCategoryCounts()
```

## Utilizzo nell'App

### EmailMessage Esteso
```swift
public struct EmailMessage {
    // ... proprietà esistenti ...
    public var category: EmailCategory?
}
```

### EmailCategorizationService
Il servizio principale per la categorizzazione:
- **Modello:** `gpt-4.1-nano` (ottimizzato per velocità)
- **Prompt avanzato** con analisi domini e parole chiave italiane
- **Parsing robusto** con mapping prioritizzato e fallback intelligenti
- **Analisi contesto** con riconoscimento domini aziendali/consumer
- **Pulizia contenuto** avanzata (HTML, URL, entità)
- **Batch processing** per efficienza e rate limiting
- **Logging dettagliato** per debugging e monitoraggio

### Integrazione in EmailService
- Categorizzazione automatica al caricamento
- Metodi per filtri e statistiche
- Cache delle categorie assegnate
- Test integrati per validazione

## Prompt Engineering

Il sistema utilizza un prompt specializzato che:
1. **Definisce chiaramente** le 4 categorie
2. **Analizza** mittente, oggetto e anteprima
3. **Fornisce istruzioni** specifiche per edge cases
4. **Supporta** contenuti in italiano e inglese

## Performance

### Ottimizzazioni
- **UI non bloccante:** Categorizzazione in background
- **Batch processing:** Processa 5 email per volta
- **Rate limiting:** Rispetta i limiti API di OpenAI
- **Cache:** Salva categorie per evitare ri-categorizzazione

### Considerazioni
- **Costo API:** Circa 0.0001-0.0005$ per email
- **Velocità:** 1-3 secondi per batch di 5 email
- **Affidabilità:** Fallback a categoria "Notifiche"

## Testing

### Test Automatico
```swift
// Testa la categorizzazione con email di esempio
await emailService.testEmailCategorization()
```

Questo crea email di test per ogni categoria e verifica la precisione della classificazione.

### Email di Test Incluse
- **Lavoro:** Meeting e progetti
- **Personale:** Messaggi da amici
- **Notifiche:** Conferme di ordini
- **Promo:** Offerte commerciali

## Requisiti

1. **API Key OpenAI** configurata nell'app
2. **Connessione internet** per chiamate API
3. **Account email** autenticato

## Personalizzazione

### Modificare le Categorie
Per aggiungere/modificare categorie, aggiorna:
1. `EmailCategory` enum in `SharedTypes.swift`
2. Prompt in `EmailCategorizationService.swift`
3. Logica di parsing delle risposte

### Ottimizzare il Prompt
Il prompt può essere personalizzato per:
- Supportare altre lingue
- Aggiungere categorie specifiche
- Migliorare la precisione per domini specifici

## Monitoraggio

### Log disponibili
- Categorizzazione in corso
- Risultati per ogni email
- Errori e fallback
- Statistiche per categoria

### Debug
Tutti i log sono prefissati con:
- `🤖 EmailCategorizationService:`
- `📧 EmailService:`
- `🧪` per i test

## Prossimi Sviluppi

1. **Machine Learning locale** per ridurre costi API
2. **Categorizzazione personalizzata** per utente
3. **Analisi sentiment** delle email
4. **Auto-regole** basate su pattern ricorrenti