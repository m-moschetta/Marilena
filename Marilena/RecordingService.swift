import Foundation
import AVFoundation
import CoreData
import CoreLocation
import Combine

class RecordingService: NSObject, ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var isPermissionGranted = false
    @Published var currentAudioLevel: Float = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private var locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var audioLevelTimer: Timer?

    private let context: NSManagedObjectContext
    private let documentsDirectory: URL

    // MARK: - Calendar Integration Properties

    /// Riferimento al CalendarManager per il collegamento con eventi
    private weak var calendarManager: CalendarManager?
    
    init(context: NSManagedObjectContext, calendarManager: CalendarManager? = nil) {
        self.context = context
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.calendarManager = calendarManager
        super.init()
        print("✅ RecordingService inizializzato")
        setupLocationManager()
        checkPermissions()
    }

    /// Imposta il riferimento al CalendarManager per il collegamento eventi
    func setCalendarManager(_ manager: CalendarManager) {
        self.calendarManager = manager
        print("📅 CalendarManager collegato a RecordingService")
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        currentAudioLevel = 0.0
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Converti da dB a valore normalizzato (0.0 - 1.0)
        // Il range tipico è da -160 dB (silenzio) a 0 dB (massimo)
        let normalizedLevel = max(0.0, (averagePower + 160.0) / 160.0)
        currentAudioLevel = Float(normalizedLevel)
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
        recording.statoElaborazione = "in_corso"

        // 4. Link to current calendar event if available
        let (eventTitle, eventAttendees) = getCurrentEventInfo()
        recording.titolo = eventTitle ?? "Registrazione \(Date().formatted(date: .abbreviated, time: .shortened))"

        // 5. Store event attendees in linguaPrincipale field if available (temporary solution)
        if let attendees = eventAttendees, !attendees.isEmpty {
            recording.linguaPrincipale = formatAttendeesForNotes(attendees)
        }
        
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
                startAudioLevelMonitoring() // Avvia il timer per il monitoraggio del livello audio
                print("✅ Recording started successfully")
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
        
        let duration = recorder.currentTime
        print("⏱️ Recording duration: \(duration) seconds")
        
        recorder.stop()
        recordingState = .processing
        stopAudioLevelMonitoring() // Ferma il timer del livello audio
        
        print("⏹️ Recorder stopped")
        
        // Wait a bit for file to be written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.finalizeRecording(duration: duration)
        }
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
            
        } catch {
            print("❌ RecordingService: Error finalizing recording: \(error)")
            recordingState = .error("Errore nel salvare la registrazione")
        }
    }
    
    private func checkPermissions() {
        // Supporto per iOS 17+ con fallback per versioni precedenti
        if #available(iOS 17.0, *) {
            let status = AVAudioSession.sharedInstance().recordPermission
            print("🔐 Permission status (iOS 17+): \(status.rawValue)")
            
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
        } else {
            // Fallback per iOS < 17
            let status = AVAudioSession.sharedInstance().recordPermission
            print("🔐 Permission status (iOS < 17): \(status.rawValue)")
            
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
    }
    
    private func requestPermission() {
        if #available(iOS 17.0, *) {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isPermissionGranted = granted
                    print("🔐 Permission request result (iOS 17+): \(granted)")
                }
            }
        } else {
            // Fallback per iOS < 17
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isPermissionGranted = granted
                    print("🔐 Permission request result (iOS < 17): \(granted)")
                }
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

    // MARK: - Calendar Integration Methods

    /// Ottiene informazioni sull'evento corrente per collegarlo alla registrazione
    private func getCurrentEventInfo() -> (title: String?, attendees: [String]?) {
        guard let calendarManager = calendarManager else {
            print("📅 Nessun CalendarManager collegato")
            return (nil, nil)
        }

        // Trova eventi in corso nel momento attuale
        let currentEvents = calendarManager.currentEvents

        if currentEvents.isEmpty {
            print("📅 Nessun evento in corso trovato")
            return (nil, nil)
        }

        // Se c'è più di un evento in corso, prendi il primo
        let currentEvent = currentEvents.first!
        print("📅 Evento corrente trovato: \(currentEvent.title)")

        // Crea titolo per la registrazione basato sull'evento
        let eventTitle = "📅 \(currentEvent.title)"

        // Estrai email dei partecipanti
        let attendeeEmails = currentEvent.attendees
            .filter { $0.status != .declined } // Escludi chi ha rifiutato
            .map { $0.email }
            .filter { !$0.isEmpty }

        print("👥 Partecipanti trovati: \(attendeeEmails.count)")

        return (eventTitle, attendeeEmails)
    }

    /// Formatta la lista dei partecipanti per le note della registrazione
    private func formatAttendeesForNotes(_ attendees: [String]) -> String {
        let header = "👥 PARTECIPANTI EVENTO:\n"
        let attendeeList = attendees.enumerated().map { index, email in
            "• \(email)"
        }.joined(separator: "\n")

        return header + attendeeList
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
