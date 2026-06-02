// Models/EYFSMilestone.swift — NurseryConnectVision
// EYFS 2024 developmental milestone tracking.

import Foundation
import SwiftData

@Model
final class EYFSMilestone {
    var id: UUID
    var eyfsArea: EYFSArea
    var milestoneDescription: String
    var ageBand: String
    var status: MilestoneStatus
    var achievedDate: Date?
    var notes: String
    var lastUpdated: Date
    var keyworkerName: String
    var child: Child?

    init(
        eyfsArea: EYFSArea,
        milestoneDescription: String,
        ageBand: String = "",
        status: MilestoneStatus = .notStarted,
        keyworkerName: String = ""
    ) {
        self.id = UUID()
        self.eyfsArea = eyfsArea
        self.milestoneDescription = milestoneDescription
        self.ageBand = ageBand
        self.status = status
        self.achievedDate = nil
        self.notes = ""
        self.lastUpdated = Date()
        self.keyworkerName = keyworkerName
    }
}

enum EYFSMilestoneCatalogue {
    struct Template { let area: EYFSArea; let description: String; let ageBand: String }

    static let all: [Template] = [
        Template(area: .communication, description: "Listens and responds to simple instructions",       ageBand: "Birth–3"),
        Template(area: .communication, description: "Uses sentences of 4–6 words",                       ageBand: "3–4 years"),
        Template(area: .physical,      description: "Walks up and down stairs, alternating feet",         ageBand: "Birth–3"),
        Template(area: .physical,      description: "Holds pencil with comfortable grip",                 ageBand: "4–5 years"),
        Template(area: .personalSocial,description: "Initiates play with other children",                 ageBand: "3–4 years"),
        Template(area: .literacy,      description: "Recognises own name in print",                       ageBand: "3–4 years"),
        Template(area: .mathematics,   description: "Counts reliably to 5",                               ageBand: "Birth–3"),
        Template(area: .understanding, description: "Makes observations about plants/animals",             ageBand: "3–4 years"),
        Template(area: .expressive,    description: "Represents own ideas through drawing/painting",      ageBand: "3–4 years"),
    ]

    static func defaults(keyworkerName: String) -> [EYFSMilestone] {
        all.map { EYFSMilestone(eyfsArea: $0.area, milestoneDescription: $0.description,
                                ageBand: $0.ageBand, keyworkerName: keyworkerName) }
    }
}
