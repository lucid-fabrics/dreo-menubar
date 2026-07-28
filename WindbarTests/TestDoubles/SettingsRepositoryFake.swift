@testable import Windbar

actor SettingsRepositoryFake: SettingsRepositoryProtocol {
    private var stored: AppSettings

    init(stored: AppSettings = .default) {
        self.stored = stored
    }

    func load() async -> AppSettings {
        stored
    }

    func save(_ settings: AppSettings) async throws {
        stored = settings
    }
}
