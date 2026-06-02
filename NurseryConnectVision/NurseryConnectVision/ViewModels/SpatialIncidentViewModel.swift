// ViewModels/SpatialIncidentViewModel.swift — NurseryConnectVision
// @Observable ViewModel owning all RealityKit state for the 3D Incident Inspector.
// Drives: body model construction, injury pin placement/update, attachment positioning,
// draft incident form fields, ornament filter, and alert banner collapse state.

import Foundation
import RealityKit
import SwiftUI
import SwiftData

// MARK: - Injury Classification

enum InjuryType: String, CaseIterable, Codable, Identifiable {
    case bruise   = "Bruise"
    case cut      = "Cut"
    case swelling = "Swelling"
    case burn     = "Burn"
    case redness  = "Redness"

    var id: String { rawValue }

    var pinColor: UIColor {
        switch self {
        case .bruise:   return UIColor(red: 0.45, green: 0.15, blue: 0.65, alpha: 1)
        case .cut:      return UIColor(red: 0.88, green: 0.12, blue: 0.12, alpha: 1)
        case .swelling: return UIColor(red: 0.98, green: 0.52, blue: 0.04, alpha: 1)
        case .burn:     return UIColor(red: 0.96, green: 0.30, blue: 0.08, alpha: 1)
        case .redness:  return UIColor(red: 0.92, green: 0.22, blue: 0.28, alpha: 1)
        }
    }

    var sfSymbol: String {
        switch self {
        case .bruise:   return "circle.fill"
        case .cut:      return "scissors"
        case .swelling: return "arrow.up.circle.fill"
        case .burn:     return "flame.fill"
        case .redness:  return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Spatial Injury Marker

struct SpatialInjuryMarker: Identifiable {
    let id: UUID
    var worldPosition: SIMD3<Float>
    var injuryType: InjuryType
    var note: String
    let pinEntity: ModelEntity

    init(worldPosition: SIMD3<Float>, injuryType: InjuryType = .bruise, note: String = "", pinEntity: ModelEntity) {
        self.id = UUID()
        self.worldPosition = worldPosition
        self.injuryType = injuryType
        self.note = note
        self.pinEntity = pinEntity
    }

    var bodyRegionName: String {
        let y = worldPosition.y
        if y > 1.10 { return "Head" }
        if y > 0.85 { return "Neck / Shoulders" }
        if y > 0.50 { return "Torso" }
        if y > 0.20 { return "Hips / Pelvis" }
        if y > -0.10 { return "Upper Legs" }
        return "Lower Legs / Feet"
    }
}

// MARK: - Filter Options

enum SafetyViewFilter: String, CaseIterable, Identifiable {
    case bodyMap  = "Body Map"
    case timeline = "Timeline"
    case alerts   = "Alerts"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .bodyMap:  return "figure.stand"
        case .timeline: return "clock.arrow.circlepath"
        case .alerts:   return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class SpatialIncidentViewModel {

    // MARK: Child context
    var selectedChild: Child?

    // MARK: Body model state
    var isBodyModelReady = false
    // Root entity of the procedural body — used by the update closure to parent pins.
    var bodyRootEntity = Entity()
    // When non-nil the update closure creates a new pin and clears this.
    var pendingTapWorldPosition: SIMD3<Float>? = nil

    // MARK: Injury markers (drives attachments ForEach + update loop)
    var injuryMarkers: [SpatialInjuryMarker] = []
    var selectedMarkerID: UUID? = nil

    // MARK: Ornament / filter
    var activeFilter: SafetyViewFilter = .bodyMap

    // MARK: Alert banner
    var isAlertBannerExpanded = true

    // MARK: Draft incident form
    var draftIncidentType: IncidentType = .accident
    var draftTitle = ""
    var draftDescription = ""
    var draftLocation = ""
    var draftWitnesses = ""
    var showIncidentForm = false
    var showSaveConfirmation = false

    // MARK: Immersive space
    var isImmersiveSpaceOpen = false

    // MARK: - Body Model Construction

    /// Builds the procedural child body from RealityKit primitives.
    /// Call once from the RealityView `make` closure.
    func buildBody(in content: RealityViewContent) {
        let root = Entity()
        root.name = "BodyRoot"

        let mat = makeBodyMaterial()

        let head = makePart(name: "head",
                            mesh: .generateSphere(radius: 0.115),
                            collisionShape: .generateSphere(radius: 0.115),
                            at: SIMD3(0, 0.72, 0),
                            material: mat)

        let neck = makePart(name: "neck",
                            mesh: .generateCylinder(height: 0.07, radius: 0.042),
                            collisionShape: .generateBox(size: SIMD3(0.085, 0.07, 0.085)),
                            at: SIMD3(0, 0.615, 0),
                            material: mat)

        let torso = makePart(name: "torso",
                             mesh: .generateBox(size: SIMD3(0.28, 0.36, 0.11), cornerRadius: 0.04),
                             collisionShape: .generateBox(size: SIMD3(0.28, 0.36, 0.11)),
                             at: SIMD3(0, 0.35, 0),
                             material: mat)

        let pelvis = makePart(name: "pelvis",
                              mesh: .generateBox(size: SIMD3(0.26, 0.09, 0.11), cornerRadius: 0.03),
                              collisionShape: .generateBox(size: SIMD3(0.26, 0.09, 0.11)),
                              at: SIMD3(0, 0.125, 0),
                              material: mat)

        let leftUpperArm = makeArmPart(name: "leftUpperArm",
                                       at: SIMD3(-0.20, 0.43, 0),
                                       tiltZ:  Float.pi / 10)

        let rightUpperArm = makeArmPart(name: "rightUpperArm",
                                        at: SIMD3( 0.20, 0.43, 0),
                                        tiltZ: -Float.pi / 10)

        let leftForeArm = makeForeArmPart(name: "leftForeArm",
                                          at: SIMD3(-0.29, 0.225, 0),
                                          tiltZ:  Float.pi / 9)

        let rightForeArm = makeForeArmPart(name: "rightForeArm",
                                           at: SIMD3( 0.29, 0.225, 0),
                                           tiltZ: -Float.pi / 9)

        let leftThigh = makeThighPart(name: "leftThigh",  at: SIMD3(-0.085, -0.085, 0))
        let rightThigh = makeThighPart(name: "rightThigh", at: SIMD3( 0.085, -0.085, 0))

        let leftShin = makeShinPart(name: "leftShin",  at: SIMD3(-0.085, -0.38, 0))
        let rightShin = makeShinPart(name: "rightShin", at: SIMD3( 0.085, -0.38, 0))

        let parts: [ModelEntity] = [
            head, neck, torso, pelvis,
            leftUpperArm, rightUpperArm, leftForeArm, rightForeArm,
            leftThigh, rightThigh, leftShin, rightShin
        ]
        for part in parts { root.addChild(part) }

        // Scaled to feel child-sized; placed roughly at standing height in scene
        root.scale    = SIMD3(repeating: 0.78)
        root.position = SIMD3(0, 0, -0.45)

        content.add(root)
        bodyRootEntity = root
        isBodyModelReady = true
    }

    // MARK: - Pin Sync (called from update closure)

    /// Creates a glowing pin entity for `pendingTapWorldPosition` and appends a marker.
    /// Must be called from inside the RealityView `update` closure so `content` is valid.
    func syncPendingPin(in content: RealityViewContent) {
        guard let pos = pendingTapWorldPosition else { return }
        pendingTapWorldPosition = nil               // clear before mutation triggers another update

        let pinEntity = makePinEntity(at: pos, type: .bruise)
        content.add(pinEntity)

        let marker = SpatialInjuryMarker(worldPosition: pos, injuryType: .bruise, pinEntity: pinEntity)
        injuryMarkers.append(marker)
        selectedMarkerID = marker.id
    }

    /// Updates the free-text note attached to a marker.
    func updateMarkerNote(_ markerID: UUID, note: String) {
        guard let idx = injuryMarkers.firstIndex(where: { $0.id == markerID }) else { return }
        injuryMarkers[idx].note = note
    }

    /// Updates the emissive colour of a pin when the user changes its injury type.
    func updateMarkerType(_ markerID: UUID, to type: InjuryType) {
        guard let idx = injuryMarkers.firstIndex(where: { $0.id == markerID }) else { return }
        injuryMarkers[idx].injuryType = type
        applyPinMaterial(to: injuryMarkers[idx].pinEntity, type: type)
    }

    /// Removes a marker and its entity from the scene.
    func removeMarker(_ markerID: UUID) {
        guard let idx = injuryMarkers.firstIndex(where: { $0.id == markerID }) else { return }
        injuryMarkers[idx].pinEntity.removeFromParent()
        injuryMarkers.remove(at: idx)
        if selectedMarkerID == markerID { selectedMarkerID = nil }
    }

    // MARK: - Incident Save

    func saveIncident(for child: Child, context: ModelContext) {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let incident = Incident(
            keyworkerName:   kKeyworkerName,
            incidentType:    draftIncidentType,
            title:           trimmed,
            descriptionText: draftDescription.trimmingCharacters(in: .whitespaces),
            location:        draftLocation,
            riddorRequired:  draftIncidentType.isRiddorRelevant,
            witnessNames:    draftWitnesses
        )

        // Encode spatial pin positions as normalised BodyMapMarkers for iPad compatibility
        incident.bodyMapMarkers = injuryMarkers.map { m in
            let noteText = m.note.trimmingCharacters(in: .whitespaces)
            let label = noteText.isEmpty ? m.injuryType.rawValue : "\(m.injuryType.rawValue): \(noteText)"
            return BodyMapMarker(
                x:       Double((m.worldPosition.x + 0.4) / 0.8).clamped(to: 0...1),
                y:       Double(1.0 - (m.worldPosition.y + 0.2) / 1.2).clamped(to: 0...1),
                isFront: true,
                label:   label
            )
        }

        incident.child = child
        child.incidents.append(incident)
        context.insert(incident)
        try? context.save()

        resetDraftForm()
        showIncidentForm      = false
        showSaveConfirmation  = true
    }

    func resetDraftForm() {
        draftTitle       = ""
        draftDescription = ""
        draftLocation    = ""
        draftWitnesses   = ""
        draftIncidentType = .accident
        injuryMarkers.forEach { $0.pinEntity.removeFromParent() }
        injuryMarkers.removeAll()
        selectedMarkerID = nil
    }

    // MARK: - Private Helpers

    private func makeBodyMaterial() -> SimpleMaterial {
        var m = SimpleMaterial()
        m.color = .init(tint: UIColor(red: 0.87, green: 0.84, blue: 0.81, alpha: 1.0))
        m.roughness = .float(0.85)
        m.metallic  = .float(0.0)
        return m
    }

    private func makePart(
        name: String,
        mesh: MeshResource,
        collisionShape: ShapeResource,
        at position: SIMD3<Float>,
        material: SimpleMaterial
    ) -> ModelEntity {
        let e = ModelEntity(mesh: mesh, materials: [material])
        e.name = name
        e.position = position
        e.components.set(InputTargetComponent())
        e.components.set(CollisionComponent(shapes: [collisionShape]))
        e.components.set(HoverEffectComponent())
        return e
    }

    private func makeArmPart(name: String, at pos: SIMD3<Float>, tiltZ: Float) -> ModelEntity {
        let mesh = MeshResource.generateCylinder(height: 0.21, radius: 0.042)
        let e = makePart(name: name,
                         mesh: mesh,
                         collisionShape: .generateBox(size: SIMD3(0.085, 0.21, 0.085)),
                         at: pos,
                         material: makeBodyMaterial())
        e.orientation = simd_quatf(angle: tiltZ, axis: SIMD3(0, 0, 1))
        return e
    }

    private func makeForeArmPart(name: String, at pos: SIMD3<Float>, tiltZ: Float) -> ModelEntity {
        let mesh = MeshResource.generateCylinder(height: 0.19, radius: 0.032)
        let e = makePart(name: name,
                         mesh: mesh,
                         collisionShape: .generateBox(size: SIMD3(0.065, 0.19, 0.065)),
                         at: pos,
                         material: makeBodyMaterial())
        e.orientation = simd_quatf(angle: tiltZ, axis: SIMD3(0, 0, 1))
        return e
    }

    private func makeThighPart(name: String, at pos: SIMD3<Float>) -> ModelEntity {
        let mesh = MeshResource.generateCylinder(height: 0.27, radius: 0.052)
        return makePart(name: name,
                        mesh: mesh,
                        collisionShape: .generateBox(size: SIMD3(0.105, 0.27, 0.105)),
                        at: pos,
                        material: makeBodyMaterial())
    }

    private func makeShinPart(name: String, at pos: SIMD3<Float>) -> ModelEntity {
        let mesh = MeshResource.generateCylinder(height: 0.25, radius: 0.038)
        return makePart(name: name,
                        mesh: mesh,
                        collisionShape: .generateBox(size: SIMD3(0.076, 0.25, 0.076)),
                        at: pos,
                        material: makeBodyMaterial())
    }

    private func makePinEntity(at position: SIMD3<Float>, type: InjuryType) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 0.022)
        let entity = ModelEntity(mesh: mesh, materials: [])
        entity.name = "injuryPin"
        entity.position = position
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.022)]))
        entity.components.set(HoverEffectComponent())
        applyPinMaterial(to: entity, type: type)

        // Outer glow sphere
        let glowMesh = MeshResource.generateSphere(radius: 0.038)
        var glowMat = UnlitMaterial()
        let gc = type.pinColor
        glowMat.color = .init(tint: gc.withAlphaComponent(0.22))
        let glowSphere = ModelEntity(mesh: glowMesh, materials: [glowMat])
        glowSphere.name = "injuryPinGlow"
        entity.addChild(glowSphere)

        return entity
    }

    private func applyPinMaterial(to entity: ModelEntity, type: InjuryType) {
        var mat = PhysicallyBasedMaterial()
        let c = type.pinColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        mat.baseColor       = .init(tint: UIColor(red: r, green: g, blue: b, alpha: 1))
        mat.emissiveColor   = .init(color: UIColor(red: min(r * 1.4, 1), green: min(g * 1.4, 1), blue: min(b * 1.4, 1), alpha: 1))
        mat.emissiveIntensity = 1.4
        mat.roughness       = 0.2
        mat.metallic        = 0.0
        entity.model?.materials = [mat]

        // Recolour the glow child if present
        if let glowChild = entity.findEntity(named: "injuryPinGlow") as? ModelEntity {
            var glowMat = UnlitMaterial()
            glowMat.color = .init(tint: type.pinColor.withAlphaComponent(0.22))
            glowChild.model?.materials = [glowMat]
        }
    }
}

// MARK: - Comparable clamping helper

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
