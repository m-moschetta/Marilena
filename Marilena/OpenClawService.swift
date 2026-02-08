import Foundation

// MARK: - OpenClaw Gateway Protocol Types

/// Messaggio base per comunicazione WebSocket con OpenClaw Gateway
struct OpenClawMessage: Codable {
    let type: String // "req", "res", "event"
    let id: String?
    let method: String?
    let params: OpenClawParams?
    let ok: Bool?
    let payload: OpenClawPayload?
    let error: String?
    let event: String?
    let seq: Int?
}

struct OpenClawParams: Codable {
    let message: String?
    let idempotencyKey: String?
    let sessionId: String?

    // Connect params
    let deviceId: String?
    let deviceName: String?
    let role: String?
    let capabilities: [String]?
    let token: String?

    enum CodingKeys: String, CodingKey {
        case message, idempotencyKey, sessionId
        case deviceId, deviceName, role, capabilities, token
    }
}

struct OpenClawPayload: Codable {
    let content: String?
    let status: String?
    let runId: String?
    let summary: String?
    let delta: String?
    let deviceToken: String?
    let sessionId: String?

    // Per snapshot dopo connect
    let sessions: [OpenClawSession]?

    enum CodingKeys: String, CodingKey {
        case content, status, runId, summary, delta, deviceToken, sessionId, sessions
    }
}

struct OpenClawSession: Codable {
    let id: String
    let title: String?
    let createdAt: String?
}

// MARK: - OpenClaw Errors

enum OpenClawError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case authenticationFailed(String)
    case requestFailed(String)
    case invalidResponse
    case timeout
    case pairingRequired

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Non connesso al Gateway OpenClaw"
        case .connectionFailed(let reason):
            return "Connessione fallita: \(reason)"
        case .authenticationFailed(let reason):
            return "Autenticazione fallita: \(reason)"
        case .requestFailed(let reason):
            return "Richiesta fallita: \(reason)"
        case .invalidResponse:
            return "Risposta non valida dal Gateway"
        case .timeout:
            return "Timeout della richiesta"
        case .pairingRequired:
            return "Pairing richiesto. Approva la connessione dal Gateway OpenClaw"
        }
    }
}

// MARK: - OpenClaw Service

class OpenClawService: NSObject, ObservableObject {
    static let shared = OpenClawService()

    @Published var isConnected = false
    @Published var connectionStatus: String = "Disconnesso"
    @Published var currentSessionId: String?

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pendingRequests: [String: CheckedContinuation<OpenClawPayload, Error>] = [:]
    private var streamContinuations: [String: AsyncThrowingStream<String, Error>.Continuation] = [:]
    private var deviceToken: String?

    private let deviceId: String
    private let deviceName: String

    private override init() {
        // Genera un device ID univoco per questa installazione
        if let saved = UserDefaults.standard.string(forKey: "openclaw_device_id") {
            self.deviceId = saved
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "openclaw_device_id")
            self.deviceId = newId
        }

        #if os(iOS)
        self.deviceName = UIDevice.current.name
        #else
        self.deviceName = Host.current().localizedName ?? "Marilena Mac"
        #endif

        super.init()
    }

    // MARK: - Connection Management

    /// Connette al Gateway OpenClaw
    /// - Parameter endpoint: URL del gateway (default: ws://127.0.0.1:18789)
    func connect(to endpoint: String? = nil) async throws {
        let gatewayURL = endpoint ?? getConfiguredEndpoint()

        guard let url = URL(string: gatewayURL) else {
            throw OpenClawError.connectionFailed("URL non valido: \(gatewayURL)")
        }

        // Configura URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()

        // Avvia ricezione messaggi
        receiveMessages()

        // Invia handshake connect
        try await performHandshake()

        await MainActor.run {
            self.isConnected = true
            self.connectionStatus = "Connesso a \(gatewayURL)"
        }
    }

    /// Disconnette dal Gateway
    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil

        Task { @MainActor in
            self.isConnected = false
            self.connectionStatus = "Disconnesso"
            self.currentSessionId = nil
        }
    }

    private func getConfiguredEndpoint() -> String {
        // Prima controlla UserDefaults
        if let saved = UserDefaults.standard.string(forKey: "openclaw_endpoint"),
           !saved.isEmpty {
            return saved
        }
        // Default: localhost
        return "ws://127.0.0.1:18789"
    }

    // MARK: - Handshake

    private func performHandshake() async throws {
        let connectId = UUID().uuidString

        let savedToken = KeychainManager.shared.load(key: "openclaw_device_token")

        let connectMessage = OpenClawMessage(
            type: "req",
            id: connectId,
            method: "connect",
            params: OpenClawParams(
                message: nil,
                idempotencyKey: nil,
                sessionId: nil,
                deviceId: deviceId,
                deviceName: deviceName,
                role: "client", // client mode, non node
                capabilities: ["chat", "streaming"],
                token: savedToken
            ),
            ok: nil,
            payload: nil,
            error: nil,
            event: nil,
            seq: nil
        )

        let response = try await sendRequest(connectMessage)

        // Salva device token se ricevuto (per future connessioni)
        if let newToken = response.deviceToken {
            _ = KeychainManager.shared.save(key: "openclaw_device_token", value: newToken)
            self.deviceToken = newToken
        }

        // Se abbiamo una sessione attiva, salvala
        if let sessionId = response.sessionId {
            await MainActor.run {
                self.currentSessionId = sessionId
            }
        }
    }

    // MARK: - Chat Methods

    /// Invia un messaggio e riceve la risposta completa
    func sendMessage(_ message: String, sessionId: String? = nil) async throws -> String {
        guard isConnected else {
            throw OpenClawError.notConnected
        }

        let requestId = UUID().uuidString
        let idempotencyKey = UUID().uuidString

        let request = OpenClawMessage(
            type: "req",
            id: requestId,
            method: "send",
            params: OpenClawParams(
                message: message,
                idempotencyKey: idempotencyKey,
                sessionId: sessionId ?? currentSessionId,
                deviceId: nil,
                deviceName: nil,
                role: nil,
                capabilities: nil,
                token: nil
            ),
            ok: nil,
            payload: nil,
            error: nil,
            event: nil,
            seq: nil
        )

        let response = try await sendRequest(request)
        return response.content ?? response.summary ?? ""
    }

    /// Invia un messaggio con streaming della risposta
    func streamMessage(_ message: String, sessionId: String? = nil) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            guard self.isConnected else {
                continuation.finish(throwing: OpenClawError.notConnected)
                return
            }

            let requestId = UUID().uuidString
            let idempotencyKey = UUID().uuidString

            // Registra continuation per questo request
            self.streamContinuations[requestId] = continuation

            let request = OpenClawMessage(
                type: "req",
                id: requestId,
                method: "send",
                params: OpenClawParams(
                    message: message,
                    idempotencyKey: idempotencyKey,
                    sessionId: sessionId ?? self.currentSessionId,
                    deviceId: nil,
                    deviceName: nil,
                    role: nil,
                    capabilities: nil,
                    token: nil
                ),
                ok: nil,
                payload: nil,
                error: nil,
                event: nil,
                seq: nil
            )

            Task {
                do {
                    try await self.sendRawMessage(request)
                } catch {
                    continuation.finish(throwing: error)
                    self.streamContinuations.removeValue(forKey: requestId)
                }
            }

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.streamContinuations.removeValue(forKey: requestId)
                }
            }
        }
    }

    // MARK: - Message Sending

    private func sendRequest(_ message: OpenClawMessage) async throws -> OpenClawPayload {
        guard let id = message.id else {
            throw OpenClawError.requestFailed("ID richiesta mancante")
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation

            Task {
                do {
                    try await sendRawMessage(message)
                } catch {
                    pendingRequests.removeValue(forKey: id)
                    continuation.resume(throwing: error)
                }
            }

            // Timeout dopo 60 secondi
            Task {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if let cont = self.pendingRequests.removeValue(forKey: id) {
                    cont.resume(throwing: OpenClawError.timeout)
                }
            }
        }
    }

    private func sendRawMessage(_ message: OpenClawMessage) async throws {
        guard let webSocket = webSocket else {
            throw OpenClawError.notConnected
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw OpenClawError.requestFailed("Impossibile codificare messaggio")
        }

        try await webSocket.send(.string(jsonString))
    }

    // MARK: - Message Receiving

    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continua a ricevere
                self.receiveMessages()

            case .failure(let error):
                Task { @MainActor in
                    self.isConnected = false
                    self.connectionStatus = "Errore: \(error.localizedDescription)"
                }
                // Cancella tutte le richieste pendenti
                for (_, continuation) in self.pendingRequests {
                    continuation.resume(throwing: error)
                }
                self.pendingRequests.removeAll()

                for (_, continuation) in self.streamContinuations {
                    continuation.finish(throwing: error)
                }
                self.streamContinuations.removeAll()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseAndHandleMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseAndHandleMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func parseAndHandleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            let message = try JSONDecoder().decode(OpenClawMessage.self, from: data)

            switch message.type {
            case "res":
                handleResponse(message)
            case "event":
                handleEvent(message)
            default:
                break
            }
        } catch {
            print("[OpenClaw] Errore parsing messaggio: \(error)")
        }
    }

    private func handleResponse(_ message: OpenClawMessage) {
        guard let id = message.id else { return }

        // Prima controlla se è una risposta a una richiesta pending
        if let continuation = pendingRequests.removeValue(forKey: id) {
            if message.ok == true, let payload = message.payload {
                continuation.resume(returning: payload)
            } else {
                let errorMsg = message.error ?? "Errore sconosciuto"
                if errorMsg.contains("pairing") || errorMsg.contains("approval") {
                    continuation.resume(throwing: OpenClawError.pairingRequired)
                } else {
                    continuation.resume(throwing: OpenClawError.requestFailed(errorMsg))
                }
            }
        }

        // Se è una risposta finale per streaming, chiudi lo stream
        if let streamCont = streamContinuations.removeValue(forKey: id) {
            if message.ok == true {
                // Invia contenuto finale se presente
                if let content = message.payload?.content, !content.isEmpty {
                    streamCont.yield(content)
                }
                streamCont.finish()
            } else {
                let errorMsg = message.error ?? "Errore sconosciuto"
                streamCont.finish(throwing: OpenClawError.requestFailed(errorMsg))
            }
        }
    }

    private func handleEvent(_ message: OpenClawMessage) {
        guard let event = message.event else { return }

        switch event {
        case "agent":
            // Evento di streaming dall'agente
            if let delta = message.payload?.delta {
                // Trova lo stream continuation corrispondente
                // OpenClaw invia eventi agent senza ID, quindi li inviamo a tutti gli stream attivi
                for (_, continuation) in streamContinuations {
                    continuation.yield(delta)
                }
            }

        case "presence":
            // Aggiornamento stato presenza - ignora per ora
            break

        case "tick":
            // Heartbeat - ignora
            break

        default:
            print("[OpenClaw] Evento non gestito: \(event)")
        }
    }

    // MARK: - Session Management

    /// Crea una nuova sessione
    func createSession() async throws -> String {
        let request = OpenClawMessage(
            type: "req",
            id: UUID().uuidString,
            method: "sessions_create",
            params: nil,
            ok: nil,
            payload: nil,
            error: nil,
            event: nil,
            seq: nil
        )

        let response = try await sendRequest(request)

        guard let sessionId = response.sessionId else {
            throw OpenClawError.invalidResponse
        }

        await MainActor.run {
            self.currentSessionId = sessionId
        }

        return sessionId
    }

    /// Lista le sessioni disponibili
    func listSessions() async throws -> [OpenClawSession] {
        let request = OpenClawMessage(
            type: "req",
            id: UUID().uuidString,
            method: "sessions_list",
            params: nil,
            ok: nil,
            payload: nil,
            error: nil,
            event: nil,
            seq: nil
        )

        let response = try await sendRequest(request)
        return response.sessions ?? []
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        do {
            try await connect()
            disconnect()
            return true
        } catch {
            throw error
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension OpenClawService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[OpenClaw] WebSocket connesso")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[OpenClaw] WebSocket chiuso: \(closeCode)")
        Task { @MainActor in
            self.isConnected = false
            self.connectionStatus = "Disconnesso"
        }
    }
}

// MARK: - Marilena Chat Integration

extension OpenClawService {
    /// Wrapper per compatibilità con il pattern esistente di Marilena
    func sendMessage(messages: [OpenAIMessage], model: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Prendi l'ultimo messaggio utente
        guard let lastUserMessage = messages.last(where: { $0.role == "user" })?.content else {
            completion(.failure(OpenClawError.requestFailed("Nessun messaggio utente")))
            return
        }

        Task {
            do {
                // Connetti se non connesso
                if !isConnected {
                    try await connect()
                }

                let response = try await sendMessage(lastUserMessage)

                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Streaming wrapper per compatibilità
    func streamMessage(
        messages: [OpenAIMessage],
        model: String,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard let lastUserMessage = messages.last(where: { $0.role == "user" })?.content else {
            onError(OpenClawError.requestFailed("Nessun messaggio utente"))
            return
        }

        Task {
            do {
                if !isConnected {
                    try await connect()
                }

                let stream = streamMessage(lastUserMessage)

                for try await chunk in stream {
                    onChunk(chunk)
                }

                onComplete()
            } catch {
                onError(error)
            }
        }
    }
}
