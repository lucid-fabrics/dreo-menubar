import Foundation

protocol DreoSocketServiceProtocol: Sendable {
    func connect(session: DreoSession) async
    func disconnect() async
    func sendCommand(serialNumber: String, key: String, value: DreoValue) async throws
    func observeUpdates() async -> AsyncStream<DreoStateUpdate>
}
