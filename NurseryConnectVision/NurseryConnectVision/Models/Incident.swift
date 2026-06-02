// Models/Incident.swift — NurseryConnectVision
// RIDDOR-aligned incident report — schema matches iPad target exactly.

import Foundation
import SwiftData

// MARK: - Body Map Marker

struct BodyMapMarker: Codable, Identifiable, Equatable {
    var id: UUID
    var x: Double
    var y: Double
    var isFront: Bool
    var label: String

    init(x: Double, y: Double, isFront: Bool = true, label: String = "") {
        self.id = UUID()
        self.x = x
        self.y = y
        self.isFront = isFront
        self.label = label
    }
}

// MARK: - Incident Model

@Model
final class Incident {
    var id: UUID
    var timestamp: Date
    var keyworkerName: String
    var incidentType: IncidentType
    var title: String
    var descriptionText: String
    var location: String
    var bodyMapMarkersData: Data?
    var pencilDrawingFrontData: Data?
    var pencilDrawingBackData: Data?
    var riddorRequired: Bool
    var riddorRef: String
    var witnessNames: String
    var parentNotified: Bool
    var parentNotifiedAt: Date?
    var parentSignature: String
    var reviewStatus: ReviewStatus
    var managerName: String
    var managerNotes: String
    var countersignedAt: Date?
    var child: Child?

    var bodyMapMarkers: [BodyMapMarker] {
        get {
            guard let data = bodyMapMarkersData else { return [] }
            return (try? JSONDecoder().decode([BodyMapMarker].self, from: data)) ?? []
        }
        set {
            bodyMapMarkersData = try? JSONEncoder().encode(newValue)
        }
    }

    var frontMarkers: [BodyMapMarker] { bodyMapMarkers.filter {  $0.isFront } }
    var backMarkers:  [BodyMapMarker] { bodyMapMarkers.filter { !$0.isFront } }

    init(
        keyworkerName: String,
        incidentType: IncidentType = .accident,
        title: String = "",
        descriptionText: String = "",
        location: String = "",
        riddorRequired: Bool = false,
        witnessNames: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.keyworkerName = keyworkerName
        self.incidentType = incidentType
        self.title = title
        self.descriptionText = descriptionText
        self.location = location
        self.bodyMapMarkersData = nil
        self.riddorRequired = riddorRequired
        self.riddorRef = ""
        self.witnessNames = witnessNames
        self.parentNotified = false
        self.parentNotifiedAt = nil
        self.parentSignature = ""
        self.reviewStatus = .pendingReview
        self.managerName = ""
        self.managerNotes = ""
        self.countersignedAt = nil
    }
}
