// Models/AttendanceRecord.swift — NurseryConnectVision
// EYFS Statutory Framework 2024 §3.76 daily register compliance.

import Foundation
import SwiftData

let kKeyworkerName = "Sarah Thompson"

enum AttendanceStatus: String, Codable, CaseIterable {
    case present   = "Present"
    case signedOut = "Signed Out"
    case absent    = "Absent"

    var sfSymbol: String {
        switch self {
        case .present:   return "person.fill.checkmark"
        case .signedOut: return "person.fill.xmark"
        case .absent:    return "person.slash"
        }
    }
}

@Model
final class AttendanceRecord {
    var id: UUID
    var date: Date
    var signedInAt: Date?
    var signedOutAt: Date?
    var signedInByName: String
    var signedOutByName: String
    var status: AttendanceStatus
    var notes: String
    var child: Child?

    var sessionDurationMinutes: Int? {
        guard let i = signedInAt, let o = signedOutAt else { return nil }
        return max(0, Int(o.timeIntervalSince(i) / 60))
    }

    var sessionDurationDescription: String {
        guard let m = sessionDurationMinutes else {
            return signedInAt != nil ? "In progress" : "—"
        }
        let h = m / 60, mins = m % 60
        return h > 0 ? "\(h)h \(mins)m" : "\(mins)m"
    }

    init(
        date: Date = Calendar.current.startOfDay(for: Date()),
        signedInAt: Date? = nil,
        signedOutAt: Date? = nil,
        signedInByName: String = kKeyworkerName,
        signedOutByName: String = "",
        status: AttendanceStatus = .absent,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.signedInAt = signedInAt
        self.signedOutAt = signedOutAt
        self.signedInByName = signedInByName
        self.signedOutByName = signedOutByName
        self.status = status
        self.notes = notes
    }
}
