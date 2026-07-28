import Foundation

actor SettingsRepository: SettingsRepositoryProtocol {
    private let userDefaults: UserDefaults
    private let settingsKey = "app_settings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() async -> AppSettings {
        guard let data = userDefaults.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save(_ settings: AppSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        userDefaults.set(data, forKey: settingsKey)
    }
}
