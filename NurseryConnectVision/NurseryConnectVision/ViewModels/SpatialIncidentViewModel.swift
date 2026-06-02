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

/// Position is stored in normalized body coordinates so a marker tapped in the
/// windowed inspector (small body) appears at the equivalent anatomical spot in
/// the immersive view (life-size body).
/// - x: 0 = left, 1 = right (across body width)
/// - y: 0 = feet, 1 = top of head
/// - z: 0 = back surface, 1 = front surface
struct SpatialInjuryMarker: Identifiable {
    let id: UUID
    var normalizedPosition: SIMD3<Float>
    var injuryType: InjuryType
    var note: String

    init(id: UUID = UUID(),
         normalizedPosition: SIMD3<Float>,
         injuryType: InjuryType = .bruise,
         note: String = "") {
        self.id = id
        self.normalizedPosition = normalizedPosition
        self.injuryType = injuryType
        self.note = note
    }

    var bodyRegionName: String {
        let y = normalizedPosition.y
        if y > 0.88 { return "Head" }
        if y > 0.78 { return "Neck / Shoulders" }
        if y > 0.55 { return "Torso" }
        if y > 0.45 { return "Hips / Pelvis" }
        if y > 0.20 { return "Upper Legs" }
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

// MARK: - Body Map View Mode (Front/Back/Left/Right)

enum BodyMapViewMode: String, CaseIterable, Identifiable {
    case front = "Front"
    case back  = "Back"
    case left  = "Left"
    case right = "Right"

    var id: String { rawValue }

    /// Y-axis rotation in radians.
    var angleRadians: Float {
        switch self {
        case .front: return 0
        case .right: return .pi * 0.5
        case .back:  return .pi
        case .left:  return -.pi * 0.5
        }
    }

    var sfSymbol: String {
        switch self {
        case .front: return "person.fill"
        case .back:  return "person.fill.turn.down"
        case .left:  return "person.fill.turn.left"
        case .right: return "person.fill.turn.right"
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

    // MARK: Pin appearance (configurable per view)
    /// Radius of the colored pin sphere in metres.
    var pinRadius: Float = 0.014
    /// Radius of the translucent halo behind each pin in metres.
    var pinGlowRadius: Float = 0.022

    // MARK: Body view mode (front / back / left / right)
    var bodyViewMode: BodyMapViewMode = .front
    /// Extra Y-rotation in radians applied on top of the view-mode angle
    /// (used by the immersive drag gesture for free 360° rotation).
    var bodyExtraYaw: Float = 0

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

    /// Processes a pending tap (converting world → normalized body coords) and
    /// then makes sure every marker in `injuryMarkers` has a corresponding pin
    /// entity living inside the caller's `bodyRoot`. This is what lets a marker
    /// placed in the windowed inspector appear automatically in the immersive
    /// view and vice versa — each view re-spawns pins from the shared list.
    func syncPendingPin(in content: RealityViewContent,
                        bodyRoot: Entity,
                        bodyBounds: BoundingBox?) {
        // Resolve a pending tap into a normalized marker
        if let world = pendingTapWorldPosition, let bounds = bodyBounds {
            pendingTapWorldPosition = nil
            let local = bodyRoot.convert(position: world, from: nil)
            let normalized = normalize(local, in: bounds)
            let marker = SpatialInjuryMarker(normalizedPosition: normalized, injuryType: .bruise)
            injuryMarkers.append(marker)
            selectedMarkerID = marker.id
            print("📌 [Pin] norm=\(normalized) count=\(injuryMarkers.count)")
        }

        // Reconcile entity tree against the markers list
        syncPinEntities(in: bodyRoot, bounds: bodyBounds)
    }

    /// Ensures the children of `bodyRoot` exactly mirror `injuryMarkers`:
    /// missing pins are spawned, deleted markers' pins are removed, and
    /// type changes update materials in place.
    private func syncPinEntities(in bodyRoot: Entity, bounds: BoundingBox?) {
        guard let bounds = bounds else { return }

        var existing: [UUID: ModelEntity] = [:]
        for child in bodyRoot.children where child.name.hasPrefix("pin-") {
            let idStr = String(child.name.dropFirst(4))
            if let id = UUID(uuidString: idStr), let me = child as? ModelEntity {
                existing[id] = me
            }
        }

        for marker in injuryMarkers {
            let local = unnormalize(marker.normalizedPosition, in: bounds)
            if let pin = existing[marker.id] {
                pin.position = local
                applyPinMaterial(to: pin, type: marker.injuryType)
            } else {
                let pin = makePinEntity(at: local, type: marker.injuryType)
                pin.name = "pin-\(marker.id.uuidString)"
                bodyRoot.addChild(pin)
            }
        }

        let validIDs = Set(injuryMarkers.map { $0.id })
        for (id, pin) in existing where !validIDs.contains(id) {
            pin.removeFromParent()
        }
    }

    /// Convert a body-local point into [0,1] normalized coords, clamping XY to
    /// the body silhouette and snapping Z to whichever surface is closer.
    private func normalize(_ local: SIMD3<Float>, in bounds: BoundingBox) -> SIMD3<Float> {
        let minB = bounds.min
        let ext  = bounds.extents
        var n = SIMD3<Float>(
            ext.x > 0.0001 ? (local.x - minB.x) / ext.x : 0.5,
            ext.y > 0.0001 ? (local.y - minB.y) / ext.y : 0.5,
            ext.z > 0.0001 ? (local.z - minB.z) / ext.z : 0.5
        )
        n.x = max(0, min(1, n.x))
        n.y = max(0, min(1, n.y))
        n.z = n.z > 0.5 ? 1.0 : 0.0            // snap to front or back surface
        return n
    }

    /// Inverse of `normalize`: expands [0,1] back into body-local coords with a
    /// small outward offset so the pin sits on the surface, not buried inside.
    private func unnormalize(_ n: SIMD3<Float>, in bounds: BoundingBox) -> SIMD3<Float> {
        let minB = bounds.min
        let ext  = bounds.extents
        let offset = pinRadius * 0.5
        let zSurface = n.z > 0.5 ? bounds.max.z + offset : bounds.min.z - offset
        return SIMD3<Float>(
            minB.x + n.x * ext.x,
            minB.y + n.y * ext.y,
            zSurface
        )
    }

    /// Look up the marker ID for a tapped entity (handles pin sphere or its
    /// glow child).
    func markerID(forTappedEntity entity: Entity) -> UUID? {
        if entity.name.hasPrefix("pin-") {
            return UUID(uuidString: String(entity.name.dropFirst(4)))
        }
        if let parent = entity.parent, parent.name.hasPrefix("pin-") {
            return UUID(uuidString: String(parent.name.dropFirst(4)))
        }
        return nil
    }

    /// Updates the free-text note attached to a marker.
    func updateMarkerNote(_ markerID: UUID, note: String) {
        guard let idx = injuryMarkers.firstIndex(where: { $0.id == markerID }) else { return }
        injuryMarkers[idx].note = note
    }

    /// Changes the injury type — the next `syncPinEntities` call refreshes
    /// the pin's material across every active view.
    func updateMarkerType(_ markerID: UUID, to type: InjuryType) {
        guard let idx = injuryMarkers.firstIndex(where: { $0.id == markerID }) else { return }
        injuryMarkers[idx].injuryType = type
    }

    /// Removes a marker; the next `syncPinEntities` call purges its pin in
    /// every active view.
    func removeMarker(_ markerID: UUID) {
        injuryMarkers.removeAll { $0.id == markerID }
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
            let label = noteText.isEmpty
                ? m.injuryType.rawValue
                : "\(m.injuryType.rawValue): \(noteText)"
            return BodyMapMarker(
                x:       Double(m.normalizedPosition.x),
                y:       Double(1.0 - m.normalizedPosition.y),  // 2D map y-flipped
                isFront: m.normalizedPosition.z > 0.5,
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
        // Clearing the markers list triggers each active view's
        // syncPinEntities to remove the orphaned pin entities.
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
        let r = pinRadius
        let mesh = MeshResource.generateSphere(radius: r)
        let entity = ModelEntity(mesh: mesh, materials: [])
        entity.name = "injuryPin"
        entity.position = position
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: r * 1.4)]))
        entity.components.set(HoverEffectComponent())
        applyPinMaterial(to: entity, type: type)

        // Outer glow sphere
        let glowMesh = MeshResource.generateSphere(radius: pinGlowRadius)
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
