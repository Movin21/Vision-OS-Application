// Models/Child.swift — NurseryConnectVision
// SwiftData schema must be byte-for-byte identical to the iPad target so the
// shared CloudKit / on-device store can be opened by both processes.

import Foundation
import SwiftData

// MARK: - Supporting Enums

enum EYFSArea: String, Codable, CaseIterable {
    case communication  = "Communication & Language"
    case physical       = "Physical Development"
    case personalSocial = "Personal, Social & Emotional"
    case literacy       = "Literacy"
    case mathematics    = "Mathematics"
    case understanding  = "Understanding the World"
    case expressive     = "Expressive Arts & Design"

    var sfSymbol: String {
        switch self {
        case .communication:  return "bubble.left.and.bubble.right"
        case .physical:       return "figure.run"
        case .personalSocial: return "heart.circle"
        case .literacy:       return "book"
        case .mathematics:    return "number.circle"
        case .understanding:  return "globe"
        case .expressive:     return "paintpalette"
        }
    }
}

enum MoodLevel: String, Codable, CaseIterable {
    case veryHappy  = "Very Happy"
    case happy      = "Happy"
    case neutral    = "Settled"
    case unsettled  = "Unsettled"
    case distressed = "Distressed"

    var emoji: String {
        switch self {
        case .veryHappy:  return "😄"
        case .happy:      return "🙂"
        case .neutral:    return "😐"
        case .unsettled:  return "😟"
        case .distressed: return "😢"
        }
    }

    var sfSymbol: String {
        switch self {
        case .veryHappy:  return "face.smiling.inverse"
        case .happy:      return "face.smiling"
        case .neutral:    return "face.dashed"
        case .unsettled:  return "exclamationmark.circle"
        case .distressed: return "xmark.circle.fill"
        }
    }
}

enum NappyType: String, Codable, CaseIterable {
    case wet    = "Wet"
    case soiled = "Soiled"
    case dry    = "Dry / Check"
    case mixed  = "Wet & Soiled"
}

enum ConsumptionLevel: String, Codable, CaseIterable {
    case all     = "All"
    case most    = "Most"
    case half    = "Half"
    case little  = "A Little"
    case refused = "Refused"
}

enum MealType: String, Codable, CaseIterable {
    case breakfast        = "Breakfast"
    case midMorningSnack  = "Mid-Morning Snack"
    case lunch            = "Lunch"
    case afternoonSnack   = "Afternoon Snack"
    case tea              = "Tea"
}

enum MilestoneStatus: String, Codable, CaseIterable {
    case notStarted = "Not Yet"
    case emerging   = "Emerging"
    case developing = "Developing"
    case achieved   = "Achieved"
}

enum IncidentType: String, Codable, CaseIterable {
    case accident     = "Accident"
    case nearMiss     = "Near Miss"
    case illness      = "Illness / Medical"
    case behavioural  = "Behavioural"
    case safeguarding = "Safeguarding Concern"

    var isRiddorRelevant: Bool {
        switch self {
        case .accident, .nearMiss: return true
        default:                   return false
        }
    }
}

enum ChildAgeBand: String, CaseIterable {
    case underTwo    = "Under 2 Years"
    case twoYears    = "2-3 Years"
    case threeToFive = "3-5 Years"
}

enum ReviewStatus: String, Codable, CaseIterable {
    case pendingReview  = "Pending Review"
    case underReview    = "Under Review"
    case countersigned  = "Countersigned"
    case requiresAction = "Requires Action"

    var sfSymbol: String {
        switch self {
        case .pendingReview:  return "clock.badge.exclamationmark"
        case .underReview:    return "eye.circle"
        case .countersigned:  return "checkmark.seal"
        case .requiresAction: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Child Model

@Model
final class Child {
    var id: UUID
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var photoData: Data?
    var assignedKeyworkerName: String
    var allergies: [String]
    var medicalNotes: String
    var dietaryRequirements: String
    var emergencyContactName: String
    var emergencyContactPhone: String

    @Relationship(deleteRule: .cascade) var observations: [DailyLog]
    @Relationship(deleteRule: .cascade) var mealRecords: [MealRecord]
    @Relationship(deleteRule: .cascade) var incidents: [Incident]
    @Relationship(deleteRule: .cascade) var milestones: [EYFSMilestone]
    @Relationship(deleteRule: .cascade) var attendanceRecords: [AttendanceRecord]

    var fullName: String { "\(firstName) \(lastName)" }

    var ageDescription: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: dateOfBirth, to: Date())
        let y = c.year ?? 0; let m = c.month ?? 0; let d = c.day ?? 0
        if y > 0 { return "\(y)y \(m)m \(d)d" }
        if m > 0 { return "\(m)m \(d)d" }
        return "\(d) days"
    }

    var isBirthdayToday: Bool {
        let cal = Calendar.current; let today = Date()
        return cal.component(.month, from: dateOfBirth) == cal.component(.month, from: today) &&
               cal.component(.day,   from: dateOfBirth) == cal.component(.day,   from: today)
    }

    var birthdayFormatted: String {
        dateOfBirth.formatted(.dateTime.day().month(.wide).year())
    }

    var hasActiveAlerts: Bool { !allergies.isEmpty || !medicalNotes.isEmpty }

    var initials: String { "\(firstName.prefix(1))\(lastName.prefix(1))" }
    var hasSevereAllergy: Bool { !allergies.isEmpty }
    var ageInYears: Int { Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0 }
    var ageBand: ChildAgeBand {
        if ageInYears < 2 { return .underTwo }
        if ageInYears < 3 { return .twoYears }
        return .threeToFive
    }

    init(
        firstName: String,
        lastName: String,
        dateOfBirth: Date,
        assignedKeyworkerName: String,
        allergies: [String] = [],
        medicalNotes: String = "",
        dietaryRequirements: String = "",
        emergencyContactName: String = "",
        emergencyContactPhone: String = ""
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.assignedKeyworkerName = assignedKeyworkerName
        self.allergies = allergies
        self.medicalNotes = medicalNotes
        self.dietaryRequirements = dietaryRequirements
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.observations      = []
        self.mealRecords       = []
        self.incidents         = []
        self.milestones        = []
        self.attendanceRecords = []
    }
}
