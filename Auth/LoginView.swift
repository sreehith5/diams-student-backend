import SwiftUI

private struct LoginResponse: Decodable {
    let success: Bool?
    let token: String?
    let user: BackendUser?
}

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var role: UserRole
    let selectedRole: UserRole

    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    private let gBlue = Color(red: 0.102, green: 0.451, blue: 0.910)

    var roleLabel: String {
        switch selectedRole {
        case .student:   return "Student"
        case .professor: return "Professor"
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 8) {
                Image("iithlogo").resizable().scaledToFit().frame(width: 80, height: 80)
                Text("Sign In as \(roleLabel)").font(.title2).bold()
            }

            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .padding().background(Color.gray.opacity(0.12)).cornerRadius(10)

                ZStack(alignment: .trailing) {
                    if showPassword {
                        TextField("Password", text: $password)
                            .autocapitalization(.none).disableAutocorrection(true)
                            .padding().background(Color.gray.opacity(0.12)).cornerRadius(10)
                    } else {
                        SecureField("Password", text: $password)
                            .padding().background(Color.gray.opacity(0.12)).cornerRadius(10)
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary).padding(.trailing, 12)
                    }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundColor(.red)
                }

                Button(action: login) {
                    if isLoading {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(gBlue).cornerRadius(10)
                    } else {
                        Text("Sign In").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(email.isEmpty ? Color.gray : gBlue)
                            .cornerRadius(10)
                    }
                }
                .disabled(email.isEmpty || isLoading)
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func login() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                let response: LoginResponse = try await APIClient.post(
                    "/api/auth/login",
                    body: ["email": email, "password": password]
                )
                guard let token = response.token, let user = response.user else {
                    errorMessage = "Invalid credentials. Please try again."
                    isLoading = false
                    return
                }
                appState.saveSession(user: user, token: token, email: email, password: password)
                KeychainHelper.savedRole = selectedRole == .professor ? "professor" : "student"
                role = selectedRole
                isLoggedIn = true
            } catch {
                errorMessage = "Invalid credentials. Please try again."
            }
            isLoading = false
        }
    }
}
