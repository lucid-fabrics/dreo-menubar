import Foundation

protocol KeychainRepositoryProtocol: Sendable {
    func save(_ credentials: DreoCredentials) async throws
    func loadCredentials() async throws -> DreoCredentials?
    func deleteCredentials() async throws
}
