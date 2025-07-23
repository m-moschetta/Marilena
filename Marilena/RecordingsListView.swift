import SwiftUI
import CoreData
import AVFoundation
import Combine
import SwiftUI

struct RecordingsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RegistrazioneAudio.dataCreazione, ascending: false)],
        animation: .default
    ) private var recordings: FetchedResults<RegistrazioneAudio>
    
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
    let hideRecordButton: Bool
    
    init(context: NSManagedObjectContext, recordingService: RecordingService, hideRecordButton: Bool = false) {
        self._transcriptionService = StateObject(wrappedValue: SpeechTranscriptionService(context: context))
        self.recordingService = recordingService
        self.hideRecordButton = hideRecordButton
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header minimale
                headerView
                
                // Spazio tra filtri e lista
                Spacer()
                    .frame(height: 16)
                
                // Lista registrazioni semplificata
                recordingsListView
            }
            // Bottone centrale glassmorphism compatibile iOS 18+ (solo se non nascosto)
            if !hideRecordButton {
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
                            GlassmorphismRecordButton(isRecording: recordingService.recordingState == .recording) {
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
    
    // MARK: - Recordings List
    
    private var recordingsListView: some View {
        List {
            ForEach(filteredRecordings, id: \.objectID) { recording in
                MinimalRecordingRowView(
                    recording: recording,
                    audioPlayer: audioPlayer,
                    transcriptionService: transcriptionService
                ) {
                    selectedRecording = recording
                } onDelete: {
                    recordingToDelete = recording
                    showingDeleteAlert = true
                } onRename: {
                    startEditingName(for: recording)
                }
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.plain)
        .refreshable {
            // Aggiorna dati se necessario
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
    let audioPlayer: AudioPlayer
    let transcriptionService: SpeechTranscriptionService
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    
    @State private var isTranscribing = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Play button
            Button {
                if audioPlayer.isPlaying && audioPlayer.currentRecording == recording {
                    audioPlayer.pause()
                } else {
                    audioPlayer.play(recording: recording)
                }
            } label: {
                Image(systemName: audioPlayer.isPlaying && audioPlayer.currentRecording == recording ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.titolo ?? "Senza titolo")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(formatDate(recording.dataCreazione))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Transcription preview se disponibile
                if let transcription = getTranscriptions().first,
                   let text = transcription.testoCompleto,
                   !text.isEmpty {
                    Text(text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(recording.durata))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
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
                onTap()
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
@preconcurrency
class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
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
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 26.0, *) {
            // Versione iOS 26+ con Liquid Glass
            Button(action: action) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                    .padding(8)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
        } else {
            // Fallback per iOS 18.6-25.x
            Button(action: action) {
                ZStack {
                    // Background con blur effect per liquid glass
                    RoundedRectangle(cornerRadius: 50)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 50)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                        .overlay(
                            // Contorno blu trasparente
                            RoundedRectangle(cornerRadius: 50)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.accentColor.opacity(0.6),
                                            Color.accentColor.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: isRecording ? 
                                Color.red.opacity(0.3) : Color.accentColor.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                    
                    // Icona
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .frame(width: 120, height: 120)
            }
        }
    }
}
