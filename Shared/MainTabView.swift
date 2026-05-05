import SwiftUI

// MARK: - Shared profile overlay used by both tab views
struct ProfileToolbarButton: View {
    @Binding var showProfile: Bool
    @EnvironmentObject var appState: AppState
    @State private var pulsing = false

    var body: some View {
        Button(action: { showProfile = true }) {
            if let img = appState.profileImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 36, height: 36).clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 0.102, green: 0.451, blue: 0.910), lineWidth: 1.5))
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
            } else {
                Circle()
                    .fill(Color(red: 0.102, green: 0.451, blue: 0.910).opacity(pulsing ? 0.15 : 0.35))
                    .frame(width: 36, height: 36)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
                    .onAppear { pulsing = true }
            }
        }
    }
}

struct ProfileSheet: View {
    @Binding var isLoggedIn: Bool
    @Binding var showProfile: Bool
    @EnvironmentObject var appState: AppState

    @State private var photoStatus: PhotoStatus? = nil
    @State private var showPhotoCapture = false

    struct PhotoStatus: Decodable {
        let enrolled: Bool
        let enrolledAt: Double?
        let photoUrl: String?
        let mustUpdateBy: Double?
        let isExpired: Bool?
    }

    var body: some View {
        VStack(spacing: 24) {
            // Profile image
            Group {
                if let img = appState.profileImage {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 100, height: 100).clipShape(Circle())
                        .overlay(Circle().stroke(Color(red: 0.102, green: 0.451, blue: 0.910), lineWidth: 2))
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 90))
                        .foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                }
            }
            .padding(.top, 40)

            VStack(spacing: 6) {
                Text(appState.user?.name ?? "—").font(.title2).bold()
                Text(appState.user?.username ?? "—").font(.subheadline).foregroundColor(.secondary)
                Text(appState.user?.id.uppercased() ?? "—").font(.subheadline).foregroundColor(.secondary)
            }

            Divider().padding(.horizontal)

            // Update Photo section (students only)
            if appState.user?.role.lowercased() == "student" {
                VStack(spacing: 8) {
                    Text("Face Photo").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)

                    Button(action: { showPhotoCapture = true }) {
                        Label("Update Photo", systemImage: "camera.fill")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(canUpdate ? Color(red: 0.102, green: 0.451, blue: 0.910) : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!canUpdate)
                    .padding(.horizontal, 28)

                    photoTimerView
                }

                Divider().padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button(action: {
                    appState.clearSession()
                    showProfile = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isLoggedIn = false }
                }) {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline).foregroundColor(.red)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                Button(action: { showProfile = false }) {
                    Text("Close").font(.subheadline).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .task { await fetchPhotoStatus() }
        .sheet(isPresented: $showPhotoCapture) {
            PhotoCaptureSheet(userId: appState.userId) {
                Task { await fetchPhotoStatus() }
            }
        }
    }

    private var canUpdate: Bool { true } // always allowed — 6-month renewal only

    @ViewBuilder private var photoTimerView: some View {
        if let s = photoStatus, s.enrolled {
            if let mustUpdateBy = s.mustUpdateBy {
                let expired = s.isExpired ?? false
                Text(expired ? "Photo expired — please update" : "Expires \(dateString(mustUpdateBy))")
                    .font(.caption)
                    .foregroundColor(expired ? .red : .secondary)
                    .padding(.horizontal, 28)
            }
        }
    }

    private func fetchPhotoStatus() async {
        guard !appState.userId.isEmpty else { return }
        if let s: PhotoStatus = try? await APIClient.get("/api/student/\(appState.userId)/photoStatus") {
            photoStatus = s
            // Only fetch image from S3 if not already cached in AppState
            if appState.profileImage == nil, let urlStr = s.photoUrl, let url = URL(string: urlStr) {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    await MainActor.run { appState.profileImage = UIImage(data: data) }
                }
            }
        }
    }

    private func dateString(_ ms: Double) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }
}

struct PhotoCaptureSheet: View {
    let userId: String
    var onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var phase: Phase = .preview
    @State private var capturedFrame: String? = nil
    @State private var isSubmitting = false
    @State private var resultMessage = ""
    @State private var cameraVC: SimpleCameraVC? = nil

    enum Phase { case preview, review, done }

    var body: some View {
        NavigationView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .preview:
                            ZStack(alignment: .bottom) {
                                SimpleCameraView(vcRef: $cameraVC)
                                    .cornerRadius(16).shadow(radius: 6)
                                    .frame(width: 320, height: 380)
        
                                Button(action: capture) {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 64, height: 64)
                                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 3))
                                        .shadow(radius: 4)
                                }
                                .padding(.bottom, 20)
                            }
                            Text("Position your face and tap to capture")
                                .font(.subheadline).foregroundColor(.secondary)
        
                        case .review:
                            if let b64 = capturedFrame,
                               let data = Data(base64Encoded: b64),
                               let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 240, height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(radius: 6)
                            }
                            if !resultMessage.isEmpty {
                                Text(resultMessage).font(.caption).foregroundColor(.secondary)
                            }
                            HStack(spacing: 16) {
                                Button("Retry") {
                                    capturedFrame = nil
                                    resultMessage = ""
                                    phase = .preview
                                }
                                .font(.headline).foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                                .frame(maxWidth: .infinity).padding()
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 0.102, green: 0.451, blue: 0.910), lineWidth: 1.5))
        
                                Button(action: submitPhoto) {
                                    Group {
                                        if isSubmitting { ProgressView() }
                                        else { Text("Submit").font(.headline).foregroundColor(.white) }
                                    }
                                    .frame(maxWidth: .infinity).padding()
                                    .background(Color(red: 0.204, green: 0.659, blue: 0.325)).cornerRadius(10)
                                }
                                .disabled(isSubmitting)
                            }
                            .padding(.horizontal, 28)
        
                        case .done:
                            Text(resultMessage).font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    .navigationTitle("Update Photo")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                }
                .navigationViewStyle(.stack)
    }

    private func capture() {
        guard let frame = cameraVC?.captureCurrentFrame() else { return }
        capturedFrame = frame
        phase = .review
    }

    private func submitPhoto() {
        guard let frame = capturedFrame else { return }
        isSubmitting = true
        Task {
            do {
                struct UpdateRequest: Encodable { let frames: [String] }
                struct UpdateResponse: Decodable { let status: String }
                let body = UpdateRequest(frames: [frame])
                guard let url = URL(string: backendBase + "/api/student/\(userId)/updatePhoto") else { throw URLError(.badURL) }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONEncoder().encode(body)
                let (data, _) = try await URLSession.shared.data(for: req)
                let response = try JSONDecoder().decode(UpdateResponse.self, from: data)
                resultMessage = response.status == "uploaded" ? "Photo updated!" : "Failed: \(response.status)"
                if response.status == "uploaded" {
                    appState.profileImage = nil
                    onDone()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                }
                phase = .done
            } catch {
                resultMessage = "Error: \(error.localizedDescription)"
                phase = .done
            }
            isSubmitting = false
        }
    }
}

// MARK: - Student Tab
struct StudentTabView: View {
    @Binding var isLoggedIn: Bool
    @EnvironmentObject var appState: AppState
    @State private var showProfile = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            StudentSessionsView()
                .tabItem { Label("Active Sessions", systemImage: "clock.fill") }
        }
        .accentColor(Color(red: 0.102, green: 0.451, blue: 0.910))
        .overlay(alignment: .topTrailing) {
            ProfileToolbarButton(showProfile: $showProfile)
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet(isLoggedIn: $isLoggedIn, showProfile: $showProfile)
        }
        .task { await prefetchProfileImage() }
    }

    private func prefetchProfileImage() async {
        guard appState.profileImage == nil, !appState.userId.isEmpty else { return }
        struct PhotoStatus: Decodable { let enrolled: Bool; let photoUrl: String? }
        guard let s: PhotoStatus = try? await APIClient.get("/api/student/\(appState.userId)/photoStatus"),
              let urlStr = s.photoUrl, let url = URL(string: urlStr) else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url) {
            await MainActor.run { appState.profileImage = UIImage(data: data) }
        }
    }
}

// MARK: - Admin Tab
struct ProfessorTabView: View {
    @Binding var isLoggedIn: Bool
    @State private var showProfile = false

    var body: some View {
        TabView {
            ProfessorCoursesView()
                .tabItem { Label("Courses", systemImage: "book.fill") }
            ProfessorAnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
        }
        .accentColor(Color(red: 0.102, green: 0.451, blue: 0.910))
        .overlay(alignment: .topTrailing) {
            ProfileToolbarButton(showProfile: $showProfile)
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet(isLoggedIn: $isLoggedIn, showProfile: $showProfile)
        }
    }
}
