import Foundation

enum DreoAPIError: Error, Equatable, Sendable {
    case invalidURL
    case notAuthenticated
    case httpError(statusCode: Int)
    case apiError(code: Int, message: String)
    case decodingFailed
    case regionRetryFailed
}
