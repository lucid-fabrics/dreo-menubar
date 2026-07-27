import Foundation

enum Constants {
    enum API {
        static let clientId = "7de37c362ee54dcf9c4561812309347a"
        static let clientSecret = "32dfa0764f25451d99f94e1693498791"
        static let himei = "faede31549d649f58864093158787ec9"
        static let userAgent = "dreo/2.8.2"
        static let okhttpUserAgent = "okhttp/4.9.1"
    }

    enum Socket {
        static let pingInterval: Duration = .seconds(15)
        static let pingMessage = "2"
        static let commandAckTimeout: Duration = .seconds(2)
        static let maxCommandRetries = 2
        static let reconnectDelay: Duration = .seconds(5)
    }

    enum Keychain {
        static let service = "com.dreobar.credentials"
        static let emailAccount = "email"
        static let passwordAccount = "password"
    }
}
