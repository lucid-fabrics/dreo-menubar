import Foundation

protocol SettingsRepositoryProtocol: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async throws
}
