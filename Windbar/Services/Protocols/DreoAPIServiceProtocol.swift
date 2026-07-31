import Foundation

protocol DreoAPIServiceProtocol: Sendable {
    func login(_ credentials: DreoCredentials) async throws
    func listDevices() async throws -> [DreoDevice]
    func fetchState(for serialNumber: String) async throws -> [String: DreoValue]
    func removeDevice(serialNumber: String) async throws
    func currentSession() async -> DreoSession?
    /// Drops the access token and cached credentials. Signing out has to clear the
    /// in-memory session too, not only the Keychain, or the app keeps talking to
    /// Dreo with the previous account until it is relaunched.
    func signOut() async
}
