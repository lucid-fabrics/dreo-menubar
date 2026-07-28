import Foundation

enum KeychainError: Error, Equatable, Sendable {
    case saveFailed(status: OSStatus)
    case readFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case itemNotFound
}
