import Foundation
import os

/// Live control channel for Dreo devices. Protocol reverse-engineered from
/// the vendored Python client: `wss://wsb-{region}.dreo-tech.com/websocket`,
/// a literal `"2"` text-frame keepalive every 15s, and JSON command/ack
/// envelopes keyed by device serial (`devicesn`).
actor DreoSocketService: DreoSocketServiceProtocol {
    private static let logger = Logger(subsystem: "com.lucidfabrics.windbar", category: "DreoSocketService")

    private let urlSession: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: DreoSession?
    private var shouldReconnect = false

    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var updateContinuations: [UUID: AsyncStream<DreoStateUpdate>.Continuation] = [:]
    private var acknowledgedSerialNumbers: Set<String> = []

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func observeUpdates() async -> AsyncStream<DreoStateUpdate> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: DreoStateUpdate.self)
        updateContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeContinuation(id) }
        }
        return stream
    }

    func connect(session: DreoSession) async {
        self.session = session
        shouldReconnect = true
        openSocket()
    }

    func disconnect() async {
        shouldReconnect = false
        reconnectTask?.cancel()
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    func sendCommand(serialNumber: String, key: String, value: DreoValue) async throws {
        let text = try Self.encodeCommand(serialNumber: serialNumber, key: key, value: value)

        var lastError: Error = DreoSocketError.notConnected
        for attempt in 0...Constants.Socket.maxCommandRetries {
            do {
                try await sendAndAwaitAck(serialNumber: serialNumber, text: text)
                return
            } catch {
                lastError = error
                let description = String(describing: error)
                Self.logger.warning("Command attempt \(attempt + 1) failed: \(description, privacy: .public)")
            }
        }
        throw lastError
    }

    // MARK: - Connection lifecycle

    private func openSocket() {
        guard let session, let url = Self.webSocketURL(for: session) else {
            Self.logger.error("No session or invalid websocket URL")
            return
        }

        Self.logger.debug("Opening socket: \(url.absoluteString, privacy: .public)")
        let task = urlSession.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        receiveTask?.cancel()
        receiveTask = Task { await self.receiveLoop() }

        pingTask?.cancel()
        pingTask = Task { await self.pingLoop() }
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(for: Constants.Socket.reconnectDelay)
            guard !Task.isCancelled else { return }
            self.reopenIfNeeded()
        }
    }

    private func reopenIfNeeded() {
        guard shouldReconnect else { return }
        openSocket()
    }

    private func removeContinuation(_ id: UUID) {
        updateContinuations.removeValue(forKey: id)
    }

    // MARK: - Loops

    private func pingLoop() async {
        while !Task.isCancelled {
            guard let webSocketTask else { return }
            do {
                try await webSocketTask.send(.string(Constants.Socket.pingMessage))
            } catch {
                Self.logger.warning("Ping failed: \(String(describing: error), privacy: .public)")
                scheduleReconnect()
                return
            }
            try? await Task.sleep(for: Constants.Socket.pingInterval)
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let webSocketTask else { return }
            do {
                let message = try await webSocketTask.receive()
                handle(message: message)
            } catch {
                Self.logger.warning("Receive failed: \(String(describing: error), privacy: .public)")
                scheduleReconnect()
                return
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message else { return }
        Self.logger.debug("Received: \(text, privacy: .public)")

        guard let data = text.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(SocketEnvelope.self, from: data) else {
            return
        }

        // Any message naming the device counts as an ack: real firmware sends
        // "report" for both command confirmations and ambient sensor pushes,
        // not the "control-report"/"control-reply" names the vendored Python
        // client's source assumed, so a strict method-name match never fires.
        acknowledgedSerialNumbers.insert(envelope.devicesn)

        if let reported = envelope.reported {
            let update = DreoStateUpdate(serialNumber: envelope.devicesn, changes: reported)
            for continuation in updateContinuations.values {
                continuation.yield(update)
            }
        }
    }

    // MARK: - Command send + ack

    // ponytail: polls every 100ms instead of a continuation-based wakeup.
    // Simpler and avoids actor-isolation pitfalls with cross-task continuations;
    // upgrade to a per-command CheckedContinuation registry if 100ms of added
    // latency on the rare retry path ever actually matters.
    private func sendAndAwaitAck(serialNumber: String, text: String) async throws {
        guard let webSocketTask else { throw DreoSocketError.notConnected }
        acknowledgedSerialNumbers.remove(serialNumber)
        Self.logger.debug("Sending: \(text, privacy: .public)")
        try await webSocketTask.send(.string(text))

        let deadline = ContinuousClock.now + Constants.Socket.commandAckTimeout
        while ContinuousClock.now < deadline {
            if acknowledgedSerialNumbers.contains(serialNumber) {
                acknowledgedSerialNumbers.remove(serialNumber)
                Self.logger.debug("Acked: \(serialNumber, privacy: .public)")
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw DreoSocketError.ackTimeout
    }

    // MARK: - Wire helpers

    private struct SocketEnvelope: Decodable {
        let devicesn: String
        let method: String
        let reported: [String: DreoValue]?
    }

    static func encodeCommand(serialNumber: String, key: String, value: DreoValue) throws -> String {
        let payload: [String: Any] = [
            "devicesn": serialNumber,
            "method": "control",
            "params": [key: value.jsonObject],
            "timestamp": String(Int(Date().timeIntervalSince1970 * 1000))
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw DreoSocketError.notConnected
        }
        return text
    }

    static func webSocketURL(for session: DreoSession) -> URL? {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "wsb-\(session.regionHost).dreo-tech.com"
        components.path = "/websocket"
        components.queryItems = [
            URLQueryItem(name: "accessToken", value: session.accessToken),
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970 * 1000)))
        ]
        return components.url
    }
}
