import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - QR Session View

struct ProfQRSessionView: View {
    let cls: ScheduledClass
    @Binding var sessionId: String
    var startedAt: Double = 0
    var durationSeconds: Int = 120
    @State private var timeLeft = 0
    @State private var qrUIImage: UIImage? = nil
    @State private var timer: Timer? = nil
    @State private var qrRefreshTimer: Timer? = nil
    @State private var markedCount: Int? = nil
    @State private var enrolledCount: Int? = nil

    var body: some View {
        Group {
            if timeLeft == 0 && startedAt > 0 { sessionCompletedView } else { activeView }
        }
        .navigationTitle("QR Attendance")
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .onAppear {
            timeLeft = computeTimeLeft()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in timeLeft += 1 }
            fetchQR()
            qrRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in fetchQR() }
        }
        .onDisappear { stopTimers() }
    }

    private var activeView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 8).frame(width: 100, height: 100)
                Circle().stroke(Color(red: 0.102, green: 0.451, blue: 0.910), lineWidth: 8).frame(width: 100, height: 100)
                Text(timeString).font(.title2).bold()
            }
            .padding(.top, 32)
            Text("QR refreshes every 5 seconds").font(.caption).foregroundColor(.secondary)
            Group {
                if let img = qrUIImage {
                    Image(uiImage: img).interpolation(.none).resizable().scaledToFit().frame(width: 220, height: 220)
                } else {
                    ProgressView().frame(width: 220, height: 220)
                }
            }
            .padding(16).background(Color.white).cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            Text("Display this to students").font(.subheadline).foregroundColor(.secondary)
            Button(action: endSession) {
                Label("End Session", systemImage: "stop.circle.fill")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.red).cornerRadius(12)
            }
            .padding(.horizontal, 28).padding(.bottom, 16)
            Spacer()
        }
    }

    private var sessionCompletedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 72))
                .foregroundColor(Color(red: 0.204, green: 0.659, blue: 0.325))
            Text("Session Ended").font(.title).bold()
            if let marked = markedCount, let enrolled = enrolledCount {
                Text("\(marked) / \(enrolled) students marked attendance").font(.title3).foregroundColor(.secondary)
            } else { ProgressView() }
            Text(cls.name).font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func computeTimeLeft() -> Int {
        guard startedAt > 0 else { return 0 }
        return Int((Date().timeIntervalSince1970 * 1000 - startedAt) / 1000)
    }

    private func fetchQR() {
        Task {
            struct QRResp: Decodable { let hash: String? }
            guard let resp: QRResp = try? await APIClient.post("/api/qr/generate", body: ["class_id": cls.room]),
                  let hash = resp.hash else { return }
            let payload = "\(cls.room)|\(hash)"
            let data = Data(payload.utf8)
            guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            guard let ciImage = filter.outputImage else { return }
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            let ctx = CIContext()
            guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return }
            await MainActor.run { qrUIImage = UIImage(cgImage: cg) }
        }
    }

    private func fetchSummary() {
        guard !sessionId.isEmpty else { return }
        Task {
            struct Summary: Decodable { let enrolledCount: Int; let markedCount: Int }
            if let s: Summary = try? await APIClient.get("/api/professor/session/\(sessionId)/summary") {
                enrolledCount = s.enrolledCount; markedCount = s.markedCount
            }
        }
    }

    private func endSession() {
        guard !sessionId.isEmpty else { return }
        stopTimers()
        Task {
            _ = try? await APIClient.postRaw("/api/professor/session/end/\(sessionId)", body: [:])
            await MainActor.run { timeLeft = 0 }
            fetchSummary()
        }
    }

    private var timeString: String { String(format: "%d:%02d", timeLeft / 60, timeLeft % 60) }
    private func stopTimers() { timer?.invalidate(); qrRefreshTimer?.invalidate() }
}

// MARK: - BLE Session View

struct ProfBLESessionView: View {
    let cls: ScheduledClass
    @Binding var sessionId: String
    var startedAt: Double = 0
    var durationSeconds: Int = 120
    @State private var timeLeft = 0
    @State private var timer: Timer? = nil
    @State private var markedCount: Int? = nil
    @State private var enrolledCount: Int? = nil

    var body: some View {
        Group {
            if timeLeft == 0 && startedAt > 0 { sessionCompletedView } else { activeView }
        }
        .navigationTitle("BLE Attendance")
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .onAppear {
            timeLeft = computeTimeLeft()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in timeLeft += 1 }
        }
        .onDisappear { timer?.invalidate() }
    }

    private var activeView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 8).frame(width: 100, height: 100)
                Circle().stroke(Color(red: 0.416, green: 0.353, blue: 0.804), lineWidth: 8).frame(width: 100, height: 100)
                Text(timeString).font(.title2).bold()
            }
            .padding(.top, 32)
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.416, green: 0.353, blue: 0.804))
                .symbolEffect(.pulse)
            Text("BLE beacon is active\nStudents will be detected automatically")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer()
            Button(action: endSession) {
                Label("End Session", systemImage: "stop.circle.fill")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.red).cornerRadius(12)
            }
            .padding(.horizontal, 28).padding(.bottom, 16)
        }
    }

    private var sessionCompletedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 72))
                .foregroundColor(Color(red: 0.204, green: 0.659, blue: 0.325))
            Text("Session Ended").font(.title).bold()
            if let marked = markedCount, let enrolled = enrolledCount {
                Text("\(marked) / \(enrolled) students marked attendance").font(.title3).foregroundColor(.secondary)
            } else { ProgressView() }
            Text(cls.name).font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func computeTimeLeft() -> Int {
        guard startedAt > 0 else { return 0 }
        return Int((Date().timeIntervalSince1970 * 1000 - startedAt) / 1000)
    }

    private func fetchSummary() {
        guard !sessionId.isEmpty else { return }
        Task {
            struct Summary: Decodable { let enrolledCount: Int; let markedCount: Int }
            if let s: Summary = try? await APIClient.get("/api/professor/session/\(sessionId)/summary") {
                enrolledCount = s.enrolledCount; markedCount = s.markedCount
            }
        }
    }

    private func endSession() {
        guard !sessionId.isEmpty else { return }
        timer?.invalidate()
        Task {
            _ = try? await APIClient.postRaw("/api/professor/session/end/\(sessionId)", body: [:])
            await MainActor.run { timeLeft = 0 }
            fetchSummary()
        }
    }

    private var timeString: String { String(format: "%d:%02d", timeLeft / 60, timeLeft % 60) }
}

// MARK: - Manual Session View

struct ProfManualSessionView: View {
    let cls: ScheduledClass
    @State private var sessionId: String = ""
    @State private var students: [StudentEntry] = []
    @State private var isLoading = false
    @State private var submitted = false

    struct StudentEntry: Identifiable {
        let id: String
        let name: String
        var present: Bool
    }

    private let gBlue = Color(red: 0.102, green: 0.451, blue: 0.910)

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if submitted {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 72))
                        .foregroundColor(Color(red: 0.204, green: 0.659, blue: 0.325))
                    Text("Attendance Submitted").font(.title).bold()
                    Text("\(students.filter { $0.present }.count) / \(students.count) marked present")
                        .font(.title3).foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Text("\(students.filter { $0.present }.count) / \(students.count) present")
                        .font(.subheadline).bold()
                    Spacer()
                    Button("Mark All") { for i in students.indices { students[i].present = true } }
                        .font(.subheadline).foregroundColor(gBlue)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)

                List {
                    ForEach(students.indices, id: \.self) { i in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(students[i].name).font(.subheadline).fontWeight(.medium)
                                Text(students[i].id).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { students[i].present.toggle() }) {
                                Image(systemName: students[i].present ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(students[i].present ? Color(red: 0.204, green: 0.659, blue: 0.325) : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)

                Button(action: submitAttendance) {
                    Text("Submit Attendance")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(gBlue).cornerRadius(10)
                }
                .padding(16).background(Color.white)
            }
        }
        .navigationTitle("Manual Attendance")
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .task { await loadSession() }
    }

    private func loadSession() async {
        isLoading = true
        // Start a manual session to get a sessionId and enrolled students
        struct StartResp: Decodable {
            struct Session: Decodable { let id: String }
            let session: Session
        }
        struct AttendanceResp: Decodable {
            struct StudentStat: Decodable { let studentId: String; let name: String? }
            let students: [StudentStat]?
        }
        if let r: StartResp = try? await APIClient.post("/api/professor/session/start",
            body: ["courseCode": cls.code, "mode": "manual"]) {
            sessionId = r.session.id
        }
        if let ar: AttendanceResp = try? await APIClient.get("/api/professor/\(cls.code)/course/\(cls.code)/attendance") {
            students = (ar.students ?? []).map { StudentEntry(id: $0.studentId, name: $0.name ?? $0.studentId, present: false) }
        }
        isLoading = false
    }

    private func submitAttendance() {
        let presentIds = students.filter { $0.present }.map { $0.id }
        guard !presentIds.isEmpty, !sessionId.isEmpty else { return }
        Task {
            _ = try? await APIClient.post("/api/professor/session/\(sessionId)/manualAttendance",
                body: ["studentIds": presentIds]) as AnyCodable?
            _ = try? await APIClient.postRaw("/api/professor/session/end/\(sessionId)", body: [:])
            await MainActor.run { submitted = true }
        }
    }
}
