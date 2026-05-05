import SwiftUI

// MARK: - Analytics Models

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

// MARK: - Analytics View

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
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 100)
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

// MARK: - Course Analytics Card

struct CourseAnalyticsCard: View {
    let course: CourseAnalytics
    private var pct: Double { course.overallPercentage }
    private var statusColor: Color { pct >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325) : pct >= 60 ? Color(red: 0.984, green: 0.467, blue: 0.094) : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                course.cls.bannerColor.frame(height: 56)
                Text(course.cls.name).font(.headline).bold().foregroundColor(.white).padding([.leading, .bottom], 12)
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

// MARK: - Course Analytics Detail

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
