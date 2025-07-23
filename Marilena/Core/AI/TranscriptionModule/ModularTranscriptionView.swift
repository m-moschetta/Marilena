import SwiftUI
import AVFoundation

// MARK: - Modular Transcription View
// Vista di trascrizione modulare e riutilizzabile

public struct ModularTranscriptionView: View {
    @StateObject private var transcriptionService: ModularTranscriptionService
    @State private var selectedMode: ModularTranscriptionMode = .auto
    @State private var selectedLanguage = "it-IT"
    @State private var showingModeSelection = false
    @State private var showingSettings = false
    @State private var audioURL: URL?
    
    // MARK: - Configuration
    private let title: String
    private let showSettings: Bool
    private let customConfiguration: ModularTranscriptionConfiguration?
    
    // MARK: - Initialization
    
    public init(
        title: String = "Trascrizione Audio",
        configuration: ModularTranscriptionConfiguration? = nil,
        showSettings: Bool = true
    ) {
        self.title = title
        self.customConfiguration = configuration
        self.showSettings = showSettings
        
        let config = configuration ?? ModularTranscriptionConfiguration()
        self._transcriptionService = StateObject(wrappedValue: ModularTranscriptionService())
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            contentView
            
            // Controls
            controlsView
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if showSettings {
                    settingsButton
                }
            }
        }
        .sheet(isPresented: $showingModeSelection) {
            ModularTranscriptionModeSelectionView(
                selectedMode: $selectedMode,
                selectedLanguage: $selectedLanguage,
                onTranscribe: startTranscription
            )
        }
        .sheet(isPresented: $showingSettings) {
            ModularTranscriptionSettingsView(transcriptionService: transcriptionService)
        }
        .onAppear {
            transcriptionService.requestPermissions()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 8) {
            if let session = transcriptionService.currentSession {
                switch session.state {
                case .error(let error):
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                case .processing:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Trascrizione in corso...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                case .completed:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Trascrizione completata")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                case .idle:
                    EmptyView()
                }
            }
            
            if transcriptionService.currentProgress > 0 && transcriptionService.currentProgress < 1 {
                ProgressView(value: transcriptionService.currentProgress)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let session = transcriptionService.currentSession,
                   let result = session.result {
                    // Result View
                    ModularTranscriptionResultView(result: result)
                } else if transcriptionService.volatileText.isNotEmpty {
                    // Volatile Text View
                    ModularTranscriptionVolatileView(text: transcriptionService.volatileText)
                } else {
                    // Empty State
                    emptyStateView
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Controls View
    
    private var controlsView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                // Mode Selection Button
                Button(action: { showingModeSelection = true }) {
                    HStack {
                        Image(systemName: selectedMode.icon)
                            .foregroundColor(.blue)
                        Text(selectedMode.displayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .disabled(transcriptionService.currentSession?.isProcessing == true)
                
                // Transcribe Button
                Button(action: startTranscription) {
                    HStack {
                        if transcriptionService.currentSession?.isProcessing == true {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "waveform")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text("Trascrivi")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        transcriptionService.currentSession?.isProcessing == true ? 
                        Color.gray : Color.blue
                    )
                    .cornerRadius(12)
                }
                .disabled(transcriptionService.currentSession?.isProcessing == true || audioURL == nil)
            }
            .padding()
        }
    }
    
    // MARK: - Settings Button
    
    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Nessuna Trascrizione")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Seleziona un file audio e avvia la trascrizione per convertire l'audio in testo.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Seleziona Audio") {
                selectAudioFile()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func startTranscription() {
        guard let url = audioURL else { return }
        
        let configuration = ModularTranscriptionConfiguration(
            mode: selectedMode,
            language: selectedLanguage
        )
        
        Task {
            do {
                _ = try await transcriptionService.transcribeAudio(url: url, configuration: configuration)
            } catch {
                print("❌ Errore trascrizione: \(error)")
            }
        }
    }
    
    private func selectAudioFile() {
        // Implementazione selezione file audio
        // Per ora placeholder
        print("📁 Seleziona file audio")
    }
}

// MARK: - Transcription Result View

struct ModularTranscriptionResultView: View {
    let result: ModularTranscriptionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Risultato Trascrizione")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label(result.framework.displayName, systemImage: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", result.confidence * 100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: copyText) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
            }
            
            // Stats
            HStack(spacing: 16) {
                StatItem(title: "Parole", value: "\(result.wordCount)")
                StatItem(title: "Durata", value: String(format: "%.1fs", result.duration))
                StatItem(title: "Lingua", value: result.detectedLanguage)
            }
            
            // Text
            Text(result.text)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func copyText() {
        UIPasteboard.general.string = result.text
    }
}

// MARK: - Transcription Volatile View

struct ModularTranscriptionVolatileView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trascrizione in corso...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                ModularTranscriptionTypingIndicatorView()
            }
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Transcription Typing Indicator

struct ModularTranscriptionTypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
                    .scaleEffect(1.0 + animationOffset)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = 0.3
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Transcription Mode Selection View

struct ModularTranscriptionModeSelectionView: View {
    @Binding var selectedMode: ModularTranscriptionMode
    @Binding var selectedLanguage: String
    let onTranscribe: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let modes: [ModularTranscriptionMode] = [
        .auto, .speechAnalyzer, .speechFramework, .whisper, .local
    ]
    
    private let languages = [
        ("it-IT", "Italiano", "🇮🇹"),
        ("en-US", "English", "🇺🇸"),
        ("es-ES", "Español", "🇪🇸"),
        ("fr-FR", "Français", "🇫🇷"),
        ("de-DE", "Deutsch", "🇩🇪"),
        ("pt-PT", "Português", "🇵🇹")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Modalità Trascrizione") {
                    ForEach(modes, id: \.self) { mode in
                        Button(action: { selectedMode = mode }) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section("Lingua") {
                    ForEach(languages, id: \.0) { code, name, flag in
                        Button(action: { selectedLanguage = code }) {
                            HStack {
                                Text(flag)
                                    .font(.title2)
                                
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedLanguage == code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Impostazioni Trascrizione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Transcription Settings View

struct ModularTranscriptionSettingsView: View {
    @ObservedObject var transcriptionService: ModularTranscriptionService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Statistiche") {
                    let stats = transcriptionService.getStats()
                    
                    HStack {
                        Text("Sessioni totali")
                        Spacer()
                        Text("\(stats.totalSessions)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Trascrizioni completate")
                        Spacer()
                        Text("\(stats.successfulTranscriptions)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Tempo medio elaborazione")
                        Spacer()
                        Text(String(format: "%.1fs", stats.averageProcessingTime))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Confidenza media")
                        Spacer()
                        Text(String(format: "%.1f%%", stats.averageConfidence * 100))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Framework più usato")
                        Spacer()
                        Text(stats.mostUsedFramework.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Parole totali")
                        Spacer()
                        Text("\(stats.totalWords)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Azioni") {
                    Button("Cancella sessioni", role: .destructive) {
                        transcriptionService.clearSessions()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Impostazioni Trascrizione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension String {
    var isNotEmpty: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ModularTranscriptionView(title: "Trascrizione Demo")
    }
} 