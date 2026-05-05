import SwiftUI

// MARK: - Schedule Row

struct ScheduleRow: View {
    let schedule: AttendanceSchedule
    var onDelete: () -> Void
    @State private var showActions = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "alarm.fill")
                    .foregroundColor(schedule.method.color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.scheduledDay).font(.subheadline).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text(schedule.method.rawValue).font(.caption).foregroundColor(schedule.method.color)
                        Text("•").font(.caption).foregroundColor(.secondary)
                        Text("\(schedule.startTime) – \(schedule.endTime)").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
            .onLongPressGesture { withAnimation { showActions.toggle() } }

            if showActions {
                Divider()
                HStack(spacing: 0) {
                    Button(action: { showActions = false; onDelete() }) {
                        Label("Delete", systemImage: "trash")
                            .font(.subheadline).foregroundColor(.red)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                }
                .background(Color.gray.opacity(0.05))
            }
        }
    }
}

// MARK: - Add Schedule Sheet

struct AddScheduleSheet: View {
    var onAdd: (String, String, String, ProfMode) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var day = "Monday"
    @State private var startTime = "09:00"
    @State private var endTime = "10:00"
    @State private var method: ProfMode = .ble

    private let days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]

    var body: some View {
        NavigationView {
            Form {
                Section("Day") {
                    Picker("Day", selection: $day) {
                        ForEach(days, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Time") {
                    HStack {
                        Text("Start")
                        Spacer()
                        TextField("09:00", text: $startTime)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        TextField("10:00", text: $endTime)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
                Section("Method") {
                    Picker("Method", selection: $method) {
                        ForEach(ProfMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Schedule")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(day, startTime, endTime, method)
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
