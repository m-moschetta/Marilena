import SwiftUI
import CoreData
import AVFoundation
import NaturalLanguage
import Combine
import Speech

struct RecordingDetailView: View {
    let recording: RegistrazioneAudio
    let context: NSManagedObjectContext
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = DetailAudioPlayer()
    @StateObject private var chatService: TranscriptionChatService
    
    @State private var selectedTab: Int = 0
    @State private var showingExportSheet = false
    @State private var exportFormat: ExportFormat = .text
    @State private var showingDeleteAlert = false
    
    @State private var showingTranscriptionModeSheet = false
    @State private var selectedTranscriptionMode = "auto"
    @State private var selectedLanguage = "it-IT"
    @State private var isEditingTitle = false
    @State private var newTitle = ""
    
    init(recording: RegistrazioneAudio, context: NSManagedObjectContext) {
        self.recording = recording
        self.context = context
        self._chatService = StateObject(wrappedValue: TranscriptionChatService(recording: recording, context: context))
    }
    
    var body: some View {
        NavigationView {
                    VStack(spacing: 0) {
            // MARK: - Header Compatto con Selettore Lingua
            recordingHeader
            
            // MARK: - Controlli Audio Compatti
            audioControls
            
            // MARK: - Tab Navigation
            tabNavigation
            
            // MARK: - Contenuto Dinamico
            TabView(selection: $selectedTab) {
                transcriptionView
                    .tag(0)
                
                chatView
                    .tag(1)
                
                analysisView
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .overlay(
            // Toolbar personalizzata
            VStack {
                HStack {
                    Button("Chiudi") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    Spacer()
                    
                    Menu {
                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Esporta", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            shareRecording()
                        } label: {
                            Label("Condividi Audio", systemImage: "waveform")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                            .font(.title2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .background(
                    LinearGradient(
                        colors: [Color(.systemBackground).opacity(0.95), Color(.systemBackground).opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                Spacer()
            }
        )
        .onAppear {
            audioPlayer.setup(with: recording)
            selectedLanguage = UserDefaults.standard.string(forKey: "transcription_language") ?? "it-IT"
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportOptionsView(
                recording: recording,
                selectedFormat: $exportFormat
            )
        }
        .alert("Elimina Registrazione", isPresented: $showingDeleteAlert) {
            Button("Elimina", role: .destructive) {
                deleteRecording()
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Questa azione eliminerà definitivamente la registrazione e tutte le trascrizioni associate.")
        }
        .alert("Modifica Nome", isPresented: $isEditingTitle) {
            TextField("Nome registrazione", text: $newTitle)
            Button("Salva") {
                saveTitle()
            }
            Button("Annulla", role: .cancel) {
                isEditingTitle = false
                newTitle = ""
            }
        } message: {
            Text("Inserisci un nuovo nome per la registrazione")
        }
        .sheet(isPresented: $showingTranscriptionModeSheet) {
            TranscriptionModeSelectionView(
                recording: recording,
                context: context,
                selectedMode: $selectedTranscriptionMode
            )
        }
    }
    
    // MARK: - Header Compatto con Selettore Lingua
    
    private var recordingHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.titolo ?? "Senza titolo")
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .onTapGesture {
                            startEditingTitle()
                        }
                    
                    Text(formatDate(recording.dataCreazione))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selettore lingua compatto
                Menu {
                    ForEach(supportedLanguages, id: \.code) { language in
                        Button(action: {
                            selectedLanguage = language.code
                            UserDefaults.standard.set(language.code, forKey: "transcription_language")
                        }) {
                            HStack {
                                Text(language.flag)
                                Text(language.name)
                                if selectedLanguage == language.code {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(supportedLanguages.first { $0.code == selectedLanguage }?.flag ?? "🇮🇹")
                            .font(.title3)
                        Text(supportedLanguages.first { $0.code == selectedLanguage }?.name ?? "Italiano")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            // Metadati compatti in una riga
            HStack(spacing: 16) {
                Label("\(formatDuration(recording.durata))", systemImage: "clock")
                Label(recording.qualitaAudio?.capitalized ?? "Media", systemImage: "waveform")
                Label("\(getTranscriptions().count)", systemImage: "text.quote")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 50) // Spazio per la toolbar
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Controlli Audio Compatti
    
    private var audioControls: some View {
        VStack(spacing: 12) {
            // Timeline compatta
            HStack {
                Text(formatDuration(audioPlayer.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: Binding(
                    get: { audioPlayer.currentTime },
                    set: { newValue in
                        audioPlayer.currentTime = newValue
                        audioPlayer.seek(to: newValue / audioPlayer.duration)
                    }
                ), in: 0...audioPlayer.duration)
                .accentColor(.blue)
                
                Text(formatDuration(audioPlayer.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Controlli compatti
            HStack(spacing: 20) {
                Button(action: { 
                    let newTime = max(0, audioPlayer.currentTime - 10)
                    audioPlayer.currentTime = newTime
                    audioPlayer.seek(to: newTime / audioPlayer.duration)
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                
                Button(action: { 
                    let newTime = min(audioPlayer.duration, audioPlayer.currentTime + 10)
                    audioPlayer.currentTime = newTime
                    audioPlayer.seek(to: newTime / audioPlayer.duration)
                }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    

    
    // MARK: - Tab Navigation Compatta
    
    private var tabNavigation: some View {
        HStack(spacing: 0) {
            ForEach(tabItems, id: \.id) { tab in
                Button(action: {
                    selectedTab = tab.id
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab.id ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab.id ? Color.blue.opacity(0.1) : Color.clear)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - Supporting Types
    
    struct Language {
        let code: String
        let name: String
        let flag: String
    }
    
    struct TabItem {
        let id: Int
        let title: String
        let icon: String
    }
    
    private var transcriptionView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let transcriptions = getTranscriptions()
                
                if transcriptions.isEmpty {
                    emptyTranscriptionView
                } else {
                    // Header con pulsante per nuova trascrizione
                    HStack {
                        Text("Trascrizioni")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Nuova Trascrizione") {
                            requestSpeechPermissionsAndShowSheet()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.horizontal)
                    
                    ForEach(transcriptions, id: \.objectID) { transcription in
                        TranscriptionCard(
                            transcription: transcription,
                            currentTime: audioPlayer.currentTime,
                            onTimestampTap: { time in
                                audioPlayer.seek(to: time / audioPlayer.duration)
                            }
                        )
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Dati di Supporto
    
    private let supportedLanguages = [
        Language(code: "it-IT", name: "Italiano", flag: "🇮🇹"),
        Language(code: "en-US", name: "English", flag: "🇺🇸"),
        Language(code: "es-ES", name: "Español", flag: "🇪🇸"),
        Language(code: "fr-FR", name: "Français", flag: "🇫🇷"),
        Language(code: "de-DE", name: "Deutsch", flag: "🇩🇪"),
        Language(code: "pt-PT", name: "Português", flag: "🇵🇹")
    ]
    
    private let tabItems = [
        TabItem(id: 0, title: "Trascrizioni", icon: "text.quote"),
        TabItem(id: 1, title: "Chat", icon: "message"),
        TabItem(id: 2, title: "Analisi", icon: "chart.bar")
    ]
    
    private var emptyTranscriptionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.quote.rtl")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Nessuna Trascrizione")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Avvia la trascrizione per analizzare il contenuto audio e poter fare domande.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Trascrivi Ora") {
                requestSpeechPermissionsAndShowSheet()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var chatView: some View {
        TranscriptionChatView(chatService: chatService)
    }
    
    private var analysisView: some View {
        TranscriptionAnalysisView(recording: recording)
    }
    

    
    // MARK: - Helper Methods
    
    private func getTranscriptions() -> [Trascrizione] {
        let transcriptions = recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
        return transcriptions.sorted { ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) }
    }
    
    private func transcribeRecording() async {
        let transcriptionService = SpeechTranscriptionService(context: context)
        
        // Salva temporaneamente la modalità selezionata
        let originalMode = UserDefaults.standard.string(forKey: "transcription_mode") ?? "auto"
        UserDefaults.standard.set(selectedTranscriptionMode, forKey: "transcription_mode")
        
        do {
            _ = try await transcriptionService.transcribeRecording(recording)
        } catch {
            print("Errore trascrizione: \(error)")
        }
        
        // Ripristina la modalità originale
        UserDefaults.standard.set(originalMode, forKey: "transcription_mode")
    }
    
    private func shareRecording() {
        guard let url = recording.pathFile else { return }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func requestSpeechPermissionsAndShowSheet() {
        print("🎤 RecordingDetailView: Richiesta permessi Speech Recognition...")
        
        // Verifica se siamo nel simulatore
        #if targetEnvironment(simulator)
        print("🎤 RecordingDetailView: Esecuzione nel simulatore")
        // Nel simulatore, prova comunque a richiedere i permessi per testare
        let simulatorStatus = SFSpeechRecognizer.authorizationStatus()
        print("🎤 RecordingDetailView: Stato permessi nel simulatore: \(simulatorStatus.rawValue)")
        
        if simulatorStatus == .notDetermined {
            print("🎤 RecordingDetailView: Richiesta permessi nel simulatore...")
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    print("🎤 RecordingDetailView: Risposta permessi simulatore: \(authStatus.rawValue)")
                    // Nel simulatore, apri comunque la sheet
                    self.showingTranscriptionModeSheet = true
                }
            }
        } else {
            // Se i permessi sono già determinati, apri direttamente la sheet
            showingTranscriptionModeSheet = true
        }
        return
        #endif
        
        // Verifica lo stato attuale dei permessi
        let status = SFSpeechRecognizer.authorizationStatus()
        print("🎤 RecordingDetailView: Stato permessi attuale: \(status.rawValue)")
        
        // Verifica se Speech Recognition è disponibile
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) else {
            print("❌ RecordingDetailView: SFSpeechRecognizer non disponibile")
            showSpeechRecognitionUnavailableAlert()
            return
        }
        
        if !recognizer.isAvailable {
            print("❌ RecordingDetailView: Speech Recognition non disponibile")
            showSpeechRecognitionUnavailableAlert()
            return
        }
        
        switch status {
        case .notDetermined:
            print("🎤 RecordingDetailView: Richiesta permessi...")
            // Richiedi i permessi
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    print("🎤 RecordingDetailView: Risposta permessi: \(authStatus.rawValue)")
                    switch authStatus {
                    case .authorized:
                        print("✅ RecordingDetailView: Permessi Speech Recognition concessi")
                        self.showingTranscriptionModeSheet = true
                    case .denied:
                        print("❌ RecordingDetailView: Permessi Speech Recognition negati")
                        self.showPermissionDeniedAlert()
                    case .restricted:
                        print("❌ RecordingDetailView: Permessi Speech Recognition limitati")
                        self.showPermissionDeniedAlert()
                    case .notDetermined:
                        print("❌ RecordingDetailView: Permessi Speech Recognition non determinati")
                        self.showPermissionDeniedAlert()
                    @unknown default:
                        print("❌ RecordingDetailView: Stato permessi sconosciuto")
                        self.showPermissionDeniedAlert()
                    }
                }
            }
        case .authorized:
            print("✅ RecordingDetailView: Permessi Speech Recognition già concessi")
            showingTranscriptionModeSheet = true
        case .denied, .restricted:
            print("❌ RecordingDetailView: Permessi Speech Recognition negati/limitati")
            showPermissionDeniedAlert()
        @unknown default:
            print("❌ RecordingDetailView: Stato permessi sconosciuto")
            showPermissionDeniedAlert()
        }
    }
    
    private func showPermissionDeniedAlert() {
        // Mostra alert per andare nelle impostazioni
        let alert = UIAlertController(
            title: "Permessi Richiesti",
            message: "Per trascrivere l'audio, Marilena ha bisogno dell'accesso al riconoscimento vocale. Vai in Impostazioni > Privacy e Sicurezza > Riconoscimento vocale e abilita Marilena.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Impostazioni", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func showSpeechRecognitionUnavailableAlert() {
        let alert = UIAlertController(
            title: "Riconoscimento Vocale Non Disponibile",
            message: "Il riconoscimento vocale non è disponibile su questo dispositivo o in questo ambiente. Prova a:\n\n• Usare un dispositivo fisico invece del simulatore\n• Verificare che i modelli linguistici siano installati\n• Controllare la connessione internet per il riconoscimento cloud",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func deleteRecording() {
        // Elimina file fisico
        if let pathString = recording.pathFile?.path {
            try? FileManager.default.removeItem(atPath: pathString)
        }
        
        // Elimina da Core Data
        context.delete(recording)
        
        do {
            try context.save()
            dismiss()
        } catch {
            print("Errore eliminazione: \(error)")
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startEditingTitle() {
        newTitle = recording.titolo ?? ""
        isEditingTitle = true
    }
    
    private func saveTitle() {
        if newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newTitle = recording.titolo ?? "" // Ripristina il vecchio titolo se vuoto
        } else {
            recording.titolo = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                try context.save()
                isEditingTitle = false
            } catch {
                print("Errore salvataggio titolo: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct TranscriptionCard: View {
    let transcription: Trascrizione
    let currentTime: TimeInterval
    let onTimestampTap: (TimeInterval) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header della trascrizione
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trascrizione")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Text("\(transcription.paroleTotali) parole")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(transcription.accuratezza * 100))% accuratezza")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Mostra il modello utilizzato con colore
                        Text(getModelDisplayName(transcription.frameworkUtilizzato ?? ""))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(getModelColor(transcription.frameworkUtilizzato ?? "").opacity(0.2))
                            .foregroundColor(getModelColor(transcription.frameworkUtilizzato ?? ""))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("Copia Testo") {
                        UIPasteboard.general.string = transcription.testoCompleto
                    }
                    
                    Button("Condividi") {
                        shareTranscription()
                    }
                    
                    Button("Elimina", role: .destructive) {
                        deleteTranscription()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // Testo della trascrizione con timestamp evidenziati
            TranscriptionTextView(
                transcription: transcription,
                currentTime: currentTime,
                onTimestampTap: onTimestampTap
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func getModelDisplayName(_ framework: String) -> String {
        switch framework {
        case "SpeechAnalyzer": return "Speech Analyzer"
        case "SpeechFramework": return "Speech Framework"
        case "WhisperAPI": return "Whisper API"
        case "Local": return "Locale"
        default: return framework
        }
    }
    
    private func getModelColor(_ framework: String) -> Color {
        switch framework {
        case "SpeechAnalyzer": return .purple
        case "SpeechFramework": return .orange
        case "WhisperAPI": return .green
        case "Local": return .blue
        default: return .gray
        }
    }
    
    private func shareTranscription() {
        guard let text = transcription.testoCompleto else { return }
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func deleteTranscription() {
        // Implementa la logica per eliminare la trascrizione
        // Questo dovrebbe essere gestito dal parent view
    }
}

struct TranscriptionTextView: View {
    let transcription: Trascrizione
    let currentTime: TimeInterval
    let onTimestampTap: (TimeInterval) -> Void
    
    @State private var highlightedRange: Range<String.Index>?
    
    var body: some View {
        ScrollView {
            Text(transcription.testoCompleto ?? "")
                .font(.body)
                .lineLimit(nil)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(highlightBackground)
        }
        .frame(maxHeight: 300)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            updateHighlight()
        }
    }
    
    @ViewBuilder
    private var highlightBackground: some View {
        // Implementazione highlight sincronizzato con audio
        if let range = highlightedRange,
           let text = transcription.testoCompleto {
            
            Rectangle()
                .fill(Color.blue.opacity(0.2))
                .frame(height: 20)
                .offset(y: calculateHighlightOffset(for: range, in: text))
        }
    }
    
    private func updateHighlight() {
        guard let metadataData = transcription.metadatiTemporali,
              let timestamps = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: metadataData) as? [TimeInterval: String],
              let text = transcription.testoCompleto else { return }
        
        // Trova il timestamp più vicino al tempo corrente
        let sortedTimestamps = timestamps.sorted { $0.key < $1.key }
        
        for (index, (timestamp, segment)) in sortedTimestamps.enumerated() {
            let nextTimestamp = index < sortedTimestamps.count - 1 ? sortedTimestamps[index + 1].key : Double.infinity
            
            if currentTime >= timestamp && currentTime < nextTimestamp {
                if let range = text.range(of: segment) {
                    highlightedRange = range
                    return
                }
            }
        }
        
        highlightedRange = nil
    }
    
    private func calculateHighlightOffset(for range: Range<String.Index>, in text: String) -> CGFloat {
        // Calcola l'offset per l'highlight (implementazione semplificata)
        let distance = text.distance(from: text.startIndex, to: range.lowerBound)
        let lineHeight: CGFloat = 20
        let charactersPerLine: CGFloat = 50 // Approssimazione
        
        return CGFloat(distance) / charactersPerLine * lineHeight
    }
}

// MARK: - Detail Audio Player

@MainActor
class DetailAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var recording: RegistrazioneAudio?
    
    func setup(with recording: RegistrazioneAudio) {
        self.recording = recording
        
        guard let url = recording.pathFile else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
        } catch {
            print("Errore setup player: \(error)")
        }
    }
    
    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func seek(to progress: Double) {
        let time = duration * progress
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    func skipForward(_ seconds: TimeInterval) {
        let newTime = min(currentTime + seconds, duration)
        audioPlayer?.currentTime = newTime
        currentTime = newTime
    }
    
    func skipBackward(_ seconds: TimeInterval) {
        let newTime = max(currentTime - seconds, 0)
        audioPlayer?.currentTime = newTime
        currentTime = newTime
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTime()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTime() {
        currentTime = audioPlayer?.currentTime ?? 0
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
    }
}

// MARK: - Supporting Types

// MARK: - Export Options

struct ExportOptionsView: View {
    let recording: RegistrazioneAudio
    @Binding var selectedFormat: ExportFormat
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Formato Esportazione") {
                    Picker("Formato", selection: $selectedFormat) {
                        Text("Testo Semplice").tag(ExportFormat.text)
                        Text("Con Timestamp").tag(ExportFormat.timestamped)
                        Text("Sottotitoli SRT").tag(ExportFormat.srt)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Anteprima") {
                    let transcriptionService = SpeechTranscriptionService(context: recording.managedObjectContext!)
                    let transcriptions = recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
                    
                    if let transcription = transcriptions.first {
                        Text(transcriptionService.exportTranscription(transcription, format: selectedFormat))
                            .font(.caption)
                            .lineLimit(10)
                    }
                }
            }
            .navigationTitle("Esporta Trascrizione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Esporta") {
                        exportTranscription()
                    }
                }
            }
        }
    }
    
    private func exportTranscription() {
        let transcriptionService = SpeechTranscriptionService(context: recording.managedObjectContext!)
        let transcriptions = recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
        
        guard let transcription = transcriptions.first else { return }
        
        let text = transcriptionService.exportTranscription(transcription, format: selectedFormat)
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        
        dismiss()
    }
} 

// MARK: - Transcription Mode Selection View

struct TranscriptionModeSelectionView: View {
    let recording: RegistrazioneAudio
    let context: NSManagedObjectContext
    @Binding var selectedMode: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var transcriptionService: SpeechTranscriptionService
    @State private var isTranscribing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let transcriptionModes = [
        ("auto", "Automatico", "Sceglie automaticamente il miglior framework disponibile", "wand.and.stars"),
        ("speech_analyzer", "Speech Analyzer (iOS 26+)", "Framework più avanzato per iOS 26+", "brain.head.profile"),
        ("speech_framework", "Speech Framework", "Framework tradizionale per iOS 13+", "waveform"),
        ("whisper", "Whisper API", "Trascrizione tramite OpenAI Whisper API", "cloud"),
        ("local", "Locale", "Trascrizione locale con modelli integrati", "device.phone.portrait")
    ]
    
    init(recording: RegistrazioneAudio, context: NSManagedObjectContext, selectedMode: Binding<String>) {
        self.recording = recording
        self.context = context
        self._selectedMode = selectedMode
        self._transcriptionService = StateObject(wrappedValue: SpeechTranscriptionService(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header con info registrazione
                recordingInfoHeader
                
                // Lista modalità
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(transcriptionModes, id: \.0) { mode in
                            TranscriptionModeCard(
                                mode: mode,
                                isSelected: selectedMode == mode.0,
                                onTap: {
                                    selectedMode = mode.0
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // Pulsante trascrizione
                transcriptionButton
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Seleziona Modello")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .alert("Trascrizione", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Recording Info Header
    
    private var recordingInfoHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.titolo ?? "Senza titolo")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(formatDuration(recording.durata)) • \(recording.qualitaAudio?.capitalized ?? "Media")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Statistiche trascrizioni esistenti
            let existingTranscriptions = getExistingTranscriptions()
            if !existingTranscriptions.isEmpty {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundColor(.green)
                    
                    Text("\(existingTranscriptions.count) trascrizione\(existingTranscriptions.count > 1 ? "i" : "") esistente\(existingTranscriptions.count > 1 ? "i" : "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Transcription Button
    
    private var transcriptionButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
            
            Button {
                startTranscription()
            } label: {
                HStack {
                    if isTranscribing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title2)
                    }
                    
                    Text(isTranscribing ? "Trascrivendo..." : "Avvia Trascrizione")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isTranscribing ? Color.gray : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isTranscribing)
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func getExistingTranscriptions() -> [Trascrizione] {
        let transcriptions = recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
        return transcriptions.sorted { ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) }
    }
    
    private func startTranscription() {
        isTranscribing = true
        
        // Salva temporaneamente la modalità selezionata
        let originalMode = UserDefaults.standard.string(forKey: "transcription_mode") ?? "auto"
        UserDefaults.standard.set(selectedMode, forKey: "transcription_mode")
        
        Task {
            do {
                // Crea un nuovo servizio con il context corretto
                let transcriptionService = SpeechTranscriptionService(context: context)
                
                // Verifica che i permessi siano concessi
                if !transcriptionService.isPermissionGranted {
                    // Richiedi i permessi
                    transcriptionService.requestSpeechPermissions()
                    
                    // Aspetta un momento per la risposta
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondi
                    
                    if !transcriptionService.isPermissionGranted {
                        await MainActor.run {
                            isTranscribing = false
                            alertMessage = "Permessi di riconoscimento vocale negati. Vai in Impostazioni > Privacy e Sicurezza > Riconoscimento vocale e abilita Marilena."
                            showingAlert = true
                        }
                        return
                    }
                }
                
                // Verifica che il riconoscimento vocale sia disponibile
                if !transcriptionService.isSpeechRecognitionAvailable() {
                    await MainActor.run {
                        isTranscribing = false
                        alertMessage = "Riconoscimento vocale non disponibile su questo dispositivo."
                        showingAlert = true
                    }
                    return
                }
                
                _ = try await transcriptionService.transcribeRecording(recording)
                
                await MainActor.run {
                    isTranscribing = false
                    alertMessage = "Trascrizione completata con successo!"
                    showingAlert = true
                    
                    // Chiudi la sheet dopo un breve delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isTranscribing = false
                    
                    // Gestione errori più specifica
                    let errorMessage: String
                    if error.localizedDescription.contains("Failed to initialize recognizer") {
                        errorMessage = "Impossibile inizializzare il riconoscimento vocale. Verifica che i modelli linguistici siano installati e che i permessi siano concessi."
                    } else if error.localizedDescription.contains("Permessi Speech Recognition negati") {
                        errorMessage = "Permessi di riconoscimento vocale negati. Vai in Impostazioni > Privacy e Sicurezza > Riconoscimento vocale e abilita Marilena."
                    } else if error.localizedDescription.contains("File audio non trovato") {
                        errorMessage = "File audio non trovato. La registrazione potrebbe essere stata eliminata."
                    } else if error.localizedDescription.contains("File audio vuoto") {
                        errorMessage = "Il file audio è vuoto. Prova a registrare di nuovo."
                    } else {
                        errorMessage = "Errore durante la trascrizione: \(error.localizedDescription)"
                    }
                    
                    alertMessage = errorMessage
                    showingAlert = true
                }
            }
            
            // Ripristina la modalità originale
            UserDefaults.standard.set(originalMode, forKey: "transcription_mode")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Transcription Mode Card

struct TranscriptionModeCard: View {
    let mode: (String, String, String, String)
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icona
                Image(systemName: mode.3)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                // Contenuto
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.1)
                    .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(mode.2)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 