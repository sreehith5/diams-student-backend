import SwiftUI

// MARK: - Slot Model

struct CourseSlot: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let durationMinutes: Int   // 60 or 90
    let sessions: [SlotSession]

    struct SlotSession: Hashable {
        let day: String
        let time: String
    }

    // TODO: fetch slot definitions from backend if needed
    static let all: [CourseSlot] = [
        CourseSlot(name: "A", durationMinutes: 60, sessions: [
            SlotSession(day: "Monday",    time: "9:00 – 10:00 AM"),
            SlotSession(day: "Wednesday", time: "11:00 AM – 12:00 PM"),
            SlotSession(day: "Thursday",  time: "10:00 – 11:00 AM"),
        ]),
        CourseSlot(name: "B", durationMinutes: 60, sessions: [
            SlotSession(day: "Monday",    time: "10:00 – 11:00 AM"),
            SlotSession(day: "Wednesday", time: "9:00 – 10:00 AM"),
            SlotSession(day: "Thursday",  time: "11:00 AM – 12:00 PM"),
        ]),
        CourseSlot(name: "C", durationMinutes: 60, sessions: [
            SlotSession(day: "Monday",    time: "11:00 AM – 12:00 PM"),
            SlotSession(day: "Wednesday", time: "10:00 – 11:00 AM"),
            SlotSession(day: "Thursday",  time: "9:00 – 10:00 AM"),
        ]),
        CourseSlot(name: "D", durationMinutes: 60, sessions: [
            SlotSession(day: "Monday",    time: "12:00 – 1:00 PM"),
            SlotSession(day: "Tuesday",   time: "9:00 – 10:00 AM"),
            SlotSession(day: "Friday",    time: "11:00 AM – 12:00 PM"),
        ]),
        CourseSlot(name: "E", durationMinutes: 60, sessions: [
            SlotSession(day: "Tuesday",   time: "10:00 – 11:00 AM"),
            SlotSession(day: "Thursday",  time: "12:00 – 1:00 PM"),
            SlotSession(day: "Friday",    time: "9:00 – 10:00 AM"),
        ]),
        CourseSlot(name: "F", durationMinutes: 60, sessions: [
            SlotSession(day: "Tuesday",   time: "11:00 AM – 12:00 PM"),
            SlotSession(day: "Wednesday", time: "2:30 – 4:00 PM"),
            SlotSession(day: "Friday",    time: "10:00 – 11:00 AM"),
        ]),
        CourseSlot(name: "G", durationMinutes: 60, sessions: [
            SlotSession(day: "Tuesday",   time: "12:00 – 1:00 PM"),
            SlotSession(day: "Wednesday", time: "12:00 – 1:00 PM"),
            SlotSession(day: "Friday",    time: "12:00 – 1:00 PM"),
        ]),
        CourseSlot(name: "P", durationMinutes: 90, sessions: [
            SlotSession(day: "Monday",    time: "2:30 – 4:00 PM"),
            SlotSession(day: "Thursday",  time: "4:00 – 5:30 PM"),
        ]),
        CourseSlot(name: "Q", durationMinutes: 90, sessions: [
            SlotSession(day: "Monday",    time: "4:00 – 5:30 PM"),
            SlotSession(day: "Thursday",  time: "2:30 – 4:00 PM"),
        ]),
        CourseSlot(name: "R", durationMinutes: 90, sessions: [
            SlotSession(day: "Tuesday",   time: "2:30 – 4:00 PM"),
            SlotSession(day: "Friday",    time: "4:00 – 5:30 PM"),
        ]),
        CourseSlot(name: "S", durationMinutes: 90, sessions: [
            SlotSession(day: "Tuesday",   time: "4:00 – 5:30 PM"),
            SlotSession(day: "Friday",    time: "2:30 – 4:00 PM"),
        ]),
        CourseSlot(name: "W", durationMinutes: 90, sessions: [
            SlotSession(day: "Monday",    time: "5:30 – 7:00 PM"),
            SlotSession(day: "Thursday",  time: "5:30 – 7:00 PM"),
        ]),
        CourseSlot(name: "X", durationMinutes: 90, sessions: [
            SlotSession(day: "Monday",    time: "7:00 – 8:30 PM"),
            SlotSession(day: "Thursday",  time: "7:00 – 8:30 PM"),
        ]),
        CourseSlot(name: "Y", durationMinutes: 90, sessions: [
            SlotSession(day: "Tuesday",   time: "5:30 – 7:00 PM"),
            SlotSession(day: "Friday",    time: "5:30 – 7:00 PM"),
        ]),
        CourseSlot(name: "Z", durationMinutes: 90, sessions: [
            SlotSession(day: "Tuesday",   time: "7:00 – 8:30 PM"),
            SlotSession(day: "Friday",    time: "7:00 – 8:30 PM"),
        ]),
    ]
}

// MARK: - Models

struct ScheduledClass: Identifiable {
    let id = UUID()
    let name: String
    let code: String
    let room: String
    let slot: CourseSlot
    let bannerColor: Color
}

struct AttendanceSchedule: Identifiable {
    let id = UUID()
    var label: String
    var mode: ProfMode
    var triggerMinutes: Int   // minutes after class start
    var isEnabled: Bool
}

enum ProfMode: String, CaseIterable {
    case qr = "QR Code"
    case ble = "BLE"
    case manual = "Manual"
    var icon: String {
        switch self {
        case .qr:     return "qrcode.viewfinder"
        case .ble:    return "antenna.radiowaves.left.and.right"
        case .manual: return "list.clipboard.fill"
        }
    }
    var color: Color {
        switch self {
        case .qr:     return Color(red: 0.102, green: 0.451, blue: 0.910)
        case .ble:    return Color(red: 0.416, green: 0.353, blue: 0.804)
        case .manual: return Color(red: 0.984, green: 0.467, blue: 0.094)
        }
    }
    // Maps to backend mode strings
    var backendString: String {
        switch self {
        case .qr:     return "qr"
        case .ble:    return "ble"
        case .manual: return "manual"
        }
    }
    static func from(_ backendString: String) -> ProfMode {
        switch backendString.lowercased() {
        case "ble":    return .ble
        case "manual": return .manual
        default:       return .qr
        }
    }
}

// MARK: - Professor Courses View (replaces both Schedule + Session tabs)

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
            let _id: String?
            let id: String?
            let name: String
            let venue: String?
            let room: String?
            let slot: String?
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

struct CourseCard: View {
    let cls: ScheduledClass
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                cls.bannerColor.frame(height: 56)
                Text(cls.name)
                    .font(.headline).bold().foregroundColor(.white)
                    .padding([.leading, .bottom], 12)
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

// MARK: - Active session response from backend
private struct ActiveSessionResponse: Decodable {
    struct Session: Decodable {
        let id: String
        let courseCode: String
        let mode: String
        let professorId: String
        let startedAt: Double
        let durationSeconds: Int
    }
    let session: Session?
}

// MARK: - Class Detail

struct ClassDetailView: View {
    let cls: ScheduledClass
    @EnvironmentObject var appState: AppState
    @State private var schedules: [AttendanceSchedule] = [
        AttendanceSchedule(label: "Auto-trigger at class start", mode: .qr,  triggerMinutes: 0,  isEnabled: true),
        AttendanceSchedule(label: "Mid-class check",             mode: .ble, triggerMinutes: 30, isEnabled: false),
    ]
    @State private var showAddSchedule = false
    @State private var editingSchedule: AttendanceSchedule? = nil

    // Active session enforcement
    @State private var navigateTo: ProfMode? = nil
    @State private var existingSession: ActiveSessionResponse.Session? = nil
    @State private var showToast = false
    @State private var isCheckingSession = false
    @State private var sessionStartedAt: Double = 0
    @State private var sessionDuration: Int = 120
    @State private var sessionId: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Slot info card
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        cls.bannerColor.frame(height: 56)
                        Text(cls.name)
                            .font(.headline).bold().foregroundColor(.white)
                            .padding([.leading, .bottom], 12)
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
                    .padding(14)
                    .background(Color.white)
                    .clipShape(CornerShape(radius: 15, corners: [.bottomLeft, .bottomRight]))
                }
                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                .padding(.horizontal)

                // Go to Active Session button — shown when this course has an active session
                if let existing = existingSession, existing.courseCode == cls.code {
                    Button(action: {
                        sessionStartedAt = existing.startedAt
                        sessionDuration  = existing.durationSeconds
                        sessionId        = existing.id
                        navigateTo = ProfMode.from(existing.mode)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text("Go to Active Session")
                                .font(.headline).fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.204, green: 0.659, blue: 0.325))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                // Start Session Now
                VStack(alignment: .leading, spacing: 10) {
                    Text("Start Attendance Now")
                        .font(.headline).padding(.horizontal)

                    // Hidden NavigationLinks driven by navigateTo state
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
                                .background(mode.color.opacity(0.12))
                                .foregroundColor(mode.color)
                                .cornerRadius(12)
                            }
                            .disabled(isCheckingSession)
                        }
                    }
                    .padding(.horizontal)
                }

                // Scheduled Attendances
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Attendance Schedules")
                            .font(.headline)
                        Spacer()
                        Button(action: { showAddSchedule = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach($schedules) { $schedule in
                            ScheduleRow(
                                schedule: $schedule,
                                onEdit: { editingSchedule = schedule },
                                onDelete: { schedules.removeAll { $0.id == schedule.id } }
                            )
                            if schedule.id != schedules.last?.id {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.gray.opacity(0.1))
        .navigationTitle(cls.name)
        .onAppear { Task { await fetchExistingSession() } }
        .sheet(isPresented: $showAddSchedule) {
            AddScheduleSheet(classDuration: cls.slot.durationMinutes) { newSchedule in schedules.append(newSchedule) }
        }
        .sheet(item: $editingSchedule) { schedule in
            EditScheduleSheet(schedule: schedule, classDuration: cls.slot.durationMinutes) { updated in
                if let i = schedules.firstIndex(where: { $0.id == updated.id }) {
                    schedules[i] = updated
                }
            }
        }
        .overlay(alignment: .top) {
            if showToast {
                Text("Active session already running")
                    .font(.subheadline).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(10)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func fetchExistingSession() async {
        guard !appState.userId.isEmpty else { return }
        if let response: ActiveSessionResponse = try? await APIClient.get("/api/professor/\(appState.userId)/activeSession") {
            existingSession = response.session
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
                // Show toast after navigation lands
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

// MARK: - Schedule Row with long-press

struct ScheduleRow: View {
    @Binding var schedule: AttendanceSchedule
    var onEdit: () -> Void
    var onDelete: () -> Void
    @State private var showActions = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "alarm.fill")
                    .foregroundColor(schedule.mode.color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.label).font(.subheadline).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text(schedule.mode.rawValue).font(.caption).foregroundColor(schedule.mode.color)
                        Text("•").font(.caption).foregroundColor(.secondary)
                        Text(schedule.triggerMinutes == 0 ? "At class start" : "+\(schedule.triggerMinutes) min")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: $schedule.isEnabled)
                    .labelsHidden()
                    .tint(Color(red: 0.102, green: 0.451, blue: 0.910))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
            .onLongPressGesture { withAnimation { showActions.toggle() } }

            // Inline actions — appear below the row on long press
            if showActions {
                Divider()
                HStack(spacing: 0) {
                    Button(action: { showActions = false; onEdit() }) {
                        Label("Edit", systemImage: "pencil")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    Divider().frame(height: 36)
                    Button(action: { showActions = false; onDelete() }) {
                        Label("Delete", systemImage: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                }
                .background(Color.gray.opacity(0.05))
            }
        }
    }
}

// MARK: - Analog-style trigger time dial

struct TriggerTimeDial: View {
    @Binding var minutes: Int
    let classDuration: Int

    private let gBlue = Color(red: 0.102, green: 0.451, blue: 0.910)
    private var angle: Double { Double(minutes) / Double(classDuration) * 360 - 90 }
    private var knobPos: CGPoint {
        let r = 90.0
        let rad = angle * .pi / 180
        return CGPoint(x: 110 + r * cos(rad), y: 110 + r * sin(rad))
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: CGFloat(minutes) / CGFloat(classDuration))
                    .stroke(gBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .animation(.easeOut(duration: 0.15), value: minutes)
                VStack(spacing: 2) {
                    Text(minutes == 0 ? "Start" : "+\(minutes)")
                        .font(.title2).bold()
                    Text(minutes == 0 ? "" : "min")
                        .font(.caption).foregroundColor(.secondary)
                }
                Circle()
                    .fill(gBlue)
                    .frame(width: 24, height: 24)
                    .shadow(radius: 3)
                    .position(knobPos)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let center = CGPoint(x: 110, y: 110)
                            let dx = val.location.x - center.x
                            let dy = val.location.y - center.y
                            var deg = atan2(dy, dx) * 180 / .pi + 90
                            if deg < 0 { deg += 360 }
                            let raw = Int(deg / 360 * Double(classDuration))
                            minutes = min(max(raw, 0), classDuration)
                        }
                    )
            }
            .frame(width: 220, height: 220)

            HStack(spacing: 0) {
                ForEach(Array(stride(from: 0, through: classDuration, by: 15)), id: \.self) { m in
                    Text("\(m)").font(.system(size: 10)).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 220)
        }
    }
}

// MARK: - Add Schedule Sheet

struct AddScheduleSheet: View {
    let classDuration: Int
    var onAdd: (AttendanceSchedule) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var label = ""
    @State private var mode: ProfMode = .qr
    @State private var triggerMinutes = 0

    var body: some View {
        NavigationView {
                    Form {
                        Section("Label") {
                            TextField("e.g. Mid-class check", text: $label)
                        }
                        Section("Mode") {
                            Picker("Mode", selection: $mode) {
                                ForEach(ProfMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        Section("Trigger — minutes after class starts (\(classDuration) min class)") {
                            HStack {
                                Spacer()
                                TriggerTimeDial(minutes: $triggerMinutes, classDuration: classDuration)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .navigationTitle("Add Schedule")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                onAdd(AttendanceSchedule(
                                    label: label.isEmpty ? "Scheduled" : label,
                                    mode: mode,
                                    triggerMinutes: triggerMinutes,
                                    isEnabled: true
                                ))
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                }
                .navigationViewStyle(.stack)
    }
}

// MARK: - Edit Schedule Sheet

struct EditScheduleSheet: View {
    let schedule: AttendanceSchedule
    let classDuration: Int
    var onSave: (AttendanceSchedule) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var label: String
    @State private var mode: ProfMode
    @State private var triggerMinutes: Int

    init(schedule: AttendanceSchedule, classDuration: Int, onSave: @escaping (AttendanceSchedule) -> Void) {
        self.schedule = schedule
        self.classDuration = classDuration
        self.onSave = onSave
        _label          = State(initialValue: schedule.label)
        _mode           = State(initialValue: schedule.mode)
        _triggerMinutes = State(initialValue: schedule.triggerMinutes)
    }

    var body: some View {
        NavigationView {
                    Form {
                        Section("Label") {
                            TextField("Label", text: $label)
                        }
                        Section("Mode") {
                            Picker("Mode", selection: $mode) {
                                ForEach(ProfMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        Section("Trigger — minutes after class starts (\(classDuration) min class)") {
                            HStack {
                                Spacer()
                                TriggerTimeDial(minutes: $triggerMinutes, classDuration: classDuration)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .navigationTitle("Edit Schedule")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                onSave(AttendanceSchedule(
                                    label: label,
                                    mode: mode,
                                    triggerMinutes: triggerMinutes,
                                    isEnabled: schedule.isEnabled
                                ))
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                }
                .navigationViewStyle(.stack)
    }
}

// MARK: - QR Session View

struct ProfQRSessionView: View {
    let cls: ScheduledClass
    @Binding var sessionId: String
    var startedAt: Double = 0
    var durationSeconds: Int = 120
    @State private var timeLeft = 120
    @State private var qrUIImage: UIImage? = nil
    @State private var timer: Timer? = nil
    @State private var qrRefreshTimer: Timer? = nil
    @State private var markedCount: Int? = nil
    @State private var enrolledCount: Int? = nil

    private func computeTimeLeft() -> Int {
            guard startedAt > 0 else { return 0 }
            return Int((Date().timeIntervalSince1970 * 1000 - startedAt) / 1000)
        }

    var body: some View {
        Group {
            if timeLeft == 0 {
                sessionCompletedView
            } else {
                activeView
            }
        }
        .navigationTitle("QR Attendance")
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .onAppear {
            timeLeft = computeTimeLeft()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                timeLeft += 1
            }
            fetchQR()
            qrRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in fetchQR() }
        }
        .onDisappear { stopTimers() }
    }

    private var activeView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 8).frame(width: 100, height: 100)
                Circle()
                                    .stroke(Color(red: 0.102, green: 0.451, blue: 0.910), lineWidth: 8)
                                    .frame(width: 100, height: 100)
                Text(timeString).font(.title2).bold()
            }
            .padding(.top, 32)
            Text("QR refreshes every 5 seconds").font(.caption).foregroundColor(.secondary)
            Group {
                if let img = qrUIImage {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable().scaledToFit()
                        .frame(width: 220, height: 220)
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
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundColor(Color(red: 0.204, green: 0.659, blue: 0.325))
            Text("Session Ended").font(.title).bold()
            if let marked = markedCount, let enrolled = enrolledCount {
                Text("\(marked) / \(enrolled) students marked attendance")
                    .font(.title3).foregroundColor(.secondary)
            } else {
                ProgressView()
            }
            Text(cls.name).font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func fetchSummary() {
        guard !sessionId.isEmpty else { return }
        Task {
            struct Summary: Decodable { let enrolledCount: Int; let markedCount: Int }
            if let s: Summary = try? await APIClient.get("/api/professor/session/\(sessionId)/summary") {
                enrolledCount = s.enrolledCount
                markedCount   = s.markedCount
            }
        }
    }

    private func fetchQR() {
        Task {
            struct QRResp: Decodable { let hash: String? }
            guard let resp: QRResp = try? await APIClient.post("/api/qr/generate", body: ["class_id": cls.room]),
                  let hash = resp.hash else { return }
            // Encode JSON payload so student app can extract both hash and class_id
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
    @State private var timeLeft = 120
    @State private var timer: Timer? = nil
    @State private var markedCount: Int? = nil
    @State private var enrolledCount: Int? = nil

    private func computeTimeLeft() -> Int {
            guard startedAt > 0 else { return 0 }
            return Int((Date().timeIntervalSince1970 * 1000 - startedAt) / 1000)
        }

    var body: some View {
        Group {
            if timeLeft == 0 {
                sessionCompletedView
            } else {
                activeView
            }
        }
        .navigationTitle("BLE Attendance")
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .onAppear {
            timeLeft = computeTimeLeft()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                timeLeft += 1
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private var activeView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 8).frame(width: 100, height: 100)
                Circle()
                                    .stroke(Color(red: 0.416, green: 0.353, blue: 0.804), lineWidth: 8)
                                    .frame(width: 100, height: 100)
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
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundColor(Color(red: 0.204, green: 0.659, blue: 0.325))
            Text("Session Ended").font(.title).bold()
            if let marked = markedCount, let enrolled = enrolledCount {
                Text("\(marked) / \(enrolled) students marked attendance")
                    .font(.title3).foregroundColor(.secondary)
            } else {
                ProgressView()
            }
            Text(cls.name).font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func fetchSummary() {
        guard !sessionId.isEmpty else { return }
        Task {
            struct Summary: Decodable { let enrolledCount: Int; let markedCount: Int }
            if let s: Summary = try? await APIClient.get("/api/professor/session/\(sessionId)/summary") {
                enrolledCount = s.enrolledCount
                markedCount   = s.markedCount
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
    @State private var students: [(name: String, roll: String, present: Bool)] = [
        ("Sreehith Sanam", "CS22BTECH11050", false),
        ("Arjun Reddy",    "CS22BTECH11023", false),
        ("Priya Sharma",   "CS22BTECH11031", false),
        ("Kiran Kumar",    "CS22BTECH11044", false),
        ("Ananya Singh",   "CS22BTECH11012", false),
        ("Rahul Verma",    "CS22BTECH11067", false),
    ]
    private let gBlue = Color(red: 0.102, green: 0.451, blue: 0.910)

    var body: some View {
        VStack(spacing: 0) {
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
                            Text(students[i].roll).font(.caption).foregroundColor(.secondary)
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

            Button(action: { /* TODO: POST attendance to backend */ }) {
                Text("Submit Attendance")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(gBlue).cornerRadius(10)
            }
            .padding(16).background(Color.white)
        }
        .navigationTitle("Manual Attendance")
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
    }
}

// MARK: - Analytics

struct StudentRecord: Identifiable {
    let id = UUID()
    let name: String
    let roll: String
    let attended: Int
    let total: Int
    var percentage: Double { total > 0 ? Double(attended) / Double(total) * 100 : 0 }
}

struct CourseAnalytics: Identifiable {
    let id = UUID()
    let cls: ScheduledClass
    let students: [StudentRecord]
    var overallPercentage: Double {
        guard !students.isEmpty else { return 0 }
        return students.reduce(0) { $0 + $1.percentage } / Double(students.count)
    }
}

struct ProfessorAnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var courses: [CourseAnalytics] = []
    @State private var isLoading = false

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
                            if isLoading && courses.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity).padding(.top, 100)
                            } else if courses.isEmpty {
                                Text("No analytics available.").font(.subheadline).foregroundColor(.secondary).padding(.top, 60)
                            } else {
                                ForEach(courses) { course in
                                    NavigationLink(destination: CourseAnalyticsDetailView(course: course)) {
                                        CourseAnalyticsCard(course: course)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .background(Color.gray.opacity(0.1))
                    .navigationTitle("Analytics")
                }
                .navigationViewStyle(.stack)
        .task { await fetchAnalytics() }
    }

    private func fetchAnalytics() async {
        guard !appState.userId.isEmpty else { return }
        isLoading = true

        struct CourseResp: Decodable {
            let _id: String?; let id: String?; let name: String; let venue: String?; let slot: String?
            var code: String { _id ?? id ?? "" }
        }
        struct CoursesResp: Decodable { let courses: [CourseResp] }
        struct StudentStat: Decodable { let studentId: String; let name: String?; let attended: Int; let total: Int }
        struct AttendanceResp: Decodable { let students: [StudentStat]? }

        guard let cr: CoursesResp = try? await APIClient.get("/api/professor/\(appState.userId)/courses") else {
            isLoading = false; return
        }

        var result: [CourseAnalytics] = []
        for (i, c) in cr.courses.enumerated() {
            let ar: AttendanceResp? = try? await APIClient.get("/api/professor/\(appState.userId)/course/\(c.code)/attendance")
            let students = (ar?.students ?? []).map {
                StudentRecord(name: $0.name ?? $0.studentId, roll: $0.studentId, attended: $0.attended, total: $0.total)
            }
            let slot = CourseSlot.all.first(where: { $0.name == (c.slot ?? "A") }) ?? CourseSlot.all[0]
            let cls = ScheduledClass(name: c.name, code: c.code, room: c.venue ?? "", slot: slot, bannerColor: colors[i % colors.count])
            result.append(CourseAnalytics(cls: cls, students: students))
        }
        courses = result
        isLoading = false
    }
}

struct CourseAnalyticsCard: View {
    let course: CourseAnalytics
    private var pct: Double { course.overallPercentage }
    private var statusColor: Color { pct >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325) : pct >= 60 ? Color(red: 0.984, green: 0.467, blue: 0.094) : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                course.cls.bannerColor.frame(height: 56)
                Text(course.cls.name).font(.headline).bold().foregroundColor(.white)
                    .padding([.leading, .bottom], 12)
            }
            .clipShape(CornerShape(radius: 15, corners: [.topLeft, .topRight]))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.cls.code).font(.caption).foregroundColor(.secondary)
                    Text("\(course.students.count) students").font(.caption).foregroundColor(.secondary)
                    ProgressView(value: pct, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                        .frame(width: 160)
                }
                Spacer()
                Text(String(format: "%.0f%%", pct)).font(.title2).bold().foregroundColor(statusColor)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(CornerShape(radius: 15, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct CourseAnalyticsDetailView: View {
    let course: CourseAnalytics

    var body: some View {
        List {
            ForEach(course.students) { student in
                let pct = student.percentage
                let color: Color = pct >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325) : pct >= 60 ? Color(red: 0.984, green: 0.467, blue: 0.094) : .red
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(student.name).font(.subheadline).fontWeight(.medium)
                        Text(student.roll).font(.caption).foregroundColor(.secondary)
                        ProgressView(value: pct, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: color))
                            .frame(width: 140)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f%%", pct)).font(.title3).bold().foregroundColor(color)
                        Text("\(student.attended)/\(student.total)").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .navigationTitle(course.cls.name)
    }
}
