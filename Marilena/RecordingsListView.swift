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
    
    @StateObject private var transcriptionService: SpeechTranscriptionService
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var searchText = ""
    @State private var selectedFilter: RecordingFilter = .all
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: RegistrazioneAudio?
    @State private var selectedRecording: RegistrazioneAudio?
    
    init(context: NSManagedObjectContext) {
        self._transcriptionService = StateObject(wrappedValue: SpeechTranscriptionService(context: context))
    }
    
    var body: some View {
        VStack {
            // Filtri e ricerca
            filterBarView
            
            // Lista registrazioni
            recordingsListView
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Ordina per Data") {
                        // Implementa ordinamento
                    }
                    Button("Ordina per Durata") {
                        // Implementa ordinamento  
                    }
                    Button("Ordina per Nome") {
                        // Implementa ordinamento
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recording: recording, context: viewContext)
        }
        .alert("Elimina Registrazione", isPresented: $showingDeleteAlert) {
            Button("Elimina", role: .destructive) {
                if let recording = recordingToDelete {
                    deleteRecording(recording)
                }
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Questa azione non può essere annullata. Verranno eliminate anche tutte le trascrizioni associate.")
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBarView: some View {
        VStack(spacing: 12) {
            // Barra di ricerca
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filtri
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
        }
        .padding()
    }
    
    // MARK: - Recordings List
    
    private var recordingsListView: some View {
        List {
            ForEach(filteredRecordings, id: \.objectID) { recording in
                RecordingRowView(
                    recording: recording,
                    audioPlayer: audioPlayer,
                    transcriptionService: transcriptionService
                ) {
                    selectedRecording = recording
                } onDelete: {
                    recordingToDelete = recording
                    showingDeleteAlert = true
                }
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.insetGrouped)
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
                    .font(.caption.weight(.medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.primary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct RecordingRowView: View {
    let recording: RegistrazioneAudio
    let audioPlayer: AudioPlayer
    let transcriptionService: SpeechTranscriptionService
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isTranscribing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header con titolo e data
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.titolo ?? "Senza titolo")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatDate(recording.dataCreazione))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Stato elaborazione
                StatusBadge(stato: recording.statoElaborazione ?? "sconosciuto")
            }
            
            // Informazioni registrazione
            HStack(spacing: 16) {
                InfoItem(
                    icon: "clock.fill",
                    text: formatDuration(recording.durata),
                    color: .blue
                )
                
                InfoItem(
                    icon: "waveform",
                    text: recording.qualitaAudio?.capitalized ?? "Media",
                    color: .green
                )
                
                InfoItem(
                    icon: "globe",
                    text: recording.linguaPrincipale?.uppercased() ?? "IT",
                    color: .orange
                )
                
                Spacer()
            }
            
            // Trascrizioni e controlli
            transcriptionInfoView
            
            // Controlli audio
            audioControlsView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onTapGesture {
            onTap()
        }
        .contextMenu {
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
    
    private var transcriptionInfoView: some View {
        let transcriptions = getTranscriptions()
        
        return HStack {
            if transcriptions.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.gray)
                    Text("Nessuna trascrizione")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if isTranscribing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Trascrivi") {
                            startTranscription()
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(transcriptions.count) trascrizione\(transcriptions.count > 1 ? "i" : "")")
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        if let latest = transcriptions.first {
                            Text("\(latest.paroleTotali) parole • \(Int(latest.accuratezza * 100))% accuratezza")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var audioControlsView: some View {
        HStack(spacing: 16) {
            // Play/Pause
            Button {
                if audioPlayer.isPlaying && audioPlayer.currentRecording == recording {
                    audioPlayer.pause()
                } else {
                    audioPlayer.play(recording: recording)
                }
            } label: {
                Image(systemName: audioPlayer.isPlaying && audioPlayer.currentRecording == recording ? "pause.fill" : "play.fill")
                    .foregroundColor(.blue)
            }
            
            // Progress bar
            if audioPlayer.currentRecording == recording {
                VStack(spacing: 4) {
                    ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text(formatDuration(audioPlayer.currentTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatDuration(audioPlayer.duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                    
                    Text(formatDuration(recording.durata))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct StatusBadge: View {
    let stato: String
    
    var body: some View {
        Text(stato.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch stato {
        case "completata": return .green.opacity(0.2)
        case "in_elaborazione": return .blue.opacity(0.2)
        case "errore": return .red.opacity(0.2)
        default: return .gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch stato {
        case "completata": return .green
        case "in_elaborazione": return .blue
        case "errore": return .red
        default: return .gray
        }
    }
}

struct InfoItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Types

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
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker])
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
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🏁 AudioPlayer: Riproduzione completata, successo: \(flag)")
        isPlaying = false
        currentTime = 0
        currentRecording = nil
        stopTimer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ AudioPlayer: Errore di decodifica: \(error?.localizedDescription ?? "Unknown")")
        isPlaying = false
        currentTime = 0
        currentRecording = nil
        stopTimer()
    }
}
