import Foundation
import AVFoundation
import CoreData

// MARK: - Notification Names
extension Notification.Name {
    static let recordingCreated = Notification.Name("recordingCreated")
    static let transcriptionCompleted = Notification.Name("transcriptionCompleted")
}
import CoreLocation
import Combine

class RecordingService: NSObject, ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var isPermissionGranted = false
    @Published var audioLevel: Float = 0.0 // Livello audio normalizzato (0-1)
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private var locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
    private let context: NSManagedObjectContext
    private let documentsDirectory: URL
    private var levelTimer: Timer?

    init(context: NSManagedObjectContext) {
        self.context = context
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        super.init()
        print("✅ RecordingService inizializzato")
        setupLocationManager()
        checkPermissions()
    }
    
    // MARK: - Public Methods
    
    func startRecording() {
        print("🎙️ START RECORDING CALLED")
        
        guard isPermissionGranted else {
            print("❌ NO PERMISSION")
            recordingState = .error("Permesso microfono negato")
            return
        }
        
        // 1. Setup audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            print("✅ Audio session configured")
        } catch {
            print("❌ Audio session error: \(error)")
            recordingState = .error("Errore configurazione audio")
            return
        }
        
        // 2. Create file URL
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        print("📁 File URL: \(fileURL.path)")
        
        // 3. Create Core Data record
        let recording = RegistrazioneAudio(context: context)
        recording.id = UUID()
        recording.dataCreazione = Date()
        recording.pathFile = fileURL
        recording.titolo = "Registrazione \(Date().formatted(date: .abbreviated, time: .shortened))"
        recording.statoElaborazione = "in_corso"
        
        do {
            try context.save()
            print("✅ Core Data record created")
        } catch {
            print("❌ Core Data error: \(error)")
            recordingState = .error("Errore salvataggio dati")
            return
        }
        
        // 4. Setup recorder
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            print("🎯 Record attempt: \(success)")
            
            if success {
                recordingState = .recording
                print("✅ Recording started successfully")
                startMonitoringLevels()
            } else {
                print("❌ Failed to start recording")
                recordingState = .error("Impossibile avviare registrazione")
                context.delete(recording)
                try? context.save()
            }
        } catch {
            print("❌ Recorder setup error: \(error)")
            recordingState = .error("Errore setup registratore")
            context.delete(recording)
            try? context.save()
        }
    }
    
    func stopRecording() {
        print("🛑 STOP RECORDING CALLED")
        
        guard let recorder = audioRecorder else {
            print("❌ No recorder to stop")
            return
        }
        
        recordingState = .processing
        
        let duration = recorder.currentTime
        print("⏱️ Recording duration: \(duration) seconds")
        
        recorder.stop()
        print("⏹️ Recorder stopped")
        
        // Wait a bit for file to be written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.finalizeRecording(duration: duration)
            self.stopMonitoringLevels()
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startMonitoringLevels() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.audioRecorder != nil else { return }
            self.audioRecorder?.updateMeters()
            
            // Calcola il livello di potenza e normalizzalo
            let peakPower = self.audioRecorder?.peakPower(forChannel: 0) ?? -160.0
            let normalizedLevel = self.normalizePowerLevel(peakPower)
            
            DispatchQueue.main.async {
                self.audioLevel = normalizedLevel
            }
        }
    }
    
    private func stopMonitoringLevels() {
        levelTimer?.invalidate()
        levelTimer = nil
        DispatchQueue.main.async {
            self.audioLevel = 0.0
        }
    }
    
    private func normalizePowerLevel(_ level: Float) -> Float {
        // I livelli di potenza sono in dB, da -160 (silenzio) a 0 (massimo).
        // Li normalizziamo in un range 0-1.
        let minDb: Float = -60.0 // Soglia minima per visualizzare qualcosa
        if level < minDb {
            return 0.0
        }
        return min((1.0 - (level / minDb)), 1.0)
    }

    // MARK: - Private Methods
    
    private func finalizeRecording(duration: TimeInterval) {
        print("🔧 RecordingService: Finalizing recording...")
        
        // Get the latest recording from Core Data
        let fetchRequest: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RegistrazioneAudio.dataCreazione, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let recordings = try context.fetch(fetchRequest)
            guard let recording = recordings.first else {
                print("❌ RecordingService: No recording found in Core Data")
                recordingState = .error("Registrazione non trovata")
                return
            }
            
            let filePath = recording.pathFile
            print("🔧 RecordingService: File path salvato in Core Data: \(filePath?.absoluteString ?? "nil")")
            print("🔧 RecordingService: File path: \(filePath?.path ?? "nil")")
            
            // Verifica se il file esiste fisicamente
            if let filePath = filePath {
                let fileExists = FileManager.default.fileExists(atPath: filePath.path)
                print("🔧 RecordingService: File esiste fisicamente: \(fileExists)")
                
                if fileExists {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: filePath.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        print("🔧 RecordingService: Dimensione file: \(fileSize) bytes")
                        
                        if fileSize == 0 {
                            print("❌ RecordingService: File salvato ma vuoto!")
                        } else {
                            print("✅ RecordingService: File salvato correttamente con dimensione: \(fileSize) bytes")
                        }
                    } catch {
                        print("❌ RecordingService: Errore nel leggere attributi file: \(error)")
                    }
                } else {
                    print("❌ RecordingService: File non esiste fisicamente!")
                    
                    // Lista tutti i file nella directory Documents
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    if let documentsPath = documentsPath {
                        do {
                            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                            let audioFiles = files.filter { $0.pathExtension == "m4a" }
                            print("🔧 RecordingService: File audio trovati in Documents: \(audioFiles.map { $0.lastPathComponent })")
                        } catch {
                            print("❌ RecordingService: Errore nel leggere directory Documents: \(error)")
                        }
                    }
                }
            }
            
            // Update recording with final duration
            recording.durata = duration
            recording.statoElaborazione = "completata"
            
            try context.save()
            print("✅ RecordingService: Recording finalized and saved to Core Data")
            recordingState = .completed
            
            // IMPORTANTE: Notifica l'aggiornamento delle registrazioni
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .recordingCreated, object: recording)
            }
            
        } catch {
            print("❌ RecordingService: Error finalizing recording: \(error)")
            recordingState = .error("Errore nel salvare la registrazione")
        }
    }
    
    private func checkPermissions() {
        let status = AVAudioSession.sharedInstance().recordPermission
        print("🔐 Permission status: \(status.rawValue)")
        
        switch status {
        case .granted:
            isPermissionGranted = true
            print("✅ Permission granted")
        case .denied:
            isPermissionGranted = false
            print("❌ Permission denied")
        case .undetermined:
            print("❓ Permission undetermined")
            requestPermission()
        @unknown default:
            isPermissionGranted = false
        }
    }
    
    private func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.isPermissionGranted = granted
                print("🔐 Permission request result: \(granted)")
            }
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func getRecordings() -> [RegistrazioneAudio] {
        let fetchRequest: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RegistrazioneAudio.dataCreazione, ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ Fetch error: \(error)")
            return []
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎵 Recorder delegate: finished with success = \(flag)")
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Recorder delegate error: \(error?.localizedDescription ?? "Unknown")")
        recordingState = .error("Errore durante registrazione")
    }
}

// MARK: - CLLocationManagerDelegate

extension RecordingService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("⚠️ Location permission denied")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - RecordingState

enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case completed
    case error(String)
    
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.recording, .recording):
            return true
        case (.processing, .processing):
            return true
        case (.completed, .completed):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
} 
