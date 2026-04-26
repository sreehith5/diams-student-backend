import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

struct AdminCourse: Identifiable {
    let id = UUID()
    var name: String
    var code: String
    var room: String
    var slot: String
    var professors: [String]
    var students: [AdminStudent]
    var isArchived: Bool
    var year: Int
    var bannerColor: Color

    var averageAttendance: Double {
        guard !students.isEmpty else { return 0 }
        return students.reduce(0.0) { $0 + $1.attendancePercent } / Double(students.count)
    }
}

struct AdminStudent: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var roll: String
    var attendancePercent: Double
}

// MARK: - Sample Data (TODO: fetch from backend)

extension AdminCourse {
    static let samples: [AdminCourse] = [
        AdminCourse(name: "Swift App Dev",    code: "CS5.401", room: "Room 304", slot: "A", professors: ["Prof. Smith"],               students: sampleStudents(avg: 85), isArchived: false, year: 2024, bannerColor: Color(red: 0.102, green: 0.451, blue: 0.910)),
        AdminCourse(name: "Machine Learning", code: "CS5.301", room: "Room 101", slot: "B", professors: ["Prof. Rao"],                 students: sampleStudents(avg: 72), isArchived: false, year: 2024, bannerColor: Color(red: 0.204, green: 0.659, blue: 0.325)),
        AdminCourse(name: "Backend Dev",      code: "CS5.501", room: "Room 202", slot: "C", professors: ["Prof. Kumar"],               students: sampleStudents(avg: 91), isArchived: false, year: 2024, bannerColor: Color(red: 0.984, green: 0.467, blue: 0.094)),
        AdminCourse(name: "Swift App Dev",    code: "CS5.401", room: "Room 304", slot: "A", professors: ["Prof. Mehta"],               students: sampleStudents(avg: 78), isArchived: true,  year: 2023, bannerColor: Color(red: 0.102, green: 0.451, blue: 0.910)),
        AdminCourse(name: "Data Structures",  code: "CS3.201", room: "Room 105", slot: "D", professors: ["Prof. Rao", "Prof. Singh"],  students: sampleStudents(avg: 65), isArchived: false, year: 2024, bannerColor: Color(red: 0.416, green: 0.353, blue: 0.804)),
    ]

    static func sampleStudents(avg: Double) -> [AdminStudent] {[
        AdminStudent(name: "Sreehith Sanam", roll: "CS22BTECH11050", attendancePercent: min(avg + 5,  100)),
        AdminStudent(name: "Arjun Reddy",    roll: "CS22BTECH11023", attendancePercent: max(avg - 8,  0)),
        AdminStudent(name: "Priya Sharma",   roll: "CS22BTECH11031", attendancePercent: min(avg + 10, 100)),
        AdminStudent(name: "Kiran Kumar",    roll: "CS22BTECH11044", attendancePercent: max(avg - 15, 0)),
    ]}
}

// MARK: - Admin Courses View

struct AdminCoursesView: View {
    @State private var courses: [AdminCourse] = AdminCourse.samples
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var showCreateCourse = false
    @State private var showBulkCSV = false

    @State private var filterArchived: Bool? = nil
    @State private var filterSlot = ""
    @State private var filterProfessor = ""
    @State private var filterRoom = ""

    var filtered: [AdminCourse] {
        courses.filter { c in
            let q = searchText.lowercased()
            let matchSearch = q.isEmpty || c.name.lowercased().contains(q) || c.code.lowercased().contains(q) || c.professors.joined().lowercased().contains(q)
            let matchArchived  = filterArchived == nil || c.isArchived == filterArchived
            let matchSlot      = filterSlot.isEmpty      || c.slot.lowercased() == filterSlot.lowercased()
            let matchProf      = filterProfessor.isEmpty || c.professors.joined(separator: " ").lowercased().contains(filterProfessor.lowercased())
            let matchRoom      = filterRoom.isEmpty      || c.room.lowercased().contains(filterRoom.lowercased())
            return matchSearch && matchArchived && matchSlot && matchProf && matchRoom
        }
    }

    private var filterActive: Bool {
        filterArchived != nil || !filterSlot.isEmpty || !filterProfessor.isEmpty || !filterRoom.isEmpty
    }

    var body: some View {
        NavigationView {
                    VStack(spacing: 0) {
                        // Search + filter toggle
                        HStack(spacing: 10) {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                                TextField("Search courses, code, professor...", text: $searchText)
                            }
                            .padding(10).background(Color.white).cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.05), radius: 3)
        
                            Button(action: { showFilters.toggle() }) {
                                Image(systemName: filterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.title2)
                                    .foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 10)
                        .background(Color.gray.opacity(0.07))
        
                        // Filter panel
                        if showFilters {
                            VStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    AdminFilterChip(label: "All",      selected: filterArchived == nil)  { filterArchived = nil }
                                    AdminFilterChip(label: "Active",   selected: filterArchived == false) { filterArchived = false }
                                    AdminFilterChip(label: "Archived", selected: filterArchived == true)  { filterArchived = true }
                                    Spacer()
                                }
                                HStack(spacing: 8) {
                                    AdminFilterField(placeholder: "Slot",      text: $filterSlot)
                                    AdminFilterField(placeholder: "Professor", text: $filterProfessor)
                                    AdminFilterField(placeholder: "Room",      text: $filterRoom)
                                }
                            }
                            .padding(.horizontal).padding(.bottom, 10)
                            .background(Color.gray.opacity(0.07))
                        }
        
                        ScrollView {
                            VStack(spacing: 14) {
                                ForEach(filtered) { course in
                                    NavigationLink(destination: AdminCourseDetailView(course: courseBinding(course))) {
                                        AdminCourseCard(course: course)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical)
                        }
                        .background(Color.gray.opacity(0.07))
                    }
                    .navigationTitle("Courses")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack(spacing: 14) {
                                Button(action: { showBulkCSV = true }) {
                                    Image(systemName: "doc.badge.plus").font(.title3)
                                        .foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                                }
                                Button(action: { showCreateCourse = true }) {
                                    Image(systemName: "plus.circle.fill").font(.title3)
                                        .foregroundColor(Color(red: 0.102, green: 0.451, blue: 0.910))
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showCreateCourse) {
                        CreateCourseSheet { courses.append($0) }
                    }
                    .fileImporter(isPresented: $showBulkCSV, allowedContentTypes: [.commaSeparatedText]) { result in
                        if case .success(let url) = result { parseBulkCSV(url: url) }
                    }
                }
                .navigationViewStyle(.stack)
    }

    private func courseBinding(_ course: AdminCourse) -> Binding<AdminCourse> {
        guard let i = courses.firstIndex(where: { $0.id == course.id }) else { fatalError() }
        return $courses[i]
    }

    /// Expected CSV format (first row = header, ignored):
    /// course_name, course_code, room, slot, year, professor(s), student_name, student_roll
    /// One row per student. Courses are grouped by code+year+slot.
    private func parseBulkCSV(url: URL) {
        guard url.startAccessingSecurityScopedResource(),
              let content = try? String(contentsOf: url) else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        var courseMap: [String: AdminCourse] = [:]  // key = "code|year|slot"

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }.dropFirst() // skip header
        for line in lines {
            let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 8 else { continue }
            let (cName, cCode, room, slot) = (parts[0], parts[1], parts[2], parts[3])
            let year   = Int(parts[4]) ?? Calendar.current.component(.year, from: Date())
            let profs  = parts[5].components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            let sName  = parts[6]
            let sRoll  = parts[7]

            let key = "\(cCode)|\(year)|\(slot)"
            var course = courseMap[key] ?? AdminCourse(
                name: cName, code: cCode, room: room, slot: slot,
                professors: profs, students: [],
                isArchived: false, year: year,
                bannerColor: Color(red: 0.102, green: 0.451, blue: 0.910)
            )
            if !sName.isEmpty && !sRoll.isEmpty {
                course.students.append(AdminStudent(name: sName, roll: sRoll, attendancePercent: 0))
            }
            courseMap[key] = course
        }

        for course in courseMap.values {
            if !courses.contains(where: { $0.code == course.code && $0.year == course.year && $0.slot == course.slot }) {
                courses.append(course)
            }
        }
    }
}

struct AdminFilterChip: View {
    let label: String; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? Color(red: 0.102, green: 0.451, blue: 0.910) : Color.white)
                .foregroundColor(selected ? .white : .primary)
                .cornerRadius(8).shadow(color: Color.black.opacity(0.05), radius: 2)
        }
    }
}

struct AdminFilterField: View {
    let placeholder: String; @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text).font(.caption)
            .padding(8).background(Color.white).cornerRadius(8)
            .shadow(color: Color.black.opacity(0.05), radius: 2)
    }
}

// MARK: - Course Card

struct AdminCourseCard: View {
    let course: AdminCourse
    private var pct: Double { course.averageAttendance }
    private var statusColor: Color { pct >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325) : pct >= 60 ? Color(red: 0.984, green: 0.467, blue: 0.094) : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                (course.isArchived ? Color.gray : course.bannerColor).frame(height: 56)
                HStack(spacing: 8) {
                    Text(course.name).font(.headline).bold().foregroundColor(.white)
                    if course.isArchived {
                        Text("ARCHIVED").font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.white.opacity(0.3)).cornerRadius(4).foregroundColor(.white)
                    }
                }
                .padding([.leading, .bottom], 12)
            }
            .clipShape(CornerShape(radius: 15, corners: [.topLeft, .topRight]))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(course.code)  •  \(course.year)  •  Slot \(course.slot)").font(.caption).foregroundColor(.secondary)
                    Text(course.professors.joined(separator: ", ")).font(.caption).foregroundColor(.secondary)
                    Label(course.room, systemImage: "mappin").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", pct)).font(.title3).bold().foregroundColor(statusColor)
                    Text("avg attendance").font(.caption2).foregroundColor(.secondary)
                    ProgressView(value: pct, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                        .frame(width: 80)
                }
            }
            .padding(14).background(Color.white)
            .clipShape(CornerShape(radius: 15, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Course Detail

struct AdminCourseDetailView: View {
    @Binding var course: AdminCourse
    @State private var showEditCourse = false
    @State private var showCSVPicker = false
    @State private var showAddStudent = false
    private let gBlue = Color(red: 0.102, green: 0.451, blue: 0.910)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Info card
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        (course.isArchived ? Color.gray : course.bannerColor).frame(height: 56)
                        Text(course.name).font(.headline).bold().foregroundColor(.white)
                            .padding([.leading, .bottom], 12)
                    }
                    .clipShape(CornerShape(radius: 15, corners: [.topLeft, .topRight]))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(course.code)  •  Year \(course.year)  •  Slot \(course.slot)  •  \(course.room)")
                            .font(.caption).foregroundColor(.secondary)
                        Text("Professors: \(course.professors.joined(separator: ", "))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(14).background(Color.white)
                    .clipShape(CornerShape(radius: 15, corners: [.bottomLeft, .bottomRight]))
                }
                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                .padding(.horizontal)

                // Actions
                HStack(spacing: 10) {
                    AdminActionButton(label: "Edit", icon: "pencil", color: gBlue) { showEditCourse = true }
                    AdminActionButton(label: course.isArchived ? "Unarchive" : "Archive", icon: "archivebox", color: .orange) { course.isArchived.toggle() }
                }
                .padding(.horizontal)

                // Students
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Students (\(course.students.count))").font(.headline)
                        Spacer()
                        Button(action: { showCSVPicker = true }) {
                            Label("CSV", systemImage: "doc.badge.plus").font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.green.opacity(0.12)).foregroundColor(.green).cornerRadius(8)
                        }
                        Button(action: { showAddStudent = true }) {
                            Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(gBlue)
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(course.students) { student in
                            let pct = student.attendancePercent
                            let color: Color = pct >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325) : pct >= 60 ? Color(red: 0.984, green: 0.467, blue: 0.094) : .red
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(student.name).font(.subheadline).fontWeight(.medium)
                                    Text(student.roll).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.0f%%", pct)).font(.subheadline).bold().foregroundColor(color)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            if student.id != course.students.last?.id { Divider().padding(.horizontal) }
                        }
                    }
                    .background(Color.white).cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .navigationTitle(course.name)
        .sheet(isPresented: $showEditCourse) { EditCourseSheet(course: $course) }
        .sheet(isPresented: $showAddStudent) {
            AddStudentSheet { name, roll in
                course.students.append(AdminStudent(name: name, roll: roll, attendancePercent: 0))
            }
        }
        .fileImporter(isPresented: $showCSVPicker, allowedContentTypes: [.commaSeparatedText]) { result in
            if case .success(let url) = result { parseCSV(url: url) }
        }
    }

    private func parseCSV(url: URL) {
        guard url.startAccessingSecurityScopedResource(),
              let content = try? String(contentsOf: url) else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        for line in content.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
            let parts = line.components(separatedBy: ",")
            guard parts.count >= 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            let roll = parts[1].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty && !roll.isEmpty {
                course.students.append(AdminStudent(name: name, roll: roll, attendancePercent: 0))
            }
        }
    }
}

struct AdminActionButton: View {
    let label: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon).font(.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(color.opacity(0.12)).foregroundColor(color).cornerRadius(12)
        }
    }
}

// MARK: - Edit Course Sheet

struct EditCourseSheet: View {
    @Binding var course: AdminCourse
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var code: String
    @State private var room: String
    @State private var slot: String
    @State private var professors: String

    init(course: Binding<AdminCourse>) {
        _course     = course
        _name       = State(initialValue: course.wrappedValue.name)
        _code       = State(initialValue: course.wrappedValue.code)
        _room       = State(initialValue: course.wrappedValue.room)
        _slot       = State(initialValue: course.wrappedValue.slot)
        _professors = State(initialValue: course.wrappedValue.professors.joined(separator: ", "))
    }

    var body: some View {
        NavigationView {
                    Form {
                        Section("Course Info") {
                            TextField("Course Name", text: $name)
                            TextField("Course Code", text: $code)
                            TextField("Room", text: $room)
                            TextField("Slot", text: $slot)
                        }
                        Section("Professors (comma-separated)") {
                            TextField("e.g. Prof. Smith, Prof. Rao", text: $professors)
                        }
                    }
                    .navigationTitle("Edit Course")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                course.name = name; course.code = code; course.room = room; course.slot = slot
                                course.professors = professors.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    }
                }
                .navigationViewStyle(.stack)
    }
}

// MARK: - Create Course Sheet

struct CreateCourseSheet: View {
    var onCreate: (AdminCourse) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""; @State private var code = ""
    @State private var room = ""; @State private var slot = ""
    @State private var professors = ""
    @State private var year = Calendar.current.component(.year, from: Date())

    private let colors: [Color] = [
        Color(red: 0.102, green: 0.451, blue: 0.910), Color(red: 0.204, green: 0.659, blue: 0.325),
        Color(red: 0.984, green: 0.467, blue: 0.094), Color(red: 0.416, green: 0.353, blue: 0.804),
    ]
    @State private var selectedColor = 0

    var body: some View {
        NavigationView {
                    Form {
                        Section("Course Info") {
                            TextField("Course Name", text: $name)
                            TextField("Course Code (e.g. CS5.401)", text: $code)
                            TextField("Room", text: $room)
                            TextField("Slot (A, B, C...)", text: $slot)
                            Stepper("Year: \(year)", value: $year, in: 2020...2030)
                        }
                        Section("Professors (comma-separated)") {
                            TextField("e.g. Prof. Smith", text: $professors)
                        }
                        Section("Banner Color") {
                            HStack(spacing: 12) {
                                ForEach(0..<colors.count, id: \.self) { i in
                                    Circle().fill(colors[i]).frame(width: 28, height: 28)
                                        .overlay(Circle().stroke(Color.white, lineWidth: selectedColor == i ? 3 : 0))
                                        .shadow(radius: selectedColor == i ? 3 : 0)
                                        .onTapGesture { selectedColor = i }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .navigationTitle("New Course")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                guard !name.isEmpty, !code.isEmpty else { return }
                                let profs = professors.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                                onCreate(AdminCourse(name: name, code: code, room: room, slot: slot, professors: profs, students: [], isArchived: false, year: year, bannerColor: colors[selectedColor]))
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    }
                }
                .navigationViewStyle(.stack)
    }
}

// MARK: - Add Student Sheet

struct AddStudentSheet: View {
    var onAdd: (String, String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""; @State private var roll = ""

    var body: some View {
        NavigationView {
                    Form {
                        Section("Student Info") {
                            TextField("Full Name", text: $name)
                            TextField("Roll Number", text: $roll)
                        }
                    }
                    .navigationTitle("Add Student")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                guard !name.isEmpty, !roll.isEmpty else { return }
                                onAdd(name, roll); dismiss()
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    }
                }
                .navigationViewStyle(.stack)
    }
}

// MARK: - Admin Analytics

struct AdminAnalyticsView: View {
    @State private var tab = 0
    let courses = AdminCourse.samples

    var allStudents: [(name: String, roll: String, avgPct: Double)] {
        var map: [String: (name: String, total: Double, count: Int)] = [:]
        for course in courses where !course.isArchived {
            for s in course.students {
                if var e = map[s.roll] { e.total += s.attendancePercent; e.count += 1; map[s.roll] = e }
                else { map[s.roll] = (s.name, s.attendancePercent, 1) }
            }
        }
        return map.map { (roll, v) in (name: v.name, roll: roll, avgPct: v.total / Double(v.count)) }
            .sorted { $0.avgPct > $1.avgPct }
    }

    var professorStats: [(name: String, avgPct: Double)] {
        var map: [String: (total: Double, count: Int)] = [:]
        for course in courses where !course.isArchived {
            for prof in course.professors {
                if var e = map[prof] { e.total += course.averageAttendance; e.count += 1; map[prof] = e }
                else { map[prof] = (course.averageAttendance, 1) }
            }
        }
        return map.map { (name, v) in (name: name, avgPct: v.total / Double(v.count)) }
            .sorted { $0.avgPct > $1.avgPct }
    }

    var body: some View {
        NavigationView {
                    VStack(spacing: 0) {
                        Picker("", selection: $tab) {
                            Text("Students").tag(0)
                            Text("Professors").tag(1)
                        }
                        .pickerStyle(.segmented).padding()
        
                        List {
                            if tab == 0 {
                                ForEach(allStudents, id: \.roll) { s in
                                    AnalyticsRow(title: s.name, subtitle: s.roll, pct: s.avgPct)
                                }
                            } else {
                                ForEach(professorStats, id: \.name) { p in
                                    AnalyticsRow(title: p.name, subtitle: "Avg student attendance across courses", pct: p.avgPct)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                    .navigationTitle("Analytics")
                }
                .navigationViewStyle(.stack)
    }
}

struct AnalyticsRow: View {
    let title: String; let subtitle: String; let pct: Double
    private var color: Color { pct >= 75 ? Color(red: 0.204, green: 0.659, blue: 0.325) : pct >= 60 ? Color(red: 0.984, green: 0.467, blue: 0.094) : .red }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
                ProgressView(value: pct, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: color)).frame(width: 140)
            }
            Spacer()
            Text(String(format: "%.0f%%", pct)).font(.title3).bold().foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}
