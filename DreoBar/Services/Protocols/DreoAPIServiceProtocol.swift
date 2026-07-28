import Foundation

protocol DreoAPIServiceProtocol: Sendable {
    func login(_ credentials: DreoCredentials) async throws
    func listDevices() async throws -> [DreoDevice]
    func fetchState(for serialNumber: String) async throws -> [String: DreoValue]
    func removeDevice(serialNumber: String) async throws
    func currentSession() async -> DreoSession?
}
