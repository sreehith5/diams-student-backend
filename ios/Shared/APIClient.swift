import Foundation

let backendBase = "https://diams-student-backend-app-gateway.onrender.com"

struct APIClient {
    // MARK: - Core request builder
    private static func makeRequest(_ url: URL, method: String, body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainHelper.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    // MARK: - GET
    static func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: backendBase + path) else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(for: makeRequest(url, method: "GET"))
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            try await refreshToken()
            let (retryData, _) = try await URLSession.shared.data(for: makeRequest(url, method: "GET"))
            return try JSONDecoder().decode(T.self, from: retryData)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - POST
    static func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let data = try await postRaw(path, body: body)
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func postRaw(_ path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: backendBase + path) else { throw URLError(.badURL) }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: makeRequest(url, method: "POST", body: bodyData))
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            try await refreshToken()
            let (retryData, _) = try await URLSession.shared.data(for: makeRequest(url, method: "POST", body: bodyData))
            return retryData
        }
        return data
    }

    // MARK: - Silent re-login on token expiry
    private static func refreshToken() async throws {
        guard let email    = KeychainHelper.savedEmail,
              let password = KeychainHelper.savedPassword else { throw URLError(.userAuthenticationRequired) }

        guard let url = URL(string: backendBase + "/api/auth/login") else { throw URLError(.badURL) }
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, _) = try await URLSession.shared.data(for: makeRequest(url, method: "POST", body: body))

        struct LoginResp: Decodable { let token: String? }
        if let resp = try? JSONDecoder().decode(LoginResp.self, from: data), let token = resp.token {
            KeychainHelper.token = token
        }
    }
}

// MARK: - AnyCodable
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self)   { value = b; return }
        if let i = try? c.decode(Int.self)    { value = i; return }
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self) { value = s; return }
        value = NSNull()
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let b as Bool:   try c.encode(b)
        case let i as Int:    try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        default:              try c.encodeNil()
        }
    }
}
