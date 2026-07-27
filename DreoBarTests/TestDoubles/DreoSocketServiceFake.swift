import Foundation
@testable import DreoBar

struct SentCommand: Equatable {
    let serialNumber: String
    let key: String
    let value: DreoValue
}

actor DreoSocketServiceFake: DreoSocketServiceProtocol {
    private(set) var connectedSession: DreoSession?
    private(set) var sentCommands: [SentCommand] = []
    var sendCommandError: Error?

    private var continuation: AsyncStream<DreoStateUpdate>.Continuation?

    func connect(session: DreoSession) async {
        connectedSession = session
    }

    func disconnect() async {
        connectedSession = nil
    }

    func sendCommand(serialNumber: String, key: String, value: DreoValue) async throws {
        sentCommands.append(SentCommand(serialNumber: serialNumber, key: key, value: value))
        if let sendCommandError {
            throw sendCommandError
        }
    }

    func observeUpdates() async -> AsyncStream<DreoStateUpdate> {
        let (stream, continuation) = AsyncStream.makeStream(of: DreoStateUpdate.self)
        self.continuation = continuation
        return stream
    }

    func push(_ update: DreoStateUpdate) {
        continuation?.yield(update)
    }
}
