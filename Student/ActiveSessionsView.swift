import SwiftUI

// MARK: - Session model from backend
struct ActiveSession: Identifiable, Decodable {
    let sessionId: String
    let courseCode: String
    let courseName: String
    let room: String
    let mode: String
    let startedAt: Double
    let durationSeconds: Int
    var id: String { sessionId }
}

private struct SessionsResponse: Decodable {
    let sessions: [ActiveSession]
}

// MARK: - Student Active Sessions
struct StudentSessionsView: View {
    @EnvironmentObject var appState: AppState
    @State private var sessions: [ActiveSession] = []
    @State private var isLoading = false
    @State private var navActive: [String: Bool] = [:]
    @State private var pollTimer: Timer? = nil

    var body: some View {
        NavigationView {
                    ScrollView {
                        VStack(spacing: 16) {
                            if isLoading && sessions.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity).padding(.top, 100)
                            } else if sessions.isEmpty {
                                Text("No active sessions right now.")
                                    .font(.subheadline).foregroundColor(.secondary)
                                    .padding(.top, 60)
                            } else {
                                ForEach(sessions) { session in
                                    let mode = AttendanceMode.from(session.mode)
                                    let isNav = Binding(
                                        get: { navActive[session.sessionId] ?? false },
                                        set: { navActive[session.sessionId] = $0 }
                                    )
                                    NavigationLink(
                                        destination: MarkAttendanceFlow(
                                            mode: mode,
                                            popToRoot: {
                                                navActive[session.sessionId] = false
                                                startPolling()
                                            },
                                            courseCode: session.courseCode,
                                            sessionId: session.sessionId,
                                            room: session.room,
                                            startedAt: session.startedAt,
                                            durationSeconds: session.durationSeconds
                                        ),
                                        isActive: isNav
                                    ) { EmptyView() }
        
                                    SessionCard(
                                        title: session.courseName,
                                        subtitle: "Room \(session.room)",
                                        mode: mode
                                    ) {
                                        pollTimer?.invalidate()
                                        navActive[session.sessionId] = true
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable { await fetchSessions() }
                    .background(Color.gray.opacity(0.1))
                    .navigationTitle("Active Sessions")
                }
                .navigationViewStyle(.stack)
        .onAppear { startPolling() }
        .onDisappear { pollTimer?.invalidate() }
    }

    private func startPolling() {
        Task { await fetchSessions() }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { await fetchSessions() }
        }
    }

    func refreshNow() async { await fetchSessions() }

    private func fetchSessions() async {
        guard !appState.userId.isEmpty else { return }
        if sessions.isEmpty { isLoading = true }
        do {
            let response: SessionsResponse = try await APIClient.get("/api/student/\(appState.userId)/sessions")
            sessions = response.sessions
        } catch {
            print("Sessions fetch error:", error)
        }
        isLoading = false
    }
}

// MARK: - Session Card
struct SessionCard: View {
    let title: String
    let subtitle: String
    let mode: AttendanceMode
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Color(red: 0.102, green: 0.451, blue: 0.910).frame(height: 60)
                Text(title).font(.headline).bold().foregroundColor(.white)
                    .padding([.leading, .bottom], 12)
            }
            .clipShape(CornerShape(radius: 15, corners: [.topLeft, .topRight]))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Currently Active").font(.caption).bold().foregroundColor(.red)
                }
                Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                HStack {
                    Label("Mode:", systemImage: "info.circle").font(.caption).foregroundColor(.secondary)
                    Text(mode.label).font(.caption).bold()
                        .foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                }
                Divider()
                Button(action: onTap) {
                    Text("Mark Attendance")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color(red: 0.102, green: 0.451, blue: 0.910))
                        .cornerRadius(10)
                }
            }
            .padding(14).background(Color.white)
            .clipShape(CornerShape(radius: 15, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Attendance Mode
enum AttendanceMode {
    case qr, ble
    var label: String { self == .qr ? "QR Scan" : "BLE Scan" }
    var icon: String  { self == .qr ? "qrcode.viewfinder" : "antenna.radiowaves.left.and.right" }

    static func from(_ string: String) -> AttendanceMode {
        string.lowercased() == "ble" ? .ble : .qr
    }
}

// MARK: - Mark Attendance Flow
struct MarkAttendanceFlow: View {
    let mode: AttendanceMode
    let popToRoot: () -> Void
    var courseCode: String = ""
    var sessionId: String = ""
    var room: String = ""
    var startedAt: Double = 0
    var durationSeconds: Int = 120
    @State private var step = 1
    @State private var expired = false
    @State private var expiryTimer: Timer? = nil
    @EnvironmentObject var appState: AppState

    private func computeTimeLeft() -> Int {
        guard startedAt > 0 else { return durationSeconds }
        let elapsed = Int((Date().timeIntervalSince1970 * 1000 - startedAt) / 1000)
        return max(durationSeconds - elapsed, 0)
    }

    var body: some View {
        Group {
            if expired {
                expiredView
            } else {
                activeView
            }
        }
        .navigationTitle("Mark Attendance")
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .onAppear {
            let remaining = computeTimeLeft()
            if remaining == 0 { expired = true; return }
            expiryTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(remaining), repeats: false) { _ in
                expired = true
            }
        }
        .onDisappear { expiryTimer?.invalidate() }
    }

    private var activeView: some View {
        VStack(spacing: 32) {
            HStack(spacing: 0) {
                StepDot(num: 1, label: mode.label,    active: step >= 1)
                Rectangle().frame(height: 2)
                    .foregroundColor(step >= 2 ? Color(red: 0.102, green: 0.451, blue: 0.910) : Color.gray.opacity(0.3))
                StepDot(num: 2, label: "Face Verify", active: step >= 2)
            }
            .padding(.horizontal, 40).padding(.top, 32)

            Spacer()

            if step == 1 {
                if mode == .qr {
                    StudentQRScanView(onSuccess: { step = 2 }, classId: room)
                        .frame(height: 340).cornerRadius(16).padding(.horizontal)
                } else {
                    StudentBLEScanView(
                        onSuccess: { step = 2 },
                        classId: room,
                        startedAt: startedAt,
                        durationSeconds: durationSeconds
                    )
                }
            } else {
                StudentFaceVerifyView(
                    onSuccess: { Task { await postMarkAttendance() } },
                    username: appState.username
                )
            }

            Spacer()
        }
    }

    private var expiredView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.badge.xmark.fill")
                .font(.system(size: 72))
                .foregroundColor(.red)
            Text("Session Expired")
                .font(.title).bold()
            Text("The attendance window has closed.\nYour attendance was not recorded.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button(action: popToRoot) {
                Text("Back to Sessions")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color(red: 0.102, green: 0.451, blue: 0.910))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40).padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func postMarkAttendance() async {
        guard !appState.userId.isEmpty, !sessionId.isEmpty else { popToRoot(); return }
        do {
            struct MarkResponse: Decodable { let success: Bool }
            let _: MarkResponse = try await APIClient.post(
                "/api/student/markAttendance",
                body: ["studentId": appState.userId, "sessionId": sessionId]
            )
            expiryTimer?.invalidate()  // prevent expiry screen from overriding success
        } catch {
            print("markAttendance error:", error)
        }
        popToRoot()
    }
}

// MARK: - Step Dot
struct StepDot: View {
    let num: Int; let label: String; let active: Bool
    private let gBlue = Color(red: 0.102, green: 0.451, blue: 0.910)
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(active ? gBlue : Color.gray.opacity(0.3)).frame(width: 32, height: 32)
                Text("\(num)").font(.headline).foregroundColor(.white)
            }
            Text(label).font(.caption).foregroundColor(active ? gBlue : .secondary)
        }
    }
}
