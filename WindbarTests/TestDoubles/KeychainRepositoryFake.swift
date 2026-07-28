@testable import Windbar

actor KeychainRepositoryFake: KeychainRepositoryProtocol {
    private var stored: DreoCredentials?

    init(stored: DreoCredentials? = nil) {
        self.stored = stored
    }

    func save(_ credentials: DreoCredentials) async throws {
        stored = credentials
    }

    func loadCredentials() async throws -> DreoCredentials? {
        stored
    }

    func deleteCredentials() async throws {
        stored = nil
    }
}
