// Models/DailyLog.swift — NurseryConnectVision
// Named DailyLog (not Observation) to avoid shadowing Swift Observation framework.

import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var timestamp: Date
    var keyworkerName: String
    var eyfsArea: EYFSArea
    var activityDescription: String
    var learningNotes: String
    var hasSleepRecord: Bool
    var sleepStart: Date?
    var sleepEnd: Date?
    var hasNappyRecord: Bool
    var nappyType: NappyType?
    var nappyNotes: String
    var mood: MoodLevel
    var wellbeingNotes: String
    var child: Child?

    var sleepDurationMinutes: Int? {
        guard let s = sleepStart, let e = sleepEnd else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }

    var sleepDurationDescription: String {
        guard let m = sleepDurationMinutes else { return "N/A" }
        let h = m / 60, mins = m % 60
        return h > 0 ? "\(h)h \(mins)m" : "\(mins)m"
    }

    init(
        keyworkerName: String,
        eyfsArea: EYFSArea = .communication,
        activityDescription: String = "",
        learningNotes: String = "",
        hasSleepRecord: Bool = false,
        sleepStart: Date? = nil,
        sleepEnd: Date? = nil,
        hasNappyRecord: Bool = false,
        nappyType: NappyType? = nil,
        nappyNotes: String = "",
        mood: MoodLevel = .happy,
        wellbeingNotes: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.keyworkerName = keyworkerName
        self.eyfsArea = eyfsArea
        self.activityDescription = activityDescription
        self.learningNotes = learningNotes
        self.hasSleepRecord = hasSleepRecord
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.hasNappyRecord = hasNappyRecord
        self.nappyType = nappyType
        self.nappyNotes = nappyNotes
        self.mood = mood
        self.wellbeingNotes = wellbeingNotes
    }
}
