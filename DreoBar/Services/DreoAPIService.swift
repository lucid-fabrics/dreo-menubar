import CryptoKit
import Foundation
import os

/// REST client for Dreo's cloud API. Protocol reverse-engineered from
/// `JeffSteinbok/hass-dreo`'s vendored Python client: host is
/// `app-api-{region}.dreo-tech.com` where region is only known after login,
/// password goes over the wire as lowercase-hex MD5, and every response is
/// wrapped in `{code, msg, data}` with `code == 0` meaning success.
actor DreoAPIService: DreoAPIServiceProtocol {
    private static let logger = Logger(subsystem: "com.dreobar", category: "DreoAPIService")

    private let urlSession: URLSession
    private var accessToken: String?
    private var regionHost = "us"
    private var credentials: DreoCredentials?
    private var userId: UInt64?

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func currentSession() async -> DreoSession? {
        guard let accessToken else { return nil }
        return DreoSession(accessToken: accessToken, regionHost: regionHost, userId: userId)
    }

    func login(_ credentials: DreoCredentials) async throws {
        self.credentials = credentials
        try await performLogin(credentials: credentials, allowRegionRetry: true)
    }

    func listDevices() async throws -> [DreoDevice] {
        guard accessToken != nil else { throw DreoAPIError.notAuthenticated }

        let url = try makeURL(path: "/api/v2/user-device/device/list", queryItems: [
            URLQueryItem(name: "acceptLanguage", value: "en"),
            URLQueryItem(name: "method", value: "devices"),
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "pageSize", value: "100"),
            URLQueryItem(name: "timestamp", value: Self.timestamp())
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(&request, includeAuth: true)

        let envelope: DreoAPIEnvelope<DeviceListData> = try await sendWithReauth(request)
        guard envelope.code == 0, let list = envelope.data?.list else {
            throw DreoAPIError.apiError(code: envelope.code, message: envelope.msg ?? "device list failed")
        }
        return list.map { entry in
            // Newer models send only a template name, so fall back to the
            // bundled schema for that model.
            var schema = entry.controlsConf
            if schema == nil || schema?.isEmpty == true {
                schema = DeviceTemplateCatalog.schema(forModel: entry.model) ?? schema
            }
            return DreoDevice(
                serialNumber: entry.serialNumber,
                deviceName: entry.deviceName,
                model: entry.model,
                controlsConf: schema
            )
        }
    }

    func fetchState(for serialNumber: String) async throws -> [String: DreoValue] {
        guard accessToken != nil else { throw DreoAPIError.notAuthenticated }

        let url = try makeURL(path: "/api/user-device/device/state", queryItems: [
            URLQueryItem(name: "deviceSn", value: serialNumber),
            URLQueryItem(name: "timestamp", value: Self.timestamp())
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(&request, includeAuth: true)

        let envelope: DreoAPIEnvelope<DeviceStateData> = try await sendWithReauth(request)
        guard envelope.code == 0, let mixed = envelope.data?.flattened else {
            throw DreoAPIError.apiError(code: envelope.code, message: envelope.msg ?? "device state failed")
        }
        return mixed
    }

    // MARK: - Login internals

    private func performLogin(credentials: DreoCredentials, allowRegionRetry: Bool) async throws {
        let url = try makeURL(path: "/api/oauth/login", queryItems: [
            URLQueryItem(name: "timestamp", value: Self.timestamp())
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(&request, includeAuth: false)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "acceptLanguage": "en",
            "client_id": Constants.API.clientId,
            "client_secret": Constants.API.clientSecret,
            "email": credentials.email,
            "encrypt": "ciphertext",
            "grant_type": "email-password",
            "himei": Constants.API.himei,
            "password": Self.md5Hex(credentials.password),
            "scope": "all"
        ])

        let envelope: DreoAPIEnvelope<LoginData> = try await send(request)
        guard envelope.code == 0, let data = envelope.data else {
            throw DreoAPIError.apiError(code: envelope.code, message: envelope.msg ?? "login failed")
        }

        let newHost = Self.hostSuffix(forAuthRegion: data.region)
        if allowRegionRetry, newHost != regionHost {
            Self.logger.info("Login region mismatch, retrying against \(newHost, privacy: .public)")
            regionHost = newHost
            try await performLogin(credentials: credentials, allowRegionRetry: false)
            return
        }

        regionHost = newHost
        accessToken = data.accessToken
        userId = data.userId.flatMap(UInt64.init)
    }

    private func reauthenticate() async throws {
        guard let credentials else { throw DreoAPIError.notAuthenticated }
        try await performLogin(credentials: credentials, allowRegionRetry: true)
    }

    // MARK: - HTTP plumbing

    private func sendWithReauth<Payload: Decodable>(_ request: URLRequest) async throws -> DreoAPIEnvelope<Payload> {
        do {
            return try await send(request)
        } catch DreoAPIError.httpError(let statusCode) where statusCode == 401 {
            Self.logger.info("Got 401, re-authenticating and retrying once")
            try await reauthenticate()
            var retried = request
            applyHeaders(&retried, includeAuth: true)
            return try await send(retried)
        }
    }

    private func send<Payload: Decodable>(_ request: URLRequest) async throws -> DreoAPIEnvelope<Payload> {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DreoAPIError.httpError(statusCode: -1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DreoAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        guard let envelope = try? JSONDecoder().decode(DreoAPIEnvelope<Payload>.self, from: data) else {
            throw DreoAPIError.decodingFailed
        }
        return envelope
    }

    private func applyHeaders(_ request: inout URLRequest, includeAuth: Bool) {
        request.setValue(Constants.API.userAgent, forHTTPHeaderField: "ua")
        request.setValue("en", forHTTPHeaderField: "lang")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "content-type")
        request.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        request.setValue(Constants.API.okhttpUserAgent, forHTTPHeaderField: "user-agent")
        if includeAuth, let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "app-api-\(regionHost).dreo-tech.com"
        components.path = path
        components.queryItems = queryItems
        guard let url = components.url else { throw DreoAPIError.invalidURL }
        return url
    }

    private static func timestamp() -> String {
        String(Int(Date().timeIntervalSince1970 * 1000))
    }

    private static func hostSuffix(forAuthRegion authRegion: String) -> String {
        authRegion == "EU" ? "eu" : "us"
    }

    private static func md5Hex(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
