import SwiftUI
// PERF: Caricamenti di liste grandi: valutare `@FetchRequest` con limiti/paginazione e prefetch per ridurre memoria.
// PERF: Evitare lavoro pesante in `onAppear` di ogni cella; usare immagini/audio downsampled.
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
            // Contenuto principale (stesso pattern di ChatsListView)
            NavigationStack {
                VStack(spacing: 0) {
                    if filteredRecordings.isEmpty {
                        // Stato vuoto centrato verticalmente
                        VStack(spacing: 0) {
                            filtersHeaderView
                            Spacer()
                            emptyStateView
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                    } else {
                        List {
                            // Filtri come Section header
                            Section {
                                // Spazio vuoto per i filtri
                            } header: {
                                filtersHeaderView
                            }

                            // Registrazioni
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

                            // Spazio extra per permettere scroll sotto il pulsante flottante
                            if !hideRecordButton {
                                Spacer()
                                    .frame(height: 120)
                            }
                        }
                        .listStyle(.plain)
                        .environment(\.defaultMinListRowHeight, 60)
                        .refreshable {
                            // Aggiorna dati se necessario
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Cerca registrazioni...")
            }
            
            // Bottone centrale glassmorphism compatibile iOS 18+ (solo se non nascosto)
            if !hideRecordButton {
                VStack {
                    Spacer()
                    GlassmorphismRecordButton(
                        isRecording: recordingService.recordingState == .recording,
                        action: {
                            withAnimation(.spring()) {
                                if recordingService.recordingState == .recording {
                                    recordingService.stopRecording()
                                } else {
                                    recordingService.startRecording()
                                }
                            }
                        },
                        recordingService: recordingService
                    )
                    .padding(.bottom, 80) // Poco sopra la tab registratore
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
            PerformanceSignpost.event("RecordingsListAppear")
        }
    }
    
    // MARK: - Filters Header View
    
    private var filtersHeaderView: some View {
        VStack(spacing: 8) {
            // Filtri per tipo di registrazione
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
        .padding(.top, 8)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Icona moderna con gradiente
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "waveform")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 12) {
                Text("Nessuna registrazione")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("Inizia a registrare per vedere le tue registrazioni qui!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
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
    @ObservedObject var recordingService: RecordingService
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isPressed: Bool = false
    
    var body: some View {
        ZStack {
            // Timer flottante sopra il pulsante (solo durante registrazione)
            if isRecording {
                recordingTimerView
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                    .zIndex(2)
            }
            
            // Pulsante flottante principale
            floatingRecordButton
                .zIndex(1)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    // MARK: - Floating Record Button
    
    private var floatingRecordButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
            }
        }) {
            ZStack {
                // Sfondo principale con glassmorphism
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground).opacity(0.95),
                                Color(.systemGray6).opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        // Contorno animato
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isRecording ? Color.red.opacity(0.8) : Color.blue.opacity(0.8),
                                        isRecording ? Color.orange.opacity(0.6) : Color.purple.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .scaleEffect(isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isRecording)
                    )
                    .shadow(
                        color: isRecording ? Color.red.opacity(0.4) : Color.blue.opacity(0.4),
                        radius: 15,
                        x: 0,
                        y: 8
                    )
                
                // Icona principale
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Recording Timer View
    
    private var recordingTimerView: some View {
        VStack(spacing: 8) {
            // Timer principale
            Text(formatDuration(recordingDuration))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
            
            // Indicatore di stato
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
                
                Text("Registrazione")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .offset(y: 60) // Posizionato sotto il pulsante
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        if isRecording {
            recordingDuration = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                recordingDuration += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingDuration = 0
    }
    
    // MARK: - Format Duration
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
