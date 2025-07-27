import SwiftUI
import AVFoundation
import CoreData
import UIKit

struct AudioRecorderView: View {
    @ObservedObject var recordingService: RecordingService
    @State private var isAnimatingButton = false
    @State private var pulseAnimation = false
    @State private var rotationAngle: Double = 0
    @State private var showWaveform = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Modern background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    Spacer()
                    
                    // Main recording interface
                    recordingInterface
                        .frame(height: geometry.size.height * 0.6)
                    
                    Spacer()
                    
                    // Status and info
                    statusInfoView
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .onAppear {
            print("✅ AudioRecorderView caricata")
        }
        .onChange(of: recordingService.recordingState) { oldState, newState in
            handleRecordingStateChange(newState)
        }
    }
    
    // MARK: - Recording State Management
    
    private func handleRecordingStateChange(_ newState: RecordingState) {
        switch newState {
        case .recording:
            startRecordingTimer()
            pulseAnimation = true
            rotationAngle = 360
        case .idle, .completed, .error:
            stopRecordingTimer()
            pulseAnimation = false
            rotationAngle = 0
            recordingDuration = 0
        case .processing:
            stopRecordingTimer()
            pulseAnimation = false
            rotationAngle = 0
        }
    }
    
    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Modern status indicator only
            statusIndicator
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusDotColor.opacity(0.2))
                    .frame(width: 20, height: 20)
                
            Circle()
                .fill(statusDotColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            
            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Recording Interface
    
    private var recordingInterface: some View {
        VStack(spacing: 40) {
            // Waveform visualization
            if showWaveform {
                waveformView
            }
            
            // Main record button
            recordButtonView
            
            // Recording timer (when recording) - POSIZIONATO FUORI DAL PULSANTE
            if case .recording = recordingService.recordingState {
                recordingTimerView
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var waveformView: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3, height: CGFloat.random(in: 10...60))
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(index) * 0.1), value: showWaveform)
            }
        }
        .frame(height: 80)
        .onAppear {
            showWaveform = true
        }
    }
    
    private var recordButtonView: some View {
        ZStack {
            if #available(iOS 26.0, *) {
                // Nuovo design iOS 26+ con Liquid Glass avanzato e animazioni ritmiche
                advancedLiquidGlassRecordButton
            } else {
                // Design migliorato per iOS 18+ con animazioni ritmiche
                improvedLegacyRecordButton
            }
        }
    }
    
    // MARK: - Advanced Liquid Glass Record Button (iOS 26+)
    
    @available(iOS 26.0, *)
    private var advancedLiquidGlassRecordButton: some View {
        ZStack {
            // Container principale con effetto Liquid Glass massima trasparenza
            GlassEffectContainer {
                VStack(spacing: 0) {
                    // Area principale del pulsante
                    Button(action: {
                        handleRecordButtonTap()
                    }) {
                        ZStack {
                            // Sfondo principale con effetto vetro massima trasparenza
                            Circle()
                                .fill(.clear)
                                .frame(width: 160, height: 160)
                                .glassEffect(.regular.tint(.white.opacity(0.3)).interactive())
                                .overlay(
                                    // Contorno animato durante la registrazione
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    recordingService.recordingState == .recording ? 
                                                        Color.red.opacity(0.6) : Color.blue.opacity(0.6),
                                                    recordingService.recordingState == .recording ? 
                                                        Color.orange.opacity(0.4) : Color.purple.opacity(0.4)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                        .scaleEffect(recordingService.recordingState == .recording ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: recordingService.recordingState == .recording)
                                )
                            
                            // Icona principale con animazioni ritmiche - più visibile (DENTRO il pulsante)
                            Image(systemName: recordingService.recordingState == .recording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 70, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                                .scaleEffect(1.0 + CGFloat(recordingService.currentAudioLevel) * 0.3)
                                .rotationEffect(.degrees(Double(recordingService.currentAudioLevel) * 5))
                                .animation(.easeInOut(duration: 0.1), value: recordingService.currentAudioLevel)
                                .zIndex(1) // Porta l'icona davanti
                        }
                    }
                    .scaleEffect(isAnimatingButton ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimatingButton)
                }
            }
        }
    }
    
    // MARK: - Improved Legacy Record Button (iOS 18+)
    
    private var improvedLegacyRecordButton: some View {
        ZStack {
            // Sfondo con glassmorphism avanzato
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.systemBackground).opacity(0.8),
                            Color(.systemGray6).opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)
                .overlay(
                    // Contorno animato durante la registrazione
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    recordingService.recordingState == .recording ? 
                                        Color.red.opacity(0.6) : Color.blue.opacity(0.6),
                                    recordingService.recordingState == .recording ? 
                                        Color.orange.opacity(0.4) : Color.purple.opacity(0.4)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .scaleEffect(recordingService.recordingState == .recording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: recordingService.recordingState == .recording)
                )
                .shadow(
                    color: recordingService.recordingState == .recording ? 
                        Color.red.opacity(0.4) : Color.blue.opacity(0.4),
                    radius: 25,
                    x: 0,
                    y: 12
                )
            
            // Icona principale con animazioni ritmiche - più visibile (DENTRO il pulsante)
            Image(systemName: recordingService.recordingState == .recording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 70, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                .scaleEffect(1.0 + CGFloat(recordingService.currentAudioLevel) * 0.3)
                .rotationEffect(.degrees(Double(recordingService.currentAudioLevel) * 5))
                .animation(.easeInOut(duration: 0.1), value: recordingService.currentAudioLevel)
                .zIndex(1) // Porta l'icona davanti
        }
        .scaleEffect(isAnimatingButton ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimatingButton)
        .onTapGesture {
            handleRecordButtonTap()
        }
    }
    
    // MARK: - Recording Timer View
    
    private var recordingTimerView: some View {
        VStack(spacing: 12) {
            // Timer principale più prominente
            VStack(spacing: 4) {
                Text(formatDuration(recordingDuration))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                
                Text("Tempo di registrazione")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4))
                    .glassEffect(.regular.tint(.white.opacity(0.2)))
            )
            .scaleEffect(1.0 + CGFloat(recordingService.currentAudioLevel) * 0.05)
            .animation(.easeInOut(duration: 0.1), value: recordingService.currentAudioLevel)
            
            // Indicatore di stato con animazione
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Text("Registrazione in corso")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
                
                // Indicatore di volume
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.white.opacity(0.8))
                            .frame(width: 2, height: CGFloat(8 + Int(recordingService.currentAudioLevel * 20) * (index + 1)))
                            .animation(.easeInOut(duration: 0.1), value: recordingService.currentAudioLevel)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.3))
            )
        }
        .padding(.top, 20)
    }
    

    
    // MARK: - Status Info View
    
    private var statusInfoView: some View {
        VStack(spacing: 20) {
            // Quick stats - only recordings count
            HStack(spacing: 30) {
                statItem(icon: "waveform", title: "Registrazioni", value: "\(recordingService.getRecordings().count)")
                
                // Permission status as interactive button
                permissionStatusButton
            }
            
            // Instructions
            if case .idle = recordingService.recordingState {
                instructionView
            }
        }
    }
    
    private func statItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var instructionView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
            Text("Tocca il pulsante per iniziare")
                .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Text("Tocca di nuovo per fermare")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.1),
                            Color.purple.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Permission Status Button
    
    private var permissionStatusButton: some View {
        Button(action: {
            // Open settings to manage permissions
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    recordingService.isPermissionGranted ? .green.opacity(0.1) : .orange.opacity(0.1),
                                    recordingService.isPermissionGranted ? .green.opacity(0.05) : .orange.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: recordingService.isPermissionGranted ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .font(.title2)
                        .foregroundColor(recordingService.isPermissionGranted ? .green : .orange)
                }
                
                Text(recordingService.isPermissionGranted ? "Concesso" : "Richiesto")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Permessi")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        switch recordingService.recordingState {
        case .idle:
            return "Pronto per registrare"
        case .recording:
            return "Registrazione in corso"
        case .processing:
            return "Finalizzazione..."
        case .completed:
            return "Completato!"
        case .error(let message):
            return "Errore: \(message)"
        }
    }
    
    private var statusColor: Color {
        switch recordingService.recordingState {
        case .idle:
            return .primary
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusDotColor: Color {
        switch recordingService.recordingState {
        case .idle:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    private var buttonColor: Color {
        switch recordingService.recordingState {
        case .idle:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .gray
        }
    }
    
    private var buttonIcon: String {
        switch recordingService.recordingState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    // MARK: - Actions
    
    private func handleRecordButtonTap() {
        print("🎛️ handleRecordButtonTap called")
        print("🎛️ Current state: \(recordingService.recordingState)")
        
        // Animate button
        withAnimation(.easeInOut(duration: 0.1)) {
            isAnimatingButton = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isAnimatingButton = false
        }
        
        // Handle recording logic
        switch recordingService.recordingState {
        case .idle:
            print("🎙️ Starting recording...")
            recordingService.startRecording()
            
        case .recording:
            print("🛑 Stopping recording...")
            recordingService.stopRecording()
            
        case .processing:
            print("⏳ Already processing...")
            
        case .completed:
            print("✅ Recording completed, resetting...")
            recordingService.recordingState = .idle
            
        case .error:
            print("❌ Error state, resetting...")
            recordingService.recordingState = .idle
        }
    }
}

#Preview {
    AudioRecorderView(recordingService: RecordingService(context: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
