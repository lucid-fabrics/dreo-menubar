import XCTest
@testable import DreoBar

final class KeychainRepositoryTests: XCTestCase {
    func test_saveThenLoad_roundTripsCredentials() async throws {
        let repository = KeychainRepository(service: Self.uniqueServiceName())
        defer { Task { try? await repository.deleteCredentials() } }

        let credentials = DreoCredentials(email: "user@example.com", password: "secret")
        try await repository.save(credentials)

        let loaded = try await repository.loadCredentials()
        XCTAssertEqual(loaded, credentials)
    }

    func test_saveTwice_updatesRatherThanDuplicates() async throws {
        let repository = KeychainRepository(service: Self.uniqueServiceName())
        defer { Task { try? await repository.deleteCredentials() } }

        try await repository.save(DreoCredentials(email: "a@example.com", password: "one"))
        try await repository.save(DreoCredentials(email: "a@example.com", password: "two"))

        let loaded = try await repository.loadCredentials()
        XCTAssertEqual(loaded?.password, "two")
    }

    func test_loadCredentials_whenNothingStored_returnsNil() async throws {
        let repository = KeychainRepository(service: Self.uniqueServiceName())

        let loaded = try await repository.loadCredentials()
        XCTAssertNil(loaded)
    }

    func test_deleteCredentials_removesStoredValue() async throws {
        let repository = KeychainRepository(service: Self.uniqueServiceName())

        try await repository.save(DreoCredentials(email: "a@example.com", password: "one"))
        try await repository.deleteCredentials()

        let loaded = try await repository.loadCredentials()
        XCTAssertNil(loaded)
    }

    private static func uniqueServiceName() -> String {
        "com.dreobar.tests.\(UUID().uuidString)"
    }
}
