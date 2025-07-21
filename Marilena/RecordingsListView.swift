import SwiftUI
import CoreData
import AVFoundation
import Combine

struct RecordingsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RegistrazioneAudio.dataCreazione, ascending: false)],
        animation: .default
    ) private var recordings: FetchedResults<RegistrazioneAudio>
    
    @State private var refreshID = UUID()
    @State private var currentPlayerRecording: RegistrazioneAudio?
    
    @StateObject private var transcriptionService: SpeechTranscriptionService
    @StateObject private var audioPlayer = AudioPlayer()
    let recordingService: RecordingService
    
    @State private var searchText = ""
    @State private var selectedFilter: RecordingFilter = .all
    @State private var showingSearchBar = false
    @State private var editingRecording: RegistrazioneAudio?
    @State private var newRecordingName = ""
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: RegistrazioneAudio?
    @State private var selectedRecording: RegistrazioneAudio?
    
    init(context: NSManagedObjectContext, recordingService: RecordingService) {
        self._transcriptionService = StateObject(wrappedValue: SpeechTranscriptionService(context: context))
        self.recordingService = recordingService
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header minimale
                headerView
                // Splash screen se non ci sono registrazioni
                if recordings.isEmpty {
                    splashScreenView
                } else {
                    // Spazio extra tra filtri e lista
                    Spacer().frame(height: 24)
                    // Lista registrazioni semplificata
                    recordingsListView
                }
            }
            // Bottone centrale glassmorphism compatibile iOS 18+
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            if recordingService.recordingState == .recording {
                                recordingService.stopRecording()
                            } else {
                                recordingService.startRecording()
                            }
                        }
                    }) {
                        GlassmorphismRecordButton(isRecording: recordingService.recordingState == .recording, audioLevel: recordingService.audioLevel) {
                            withAnimation(.spring()) {
                                if recordingService.recordingState == .recording {
                                    recordingService.stopRecording()
                                } else {
                                    recordingService.startRecording()
                                }
                            }
                        }
                    }
                    .scaleEffect(recordingService.recordingState == .recording ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: recordingService.recordingState)
                    Spacer()
                }
                .padding(.bottom, 36) // sopra i tab
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recording: recording, context: viewContext)
        }
        .alert("Elimina Registrazione", isPresented: $showingDeleteAlert) {
            Button("Elimina", role: .destructive) {
                if let recording = recordingToDelete {
                    deleteRecording(recording)
                }
                recordingToDelete = nil
            }
            Button("Annulla", role: .cancel) {
                recordingToDelete = nil
            }
        } message: {
            Text("Sei sicuro di voler eliminare questa registrazione? L'azione non può essere annullata.")
        }
        .alert("Modifica Nome",
               isPresented: Binding(
                   get: { editingRecording != nil },
                   set: { newValue in if !newValue { editingRecording = nil; newRecordingName = "" } }
               )
        ) {
            TextField("Nome registrazione", text: $newRecordingName)
            Button("Salva") {
                saveRecordingName()
            }
            Button("Annulla", role: .cancel) {
                editingRecording = nil
                newRecordingName = ""
            }
        } message: {
            Text("Inserisci un nuovo nome per la registrazione")
        }
        .onAppear {
            debugCoreDataState()
        }
        .id(refreshID) // Forza refresh quando cambia refreshID
        .onReceive(NotificationCenter.default.publisher(for: .recordingCreated)) { _ in
            // Forza aggiornamento della lista quando viene creata una nuova registrazione
            print("📱 RecordingsListView: Ricevuta notifica recordingCreated")
            DispatchQueue.main.async {
                refreshID = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptionCompleted)) { _ in
            // Forza aggiornamento della lista quando viene completata una trascrizione  
            print("📱 RecordingsListView: Ricevuta notifica transcriptionCompleted")
            DispatchQueue.main.async {
                refreshID = UUID()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Filtri semplificati
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RecordingFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.title,
                            isSelected: selectedFilter == filter,
                            count: getFilterCount(filter)
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Barra di ricerca minimale
            if !searchText.isEmpty || selectedFilter != .all {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Cerca registrazioni...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
    
    // MARK: - Splash Screen
    private var splashScreenView: some View {
        VStack(spacing: 32) {
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .shadow(radius: 8)
            Text("Benvenuto in Marilena!")
                .font(.title)
                .fontWeight(.bold)
            VStack(alignment: .leading, spacing: 12) {
                Text("• Tocca il microfono per iniziare una nuova registrazione audio.")
                Text("• Dopo aver registrato, potrai trascrivere l'audio in testo con un solo tap.")
                Text("• Le trascrizioni ti permettono di cercare, analizzare e chattare con l'AI sul contenuto.")
                Text("• Puoi filtrare le registrazioni in base alla presenza di trascrizioni.")
            }
            .font(.body)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            Spacer()
        }
        .padding(.top, 48)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Recordings List
    
    private var recordingsListView: some View {
        List {
            ForEach(filteredRecordings, id: \.objectID) { recording in
                MinimalRecordingRowView(
                    recording: recording,
                    audioPlayer: audioPlayer,
                    transcriptionService: transcriptionService,
                    onRequestFullScreen: { rec in
                        currentPlayerRecording = rec
                    },
                    onSelect: {
                        selectedRecording = recording
                    },
                    onDelete: {
                        recordingToDelete = recording
                        showingDeleteAlert = true
                    },
                    onRename: {
                        startEditingName(for: recording)
                    }
                )
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .refreshable {
            // Aggiorna dati se necessario
        }
        .fullScreenCover(item: $currentPlayerRecording) { rec in
            FullScreenPlayerView(recording: rec, audioPlayer: audioPlayer) {
                currentPlayerRecording = nil
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredRecordings: [RegistrazioneAudio] {
        var filtered = Array(recordings)
        
        // Applica filtro di categoria
        switch selectedFilter {
        case .all:
            break
        case .withTranscription:
            filtered = filtered.filter { !getTranscriptions(for: $0).isEmpty }
        case .withoutTranscription:
            filtered = filtered.filter { getTranscriptions(for: $0).isEmpty }
        case .processing:
            filtered = filtered.filter { $0.statoElaborazione == "in_elaborazione" }
        case .completed:
            filtered = filtered.filter { $0.statoElaborazione == "completata" }
        }
        
        // Applica ricerca testuale
        if !searchText.isEmpty {
            filtered = filtered.filter { recording in
                let titleMatch = recording.titolo?.localizedCaseInsensitiveContains(searchText) ?? false
                let transcriptionMatch = getTranscriptions(for: recording).contains { transcription in
                    transcription.testoCompleto?.localizedCaseInsensitiveContains(searchText) ?? false
                }
                return titleMatch || transcriptionMatch
            }
        }
        
        return filtered
    }
    
    // MARK: - Helper Methods
    
    private func getFilterCount(_ filter: RecordingFilter) -> Int {
        switch filter {
        case .all:
            return recordings.count
        case .withTranscription:
            return recordings.filter { !getTranscriptions(for: $0).isEmpty }.count
        case .withoutTranscription:
            return recordings.filter { getTranscriptions(for: $0).isEmpty }.count
        case .processing:
            return recordings.filter { $0.statoElaborazione == "in_elaborazione" }.count
        case .completed:
            return recordings.filter { $0.statoElaborazione == "completata" }.count
        }
    }
    
    private func getTranscriptions(for recording: RegistrazioneAudio) -> [Trascrizione] {
        return recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
    }
    
    private func deleteRecording(_ recording: RegistrazioneAudio) {
        // Elimina file fisico
        if let pathString = recording.pathFile?.path {
            try? FileManager.default.removeItem(atPath: pathString)
        }
        
        // Elimina da Core Data (cascading eliminerà anche le trascrizioni)
        viewContext.delete(recording)
        
        do {
            try viewContext.save()
        } catch {
            print("Errore eliminazione registrazione: \(error)")
        }
    }
    
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = filteredRecordings[index]
            deleteRecording(recording)
        }
    }
    
    private func startEditingName(for recording: RegistrazioneAudio) {
        editingRecording = recording
        newRecordingName = recording.titolo ?? ""
    }
    
    private func saveRecordingName() {
        guard let recording = editingRecording else { return }
        
        let trimmedName = newRecordingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            recording.titolo = trimmedName
            
            do {
                try viewContext.save()
                print("✅ Nome registrazione salvato: \(trimmedName)")
                
                // Debug: verifica che la registrazione sia ancora presente
                let fetchRequest: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", recording.id! as CVarArg)
                let results = try viewContext.fetch(fetchRequest)
                print("🔍 Debug: Registrazioni trovate con questo ID: \(results.count)")
                
            } catch {
                print("❌ Errore salvataggio nome: \(error)")
            }
        }
        editingRecording = nil
        newRecordingName = ""
    }
    
    // MARK: - Debug Methods
    
    private func debugCoreDataState() {
        print("🔍 === DEBUG CORE DATA STATE ===")
        
        let fetchRequest: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
        do {
            let recordings = try viewContext.fetch(fetchRequest)
            print("📊 Totale registrazioni in Core Data: \(recordings.count)")
            
            for (index, recording) in recordings.enumerated() {
                print("📝 Registrazione \(index + 1):")
                print("   - ID: \(recording.id?.uuidString ?? "nil")")
                print("   - Titolo: \(recording.titolo ?? "nil")")
                print("   - Data: \(recording.dataCreazione?.description ?? "nil")")
                print("   - Durata: \(recording.durata)")
                print("   - Path: \(recording.pathFile?.path ?? "nil")")
            }
        } catch {
            print("❌ Errore fetch registrazioni: \(error)")
        }
        
        print("🔍 === FINE DEBUG ===")
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.primary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct MinimalRecordingRowView: View {
    let recording: RegistrazioneAudio
    @ObservedObject var audioPlayer: AudioPlayer
    let transcriptionService: SpeechTranscriptionService
    let onRequestFullScreen: (RegistrazioneAudio) -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    
    @State private var isTranscribing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Informazioni Principali
            HStack(spacing: 16) {
                // Play button più grande
                Button {
                    if audioPlayer.isPlaying && audioPlayer.currentRecording == recording {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play(recording: recording)
                        onRequestFullScreen(recording)
                    }
                } label: {
                    Image(systemName: audioPlayer.isPlaying && audioPlayer.currentRecording == recording ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                
                // Content migliorato
                VStack(alignment: .leading, spacing: 6) {
                    // Titolo e durata sulla stessa riga
                    HStack {
                        Text(recording.titolo ?? "Senza titolo")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(formatDuration(recording.durata))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    // Data e info trascrizioni
                    HStack {
                        Text(formatDate(recording.dataCreazione))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Badge trascrizioni
                        let transcriptionsCount = getTranscriptions().count
                        if transcriptionsCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "text.quote")
                                    .font(.caption2)
                                Text("\(transcriptionsCount)")
                                    .font(.caption2)
                                    .bold()
                            }
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                    
                    // Preview trascrizione se disponibile
                    if let transcription = getTranscriptions().first,
                       let text = transcription.testoCompleto,
                       !text.isEmpty {
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
                .onTapGesture {
                    onSelect()
                }
                
                // Chevron per indicare che è tappabile
                Button {
                    onSelect()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // MARK: - Player Compatto (solo barra progresso)
            if audioPlayer.currentRecording == recording {
                HStack {
                    Text(formatDuration(audioPlayer.currentTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    
                    ProgressView(value: audioPlayer.currentTime, total: recording.durata)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        .frame(maxWidth: .infinity)

                    Text(formatDuration(recording.durata))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        /* tap per dettaglio delegato a testo/chevron */
        .onLongPressGesture {
            onRename()
        }
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Rinomina", systemImage: "pencil")
            }
            
            Button {
                onSelect()
            } label: {
                Label("Visualizza Dettagli", systemImage: "info.circle")
            }
            
            if getTranscriptions().isEmpty {
                Button {
                    startTranscription()
                } label: {
                    Label("Trascrivi", systemImage: "text.quote")
                }
            }
            
            Button {
                shareRecording()
            } label: {
                Label("Condividi", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTranscriptions() -> [Trascrizione] {
        let transcriptions = recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
        return transcriptions.sorted { ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) }
    }
    
    private func startTranscription() {
        isTranscribing = true
        
        Task {
            do {
                _ = try await transcriptionService.transcribeRecording(recording)
            } catch {
                print("Errore trascrizione: \(error)")
            }
            
            await MainActor.run {
                isTranscribing = false
            }
        }
    }
    
    private func shareRecording() {
        guard let url = recording.pathFile else { return }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Data sconosciuta" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Filter

enum RecordingFilter: CaseIterable {
    case all
    case withTranscription
    case withoutTranscription
    case processing
    case completed
    
    var title: String {
        switch self {
        case .all: return "Tutte"
        case .withTranscription: return "Con Trascrizione"
        case .withoutTranscription: return "Senza Trascrizione"
        case .processing: return "In Elaborazione"
        case .completed: return "Completate"
        }
    }
}

// MARK: - Audio Player

@MainActor
class AudioPlayer: NSObject, ObservableObject, @preconcurrency AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentRecording: RegistrazioneAudio?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func play(recording: RegistrazioneAudio) {
        print("🎵 AudioPlayer: Tentativo di riproduzione per registrazione: \(recording.titolo ?? "Senza titolo")")
        print("🎵 AudioPlayer: ID registrazione: \(recording.id?.uuidString ?? "nil")")
        
        guard let url = recording.pathFile else { 
            print("❌ AudioPlayer: URL del file audio è nil")
            return 
        }
        
        print("🎵 AudioPlayer: URL del file: \(url)")
        print("🎵 AudioPlayer: URL absoluteString: \(url.absoluteString)")
        print("🎵 AudioPlayer: URL path: \(url.path)")
        print("🎵 AudioPlayer: File esiste: \(FileManager.default.fileExists(atPath: url.path))")
        
        // Controlla se il file esiste fisicamente
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        if !fileExists {
            print("❌ AudioPlayer: File non esiste fisicamente!")
            
            // Prova a cercare il file in altre posizioni
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            print("🎵 AudioPlayer: Documents path: \(documentsPath?.path ?? "nil")")
            
            // Lista tutti i file .m4a nella directory Documents
            if let documentsPath = documentsPath {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                    let audioFiles = files.filter { $0.pathExtension == "m4a" }
                    print("🎵 AudioPlayer: File audio trovati in Documents: \(audioFiles.map { $0.lastPathComponent })")
                } catch {
                    print("❌ AudioPlayer: Errore nel leggere directory Documents: \(error)")
                }
            }
            return
        }
        
        // Controlla le dimensioni del file
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("🎵 AudioPlayer: Dimensione file: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ AudioPlayer: File vuoto!")
                return
            }
        } catch {
            print("❌ AudioPlayer: Errore nel leggere attributi file: \(error)")
        }
        
        // IMPORTANTE: Su dispositivo fisico, configura la sessione audio PRIMA di tutto
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Disattiva prima la sessione corrente
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Configura per riproduzione con opzioni specifiche per dispositivo fisico
                            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("✅ AudioPlayer: Sessione audio configurata per riproduzione")
        } catch {
            print("❌ AudioPlayer: Errore configurazione sessione audio: \(error)")
            return
        }
        
        // IMPORTANTE: Crea l'AVAudioPlayer DOPO aver configurato la sessione
        do {
            // Usa URL diretto invece di path per evitare problemi su dispositivo fisico
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            
            print("🎵 AudioPlayer: Durata file: \(audioPlayer.duration) secondi")
            print("🎵 AudioPlayer: Formato audio: \(audioPlayer.format)")
            print("🎵 AudioPlayer: Numero canali: \(audioPlayer.numberOfChannels)")
            
            if audioPlayer.duration == 0 {
                print("❌ AudioPlayer: Durata file è 0!")
                return
            }
            
            let success = audioPlayer.play()
            print("🎵 AudioPlayer: Tentativo di riproduzione: \(success)")
            
            if success {
                self.audioPlayer = audioPlayer
                isPlaying = true
                currentRecording = recording
                duration = audioPlayer.duration
                currentTime = 0
                
                // Avvia timer per aggiornare il tempo
                startTimer()
                
                print("✅ AudioPlayer: Riproduzione avviata con successo")
            } else {
                print("❌ AudioPlayer: Impossibile avviare la riproduzione")
            }
            
        } catch {
            print("❌ AudioPlayer: Errore nella riproduzione: \(error)")
            print("❌ AudioPlayer: Error description: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        print("⏸️ AudioPlayer: Pausa")
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        print("🛑 AudioPlayer: Fermando riproduzione...")
        
        timer?.invalidate()
        timer = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        isPlaying = false
        currentTime = 0
        currentRecording = nil
        
        // Disattiva la sessione audio
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ AudioPlayer: Sessione audio disattivata")
        } catch {
            print("❌ AudioPlayer: Errore disattivazione sessione audio: \(error)")
        }
        
        print("✅ AudioPlayer: Riproduzione fermata")
    }
    
    func seek(to time: TimeInterval) {
        print("⏭️ AudioPlayer: Seek a \(time) secondi")
        guard let audioPlayer = audioPlayer else { return }
        
        audioPlayer.currentTime = max(0, min(time, duration))
        currentTime = audioPlayer.currentTime
        
        print("✅ AudioPlayer: Seek completato a \(audioPlayer.currentTime) secondi")
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
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🏁 AudioPlayer: Riproduzione completata, successo: \(flag)")
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            currentRecording = nil
            stopTimer()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ AudioPlayer: Errore di decodifica: \(error?.localizedDescription ?? "Unknown")")
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            currentRecording = nil
            stopTimer()
        }
    }
}

// MARK: - Glassmorphism Button View

struct GlassmorphismRecordButton: View {
    let isRecording: Bool
    let audioLevel: Float // 0.0 - 1.0
    let action: () -> Void
    
    var body: some View {
        ZStack {
            // Animazione differenziata per versione iOS
            if #available(iOS 26.0, *) {
                // Versione iOS 26+: Animazione liquida più complessa
                liquidAnimationView(level: audioLevel, isRecording: isRecording)
            } else {
                // Versione iOS 18-25: Animazione a anelli con blur
                legacyAnimationView(level: audioLevel, isRecording: isRecording)
            }

            // Pulsante principale, comune a entrambe le versioni
            mainButton()
        }
    }
    
    // MARK: - Viste di Animazione
    
    /// Animazione per iOS 18-25 basata su anelli e blur.
    @ViewBuilder
    private func legacyAnimationView(level: Float, isRecording: Bool) -> some View {
        if isRecording {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.red.opacity(0.6), .purple.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 130, height: 130)
                        .scaleEffect(1 + (CGFloat(level) * (0.4 + CGFloat(i) * 0.2)))
                        .opacity(1 - (CGFloat(level) * 0.5))
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.2)
                            .delay(Double(i) * 0.05),
                            value: level
                        )
                }
            }
            .blur(radius: 10)
        }
    }
    
    /// Animazione per iOS 26+ con effetto "liquid glass" più avanzato.
    @available(iOS 26.0, *)
    @ViewBuilder
    private func liquidAnimationView(level: Float, isRecording: Bool) -> some View {
        if isRecording {
            // Semplifichiamo la vista per evitare l'errore di type-checking
            // Usiamo un singolo cerchio con un gradiente e un'animazione complessa
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0.7), .purple.opacity(0.5), .red.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 150)
                .scaleEffect(1 + CGFloat(level) * 0.5)
                .blur(radius: 15 + CGFloat(level) * 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0.3), value: level)
        }
    }
    
    // MARK: - Pulsante Principale
    
    @ViewBuilder
    private func mainButton() -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.6) : Color.accentColor.opacity(0.6))
                    )
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 120, height: 120)
    }
}
