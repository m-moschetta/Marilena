# Refactor Mirato Email: Criticità e Piano Operativo

Focus: mantenere invariata l’autenticazione e intervenire su HTML, UI AI, categorizzazione, cache, costi LLM e “reply-needed”.

**Stato Attuale (sintesi tecnica)**
- HTML: coesistono più renderer (Core/EmailHTMLRenderer, ModernEmailViewer, AppleMail* e wrapper locali in EmailDetailView) con logica duplicata e comportamenti incoerenti (altezza, colori, link esterni). BaseURL assente (niente risorse relative), ATS permissiva ma senza policy immagini remote. 
- UI AI: pannelli e azioni AI sono in cima al dettaglio email e talvolta invadenti. Mancano modalità compatte/“silenziose”.
- Categorizzazione: presente un servizio ibrido (tradizionale + AI) ma i risultati non persistono in cache. In Core Data l’entità CachedEmail non salva la categoria; getCachedEmails() non filtra per account e di fatto ignora l’argomento accountId.
- Cache: TTL a 5 minuti, caricamento non selettivo per account, nessuna indicizzazione su categoria, nessuna invalidazione per cambi categoria. 
- Efficienza: non esiste limite “ultime N email” sull’uso LLM; la scelta è per giorni recenti. Non c’è “Uncategorized” esplicita. 
- Reply-needed: EmailChatService crea chat su nuove email con euristiche (entro 1h, ecc.) ma manca un detector strutturato “serve risposta?” e integrazione con prompt/parsing dedicati (explicit/implicit requests sono nel prompt, ma non vengono parsati in EmailAIService).

**Criticità Prioritarie**
- HTML non funzionante: duplicazione renderer → risultati incoerenti; stile/altezza/immagini non uniformi; potenziali bug di rendering nei wrapper locali.
- Interfaccia AI: esperienza invasiva; mancano chip/CTA discreti; nessun “AI Minimal Mode”.
- Categorizzazione non applicata: categoria non persiste in cache → su reload tutto torna “senza categoria”.
- Cache: API non mult-account, TTL basso non coordinato con caricamenti, assenza di indici/chiavi su categoria, nessuna invalidazione per update di categoria.
- Costo LLM: nessun limite “ultime 50”, batch e quote presenti ma non ancorati a una strategia di budget chiara.
- Modalità “serve risposta”: detector assente a livello dati/UX; oggi si apre chat anche quando non necessario o senza spiegazioni del “perché”.

**Piano di Intervento (incrementale e verificabile)**

1) HTML Unificato e Robusto
- Unifica su `Core/EmailHTMLRenderer` in tutte le viste (Modern/AppleMail/Detail). Depreca i wrapper WKWebView duplicati in `EmailDetailView` e i viewer legacy.
- Aggiungi opzioni: blocco immagini remote di default + pulsante “Mostra immagini” per mittente non fidato; baseURL nil ok per HTML inline, ma prevedi normalizzazione link relativi → assoluti quando disponibile.
- Stabilizza altezza: usa l’attuale calcolo JS + fallback nativo; rimuovi animazioni ridondanti. 
- Test: 5 campioni HTML (newsletter, fattura, social, ticketing, testo semplice) in light/dark; link esterni aprono in Safari; immagini bloccate sbloccabili.

2) UI AI Discreta (“AI Minimal Mode”)
- Inserisci un “AI Chip” compatto sopra il contenuto: categoria, urgenza, 1 riga di riassunto, CTA “Apri suggerimento”. Pannello espanso solo on tap.
- Impostazione in `Settings`: AI Minimal Mode (default ON), Nascondi pulsanti AI nella lista.
- Porta le azioni AI in un menù contestuale (…): Genera bozza, Altre bozze, Risposta personalizzata.
- Accettazione: nessun layout jump in apertura dettaglio; 60 fps durante scroll.

3) Categorizzazione che “mette davvero” nelle categorie
- Persistenza categoria in cache:
  - Estendi `CachedEmail` con campo `category` (stringa rawValue di `EmailCategory`). Migrazione leggera Core Data.
  - In `EmailCacheService.saveEmailToCache` imposta/aggiorna `category`; in `loadCachedEmails` reidrata `EmailMessage.category`.
- Correzione mult-account: `getCachedEmails(for:)` deve filtrare per `accountId`; `loadCachedEmails()` accetta un account opzionale o filtra per quello corrente.
- In `EmailService.categorizeEmailsInBackground`: dopo batch, salva in cache anche la categoria e marca come categorizzate per evitare ricalcolo.
- UI: chip “Tutte / Lavoro / Personale / Notifiche / Promo / Uncategorized”. Se non si introduce un nuovo enum `.uncategorized`, tratta `category == nil` come “Uncategorized”.
- Accettazione: filtri per categoria riflettono i contatori corretti dopo reload app.

4) Cache affidabile (per performance e UX)
- TTL a 15 min; fetch incrementale solo se `shouldFetchFromServer(accountId)`; mantieni cache per account separati.
- Indicizza per `date` e `category`; aggiungi invalidazione locale quando cambia la categoria.
- Evita over-fetch: quando Online ma in debouncing, mostra cache e rinvia il refresh.
- Accettazione: cold start < 300ms con 200 email in cache; nessun reset di categoria dopo riavvio.

5) Efficienza LLM (cap sui costi)
- Config `maxAIOnLaunch = 50` (default): categorizza con AI solo le ultime 50 non lette/recenti; le altre → heuristics tradizionali o “Uncategorized”.
- Priorità AI: non lette + ricevute negli ultimi X giorni; oltre soglia usa solo regole/domìni/parole chiave.
- Budget runtime: se tempo medio AI o “stimato costo” supera soglia sessione, degrada automaticamente a metodi tradizionali.
- Accettazione: nessun burst > 50 chiamate AI al primo avvio; costo stimato visibile in `EmailCategorizationStatsView`.

6) “Serve Risposta?” e Chat Assistita
- Detector “needs_reply”:
  - Regole leggere: presenza di punto interrogativo + call-to-action (“per favore rispondi”, “RSVP”, “conferma”, “scadenza”, “entro”).
  - Arricchimento AI economico: estendi `emailAnalysisPrompt` con campi `needs_reply: yes/no`, `reason`, `confidence(0-1)`; aggiorna `EmailAIService.parseEmailAnalysis` per parsare richieste esplicite/implicite e needs_reply.
- Flusso nuove email:
  - Se `needs_reply == yes` e confidenza alta → crea chat automatica con bozza; se media → mostra chip “Risposta suggerita” con 1‑tap per aprire chat; se bassa → solo badge “Da valutare”.
- UX: nel dettaglio email mostra “Risposta suggerita” come CTA singola; se già pronta una bozza, offri “Apri bozza”.
- Accettazione: su 5 email test (richiesta meeting, info, newsletter, notifica, promo) solo le prime 2 aprono chat/suggerimento; le altre no.

7) Sequenza PR (sicura, senza toccare auth)
- PR1: Persistenza categoria + fix cache per account + chip “Uncategorized”.
- PR2: Unificazione HTML renderer in tutte le viste + blocco immagini.
- PR3: AI Minimal Mode + menù azioni + cleanup pannelli.
- PR4: Limite “ultime 50” + priorità non lette/recenti + fallback tradizionale.
- PR5: Detector needs_reply + parsing + integrazione con EmailChatService.

**Criteri di Accettazione sintetici**
- HTML: 5 template reali renderizzati correttamente, dark/light, link esterni OK, immagini bloccabili.
- Categorie: filtro/co ntatori corretti dopo riavvio; nessuna perdita categoria in cache.
- Cache: cold start rapido, no fetch inutile entro TTL.
- Costi: max 50 chiamate AI on‑launch; monitor mostra costi/stime.
- Reply-needed: chat/bozza si apre solo quando serve; motivazione visibile (reason).

**Note di Implementazione puntuali**
- Core Data: aggiungere `category: String?` a `CachedEmail` con migrazione leggera (Optional → safe). Backfill pigro alla prima lettura.
- EmailListView: aggiungere filtro “Uncategorized” trattando `nil` come categoria dedicata.
- EmailAIService: estendere `parseEmailAnalysis` per `explicitRequests`, `implicitRequests`, `needs_reply`, `confidence`.
- EmailService: in `categorizeEmailsInBackground`, limita a N=50 le email più recenti non categorizzate, il resto passa da `categorizeWithTraditionalMethods` o resta `nil`.
- Telemetria: loggare numero di email AI/tradizionali, tempo medio e costo stimato (già presente monitor, raffinare). 

Se sei d’accordo, procedo con PR1 (persistenza categoria e fix cache per account), lasciando l’autenticazione invariata.
