import SwiftUI

// MARK: - Slot Model

struct CourseSlot: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let durationMinutes: Int
    let sessions: [SlotSession]

    struct SlotSession: Hashable {
        let day: String
        let time: String
    }

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
    let id: String
    var scheduledDay: String
    var startTime: String
    var endTime: String
    var method: ProfMode
}

extension AttendanceSchedule {
    static func from(_ dict: [String: Any], index: Int) -> AttendanceSchedule {
        let methodStr = dict["method"] as? String ?? "BLE"
        return AttendanceSchedule(
            id:           dict["_id"] as? String ?? "\(index)",
            scheduledDay: dict["scheduledDay"] as? String ?? "",
            startTime:    dict["startTime"] as? String ?? "",
            endTime:      dict["endTime"] as? String ?? "",
            method:       ProfMode.from(methodStr)
        )
    }
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

// MARK: - Active session response from backend

struct ActiveSessionResponse: Decodable {
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
