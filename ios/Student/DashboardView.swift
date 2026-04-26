import SwiftUI

private struct AnalyticsResponse: Decodable {
    struct CourseRecord: Decodable {
        let code: String
        let name: String
        let attended: Int
        let total: Int
        let percentage: Double
    }
    let courses: [CourseRecord]
}

struct Subject: Identifiable {
    let id = UUID()
    let name: String
    let code: String
    let bannerColor: Color
    var attended: Int
    var total: Int
    var percentage: Double
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var subjects: [Subject] = []
    @State private var isLoading = false

    private let colors: [Color] = [
        Color(red: 0.102, green: 0.451, blue: 0.910),
        Color(red: 0.204, green: 0.659, blue: 0.325),
        Color(red: 0.984, green: 0.467, blue: 0.094),
        Color(red: 0.416, green: 0.353, blue: 0.804),
    ]

    private var overall: Double {
        let a = subjects.reduce(0) { $0 + $1.attended }
        let t = subjects.reduce(0) { $0 + $1.total }
        return t > 0 ? Double(a) / Double(t) * 100 : 0
    }

    var body: some View {
        NavigationView {
                    ScrollView {
                        VStack(spacing: 16) {
                            if isLoading && subjects.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 100)
                            } else {
                                // Overall card
                                VStack(spacing: 6) {
                                    Text("Overall Attendance")
                                        .font(.subheadline).foregroundColor(.secondary)
                                    Text(String(format: "%.1f%%", overall))
                                        .font(.system(size: 56, weight: .bold))
                                        .foregroundColor(overall >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325) : .red)
                                    ProgressView(value: overall, total: 100)
                                        .progressViewStyle(LinearProgressViewStyle(
                                            tint: overall >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325) : .red))
                                        .padding(.horizontal, 32)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 24)
                                .background(Color.white).cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                                .padding(.horizontal)
        
                                ForEach(subjects) { subject in SubjectCard(subject: subject) }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable { await fetchAnalytics() }
                    .background(Color.gray.opacity(0.1))
                    .navigationTitle("Analytics")
                }
                .navigationViewStyle(.stack)
        .task { await fetchAnalytics() }
    }

    private func fetchAnalytics() async {
        guard !appState.userId.isEmpty else { return }
        isLoading = true
        do {
            let response: AnalyticsResponse = try await APIClient.get("/api/student/\(appState.userId)/analytics")
            subjects = response.courses.enumerated().map { i, c in
                Subject(name: c.name, code: c.code,
                        bannerColor: colors[i % colors.count],
                        attended: c.attended, total: c.total, percentage: c.percentage)
            }
        } catch {
            print("Analytics fetch error:", error)
        }
        isLoading = false
    }
}

struct SubjectCard: View {
    let subject: Subject
    private var statusColor: Color {
        subject.percentage >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325)
            : subject.percentage >= 60 ? Color(red: 0.984, green: 0.467, blue: 0.094) : .red
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                subject.bannerColor.frame(height: 60)
                Text(subject.name).font(.headline).bold().foregroundColor(.white)
                    .padding([.leading, .bottom], 12)
            }
            .clipShape(CornerShape(radius: 15, corners: [.topLeft, .topRight]))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.code).font(.caption).foregroundColor(.secondary)
                    ProgressView(value: subject.percentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                        .frame(width: 160)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", subject.percentage))
                        .font(.title2).bold().foregroundColor(statusColor)
                    Text("\(subject.attended)/\(subject.total) classes")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(14).background(Color.white)
            .clipShape(CornerShape(radius: 15, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
