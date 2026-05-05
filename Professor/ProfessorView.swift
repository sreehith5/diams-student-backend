import SwiftUI

// MARK: - Professor Courses View

struct ProfessorCoursesView: View {
    @EnvironmentObject var appState: AppState
    @State private var classes: [ScheduledClass] = []

    private let colors: [Color] = [
        Color(red: 0.102, green: 0.451, blue: 0.910),
        Color(red: 0.204, green: 0.659, blue: 0.325),
        Color(red: 0.984, green: 0.467, blue: 0.094),
        Color(red: 0.416, green: 0.353, blue: 0.804),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(classes) { cls in
                        NavigationLink(destination: ClassDetailView(cls: cls)) {
                            CourseCard(cls: cls)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical)
            }
            .background(Color.gray.opacity(0.1))
            .navigationTitle("My Courses")
        }
        .navigationViewStyle(.stack)
        .task { await fetchCourses() }
    }

    private func fetchCourses() async {
        struct Course: Decodable {
            let _id: String?; let id: String?; let name: String
            let venue: String?; let room: String?; let slot: String?
            var code: String { _id ?? id ?? "" }
            var resolvedRoom: String { venue ?? room ?? "" }
            var resolvedSlot: String { slot ?? "A" }
        }
        struct CoursesResponse: Decodable { let courses: [Course] }
        guard !appState.userId.isEmpty,
              let response: CoursesResponse = try? await APIClient.get("/api/professor/\(appState.userId)/courses")
        else { return }
        classes = response.courses.enumerated().map { i, c in
            let slot = CourseSlot.all.first(where: { $0.name == c.resolvedSlot }) ?? CourseSlot.all[0]
            return ScheduledClass(name: c.name, code: c.code, room: c.resolvedRoom, slot: slot, bannerColor: colors[i % colors.count])
        }
    }
}

// MARK: - Course Card

struct CourseCard: View {
    let cls: ScheduledClass
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                cls.bannerColor.frame(height: 56)
                Text(cls.name).font(.headline).bold().foregroundColor(.white).padding([.leading, .bottom], 12)
            }
            .clipShape(CornerShape(radius: 15, corners: [.topLeft, .topRight]))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cls.code).font(.caption).foregroundColor(.secondary)
                    Label("Slot \(cls.slot.name)", systemImage: "calendar").font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        ForEach(cls.slot.sessions, id: \.day) { s in
                            Text(String(s.day.prefix(3)))
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(cls.bannerColor.opacity(0.15))
                                .foregroundColor(cls.bannerColor)
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                Label(cls.room, systemImage: "mappin").font(.caption).foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(CornerShape(radius: 15, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Class Detail View

struct ClassDetailView: View {
    let cls: ScheduledClass
    @EnvironmentObject var appState: AppState
    @State private var schedules: [AttendanceSchedule] = []
    @State private var showAddSchedule = false
    @State private var navigateTo: ProfMode? = nil
    @State private var existingSession: ActiveSessionResponse.Session? = nil
    @State private var showToast = false
    @State private var isCheckingSession = false
    @State private var sessionStartedAt: Double = 0
    @State private var sessionDuration: Int = 300
    @State private var sessionId: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Slot info card
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        cls.bannerColor.frame(height: 56)
                        Text(cls.name).font(.headline).bold().foregroundColor(.white).padding([.leading, .bottom], 12)
                    }
                    .clipShape(CornerShape(radius: 15, corners: [.topLeft, .topRight]))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(cls.code)  •  \(cls.room)  •  Slot \(cls.slot.name)")
                            .font(.subheadline).foregroundColor(.secondary)
                        ForEach(cls.slot.sessions, id: \.day) { s in
                            HStack(spacing: 6) {
                                Text(s.day).font(.caption).fontWeight(.semibold).frame(width: 90, alignment: .leading)
                                Text(s.time).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(14).background(Color.white)
                    .clipShape(CornerShape(radius: 15, corners: [.bottomLeft, .bottomRight]))
                }
                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                .padding(.horizontal)

                // Go to Active Session
                if let existing = existingSession, existing.courseCode == cls.code {
                    Button(action: {
                        sessionStartedAt = existing.startedAt
                        sessionDuration  = existing.durationSeconds
                        sessionId        = existing.id
                        navigateTo = ProfMode.from(existing.mode)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text("Go to Active Session").font(.headline).fontWeight(.semibold)
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(red: 0.204, green: 0.659, blue: 0.325)).cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                // Start Session Now
                VStack(alignment: .leading, spacing: 10) {
                    Text("Start Attendance Now").font(.headline).padding(.horizontal)

                    Group {
                        NavigationLink(
                            destination: ProfQRSessionView(cls: cls, sessionId: $sessionId, startedAt: sessionStartedAt, durationSeconds: sessionDuration),
                            isActive: Binding(get: { navigateTo == .qr }, set: { if !$0 { navigateTo = nil } })
                        ) { EmptyView() }
                        NavigationLink(
                            destination: ProfBLESessionView(cls: cls, sessionId: $sessionId, startedAt: sessionStartedAt, durationSeconds: sessionDuration),
                            isActive: Binding(get: { navigateTo == .ble }, set: { if !$0 { navigateTo = nil } })
                        ) { EmptyView() }
                        NavigationLink(
                            destination: ProfManualSessionView(cls: cls),
                            isActive: Binding(get: { navigateTo == .manual }, set: { if !$0 { navigateTo = nil } })
                        ) { EmptyView() }
                    }

                    HStack(spacing: 10) {
                        ForEach(ProfMode.allCases, id: \.self) { mode in
                            Button(action: { Task { await handleStartSession(mode: mode) } }) {
                                VStack(spacing: 6) {
                                    if isCheckingSession {
                                        ProgressView().frame(width: 22, height: 22)
                                    } else {
                                        Image(systemName: mode.icon).font(.system(size: 22))
                                    }
                                    Text(mode.rawValue).font(.caption).fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(mode.color.opacity(0.12)).foregroundColor(mode.color).cornerRadius(12)
                            }
                            .disabled(isCheckingSession)
                        }
                    }
                    .padding(.horizontal)
                }

                // Attendance Schedules
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Attendance Schedules").font(.headline)
                        Spacer()
                        Button(action: { showAddSchedule = true }) {
                            Image(systemName: "plus.circle.fill").font(.title3)
                                .foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                        }
                    }
                    .padding(.horizontal)

                    if schedules.isEmpty {
                        Text("No schedules yet").font(.subheadline).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.white).cornerRadius(15)
                            .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(schedules) { schedule in
                                ScheduleRow(schedule: schedule, onDelete: { deleteSchedule(schedule) })
                                if schedule.id != schedules.last?.id { Divider().padding(.horizontal) }
                            }
                        }
                        .background(Color.white).cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.gray.opacity(0.1))
        .navigationTitle(cls.name)
        .onAppear { Task { await fetchExistingSession(); await fetchSchedules() } }
        .sheet(isPresented: $showAddSchedule) {
            AddScheduleSheet { day, start, end, method in
                Task { await addSchedule(day: day, start: start, end: end, method: method) }
            }
        }
        .overlay(alignment: .top) {
            if showToast {
                Text("Active session already running")
                    .font(.subheadline).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.black.opacity(0.75)).cornerRadius(10)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Private functions

    private func fetchExistingSession() async {
        guard !appState.userId.isEmpty else { return }
        do {
            let response: ActiveSessionResponse = try await APIClient.get(
                "/api/professor/\(appState.userId)/activeSession"
            )
            existingSession = response.session
        } catch {
            print("fetchExistingSession error: \(error)")
        }
    }

    private func fetchSchedules() async {
        struct ScheduleResp: Decodable {
            let schedules: [[String: AnyCodable]]?
        }
        guard let resp: ScheduleResp = try? await APIClient.get("/api/professor/\(cls.code)/schedule") else { return }
        let raw = resp.schedules ?? []
        schedules = raw.enumerated().compactMap { i, dict in
            let plain = dict.mapValues { $0.value }
            return AttendanceSchedule.from(plain, index: i)
        }
    }

    private func addSchedule(day: String, start: String, end: String, method: ProfMode) async {
        struct Resp: Decodable { let success: Bool? }
        _ = try? await APIClient.post("/api/professor/\(cls.code)/schedule",
            body: ["scheduledDay": day, "startTime": start, "endTime": end, "method": method.backendString]) as Resp?
        await fetchSchedules()
    }

    private func deleteSchedule(_ schedule: AttendanceSchedule) {
        Task {
            _ = try? await APIClient.postRaw("/api/professor/\(cls.code)/schedule/\(schedule.id)", body: [:])
            await fetchSchedules()
        }
    }

    private func handleStartSession(mode: ProfMode) async {
        guard !appState.userId.isEmpty else { return }
        isCheckingSession = true
        do {
            let response: ActiveSessionResponse = try await APIClient.get(
                "/api/professor/\(appState.userId)/activeSession"
            )
            if let existing = response.session {
                sessionStartedAt = existing.startedAt
                sessionDuration  = existing.durationSeconds
                sessionId        = existing.id
                navigateTo = ProfMode.from(existing.mode)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { showToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showToast = false } }
                }
            } else {
                struct StartResponse: Decodable {
                    struct Session: Decodable { let id: String; let startedAt: Double; let durationSeconds: Int }
                    let session: Session
                }
                let result: StartResponse = try await APIClient.post(
                    "/api/professor/session/start",
                    body: ["professorId": appState.userId, "courseCode": cls.code, "mode": mode.backendString]
                )
                sessionStartedAt = result.session.startedAt
                sessionDuration  = result.session.durationSeconds
                sessionId        = result.session.id
                navigateTo = mode
            }
        } catch {
            print("handleStartSession error: \(error)")
        }
        isCheckingSession = false
    }
}
