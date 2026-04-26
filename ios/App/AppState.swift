import Foundation
import UIKit
import Combine

struct BackendUser: Codable {
    let id: String
    let email: String
    let name: String
    let role: String
    let courses: [String]

    var username: String { email }

    init(id: String, email: String, name: String, role: String, courses: [String] = []) {
        self.id = id; self.email = email; self.name = name
        self.role = role; self.courses = courses
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id      = try c.decode(String.self, forKey: .id)
        email   = try c.decode(String.self, forKey: .email)
        name    = try c.decode(String.self, forKey: .name)
        role    = try c.decode(String.self, forKey: .role)
        courses = (try? c.decode([String].self, forKey: .courses)) ?? []
    }

    enum CodingKeys: String, CodingKey { case id, email, name, role, courses }
}

class AppState: ObservableObject {
    @Published var user: BackendUser? = nil
    @Published var profileImage: UIImage? = nil
    @Published var isRestoringSession: Bool = true

    var username: String { user?.email ?? "" }
    var userId: String   { user?.id ?? "" }

    func restoreSession() async {
        defer {
            DispatchQueue.main.async { self.isRestoringSession = false }
        }

        guard KeychainHelper.isTokenValid else {
            guard let email    = KeychainHelper.savedEmail,
                  let password = KeychainHelper.savedPassword else { return }
            await silentLogin(email: email, password: password)
            return
        }

        if let str  = KeychainHelper.load("user"),
           let data = str.data(using: .utf8),
           let u    = try? JSONDecoder().decode(BackendUser.self, from: data) {
            DispatchQueue.main.async { self.user = u }
        }
    }

    func saveSession(user: BackendUser, token: String, email: String, password: String) {
        KeychainHelper.token         = token
        KeychainHelper.savedEmail    = email
        KeychainHelper.savedPassword = password
        if let data = try? JSONEncoder().encode(user),
           let str  = String(data: data, encoding: .utf8) {
            KeychainHelper.save(str, for: "user")
        }
        self.user = user
    }

    func clearSession() {
        KeychainHelper.token         = nil
        KeychainHelper.savedEmail    = nil
        KeychainHelper.savedPassword = nil
        KeychainHelper.delete("role")
        KeychainHelper.delete("user")
        DispatchQueue.main.async { self.user = nil; self.profileImage = nil }
    }

    private func silentLogin(email: String, password: String) async {
        struct LoginResp: Decodable { let token: String?; let user: BackendUser? }
        guard let resp: LoginResp = try? await APIClient.post(
            "/api/auth/login", body: ["email": email, "password": password]
        ), let token = resp.token, let u = resp.user else { return }

        KeychainHelper.token = token
        if let data = try? JSONEncoder().encode(u),
           let str  = String(data: data, encoding: .utf8) {
            KeychainHelper.save(str, for: "user")
        }
        DispatchQueue.main.async { self.user = u }
    }
}
