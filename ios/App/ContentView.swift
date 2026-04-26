import SwiftUI

enum UserRole { case student, professor }

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var role: UserRole = .student
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if appState.isRestoringSession {
                ProgressView("Restoring session…")
            } else if isLoggedIn || appState.user != nil {
                switch role {
                case .student:   StudentTabView(isLoggedIn: $isLoggedIn)
                case .professor: ProfessorTabView(isLoggedIn: $isLoggedIn)
                }
            } else {
                RoleSelectionView(isLoggedIn: $isLoggedIn, role: $role)
            }
        }
        .environmentObject(appState)
        .preferredColorScheme(.light)
        .task {
            // Warm up Soham's backend in background (Render free tier cold start)
            Task { _ = try? await URLSession.shared.data(from: URL(string: "https://attendance-management-gazr.onrender.com/health")!) }
            await appState.restoreSession()
            if let savedRole = KeychainHelper.savedRole {
                switch savedRole {
                case "professor": role = .professor
                default:          role = .student
                }
            }
        }
    }
}
