// Views/ImmersiveBodyMapView.swift — NurseryConnectVision

import SwiftUI
import RealityKit
import RealityKitContent
import SwiftData

// MARK: - ImmersiveBodyMapView

struct ImmersiveBodyMapView: View {

    @Environment(SpatialIncidentViewModel.self) private var vm
    @Environment(\.modelContext) private var modelContext

    /// Accumulated drag yaw so each new drag picks up where the last left off.
    @State private var dragStartYaw: Float = 0
    /// This view's own bodyRoot + bounds, used by syncPendingPin.
    @State private var localBodyRoot: Entity? = nil
    @State private var localBodyBounds: BoundingBox? = nil

    var body: some View {
        @Bindable var bvm = vm

        RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            var usdzShown = false

            // Larger pins for the life-size immersive body
            vm.pinRadius     = 0.018
            vm.pinGlowRadius = 0.030

            let candidateNames = ["Child", "Child.usdz"]
            var loadedEntity: Entity? = nil
            for name in candidateNames {
                do {
                    loadedEntity = try await Entity(named: name, in: realityKitContentBundle)
                    print("✅ [BodyMap] Loaded USDZ as '\(name)'")
                    break
                } catch {
                    print("⚠️ [BodyMap] Could not load '\(name)': \(error.localizedDescription)")
                }
            }

            if let modelEntity = loadedEntity {

                let bodyRoot = Entity()
                bodyRoot.name = "BodyRoot"
                bodyRoot.addChild(modelEntity)

                autoScaleToHeight(modelEntity, targetMetres: 0.95)
                applyBodyMaterial(to: bodyRoot)
                addInteraction(to: bodyRoot)

                let bounds = modelEntity.visualBounds(relativeTo: bodyRoot)
                let feetOffset = -bounds.min.y
                bodyRoot.position = SIMD3(0, feetOffset, -1.5)

                print("📏 [BodyMap] Bounds extents = \(bounds.extents), feetOffset = \(feetOffset)")

                content.add(bodyRoot)
                localBodyRoot   = bodyRoot
                localBodyBounds = bounds
                vm.bodyRootEntity = bodyRoot
                usdzShown = true
            } else {
                print("❌ [BodyMap] No USDZ loaded — falling back to procedural body.")
            }

            if !usdzShown {
                vm.buildBody(in: content)
                vm.bodyRootEntity.scale    = SIMD3(repeating: 1.0)
                vm.bodyRootEntity.position = SIMD3(0, 0.505, -1.5)
                localBodyRoot   = vm.bodyRootEntity
                localBodyBounds = BoundingBox(min: SIMD3(-0.18, -0.50, -0.06),
                                              max: SIMD3( 0.18,  0.84,  0.06))
            }

            vm.isBodyModelReady = true

            // ── Floor glow disc ───────────────────────────────────────────────
            let discMesh = MeshResource.generateCylinder(height: 0.003, radius: 0.58)
            var discMat  = UnlitMaterial()
            discMat.color = .init(tint: UIColor(red: 0.16, green: 0.55, blue: 0.88, alpha: 0.18))
            let disc = ModelEntity(mesh: discMesh, materials: [discMat])
            disc.position = SIMD3(0, 0.002, -1.5)
            content.add(disc)
        } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            guard let bodyRoot = localBodyRoot else { return }

            vm.syncPendingPin(in: content,
                              bodyRoot: bodyRoot,
                              bodyBounds: localBodyBounds)

            // Apply combined Y-rotation: view-mode (cardinal) + extra yaw (drag).
            let totalAngle = vm.bodyViewMode.angleRadians + vm.bodyExtraYaw
            bodyRoot.transform.rotation =
                simd_quatf(angle: totalAngle, axis: SIMD3(0, 1, 0))

            // Attachment panels follow each pin's current world position so
            // they stay glued to their pins as the body rotates.
            for marker in vm.injuryMarkers {
                if let entity = attachments.entity(for: marker.id),
                   let pin = bodyRoot.findEntity(named: "pin-\(marker.id.uuidString)") {
                    let pinWorld = pin.position(relativeTo: nil)
                    entity.position = pinWorld + SIMD3<Float>(0.20, 0.14, 0.14)
                    if entity.parent == nil { content.add(entity) }
                }
            }
        } attachments: {
            ForEach(vm.injuryMarkers) { marker in
                Attachment(id: marker.id) {
                    ImmersiveInjuryPanel(markerID: marker.id, viewModel: vm) {
                        bvm.showIncidentForm = true
                    }
                }
            }
        }
        .simultaneousGesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if let mid = vm.markerID(forTappedEntity: value.entity) {
                        withAnimation(.spring(response: 0.25)) {
                            vm.selectedMarkerID =
                                vm.selectedMarkerID == mid ? nil : mid
                        }
                        return
                    }

                    let scenePt = value.convert(value.location3D, from: .local, to: .scene)
                    let world = SIMD3<Float>(Float(scenePt.x), Float(scenePt.y), Float(scenePt.z))
                    print("📍 [Immersive] Tap → world \(world)")
                    vm.pendingTapWorldPosition = world
                }
        )
        .simultaneousGesture(
            // Drag horizontally anywhere to spin the body 360° around Y.
            DragGesture(minimumDistance: 30)
                .targetedToAnyEntity()
                .onChanged { value in
                    let deltaX = Float(value.translation.width) * 0.005
                    vm.bodyExtraYaw = dragStartYaw + deltaX
                }
                .onEnded { value in
                    let deltaX = Float(value.translation.width) * 0.005
                    dragStartYaw += deltaX
                    vm.bodyExtraYaw = dragStartYaw
                }
        )
        .sheet(isPresented: $bvm.showIncidentForm) {
            if let child = vm.selectedChild {
                IncidentFormSheet(child: child, viewModel: vm, context: modelContext)
            }
        }
        .onDisappear {
            vm.isBodyModelReady = false
        }
    }

    // MARK: - Private Helpers

    private func applyBodyMaterial(to entity: Entity) {
        if var modelComp = entity.components[ModelComponent.self] {
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: UIColor(red: 0.89, green: 0.77, blue: 0.66, alpha: 1))
            mat.roughness = 0.70
            mat.metallic  = 0.0
            mat.emissiveColor     = .init(color: UIColor(red: 0.22, green: 0.13, blue: 0.06, alpha: 1))
            mat.emissiveIntensity = 0.10
            modelComp.materials = [mat]
            entity.components[ModelComponent.self] = modelComp
        }
        for child in entity.children {
            applyBodyMaterial(to: child)
        }
    }

    private func addInteraction(to entity: Entity) {
        if entity.components[ModelComponent.self] != nil {
            Task { @MainActor in
                entity.generateCollisionShapes(recursive: false)
                entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
                entity.components.set(HoverEffectComponent())
            }
        }
        for child in entity.children {
            addInteraction(to: child)
        }
    }

    /// Scales an entity so its visual bounding-box height matches `targetMetres`.
    /// Works regardless of the source model's native units (cm, mm, in, m).
    private func autoScaleToHeight(_ entity: Entity, targetMetres: Float) {
        entity.scale = SIMD3<Float>(repeating: 1.0)
        let bounds = entity.visualBounds(relativeTo: entity)
        let rawHeight = bounds.extents.y
        guard rawHeight > 0.0001 else { return }
        let s = targetMetres / rawHeight
        entity.scale = SIMD3<Float>(repeating: s)
    }
}

// MARK: - ImmersiveInjuryPanel

struct ImmersiveInjuryPanel: View {

    let markerID: UUID
    let viewModel: SpatialIncidentViewModel
    let onLogReport: () -> Void

    @State private var localNote: String = ""

    private var marker: SpatialInjuryMarker? {
        viewModel.injuryMarkers.first { $0.id == markerID }
    }

    private var isSelected: Bool { viewModel.selectedMarkerID == markerID }

    var body: some View {
        guard let marker else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 0) {

                // Header row
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(typeColor(marker.injuryType).opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: marker.injuryType.sfSymbol)
                            .font(.title2)
                            .foregroundStyle(typeColor(marker.injuryType))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(marker.injuryType.rawValue)
                            .font(.headline.bold())
                            .foregroundStyle(typeColor(marker.injuryType))
                        Text(marker.bodyRegionName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.removeMarker(markerID)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.ncAlert)
                }
                .padding(16)

                Divider()

                // Type picker
                HStack(spacing: 0) {
                    ForEach(InjuryType.allCases) { type in
                        Button {
                            viewModel.updateMarkerType(markerID, to: type)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: type.sfSymbol)
                                    .font(.caption)
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                marker.injuryType == type
                                    ? typeColor(type).opacity(0.22)
                                    : Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        marker.injuryType == type ? typeColor(type) : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                            .foregroundStyle(
                                marker.injuryType == type
                                    ? typeColor(type)
                                    : Color.secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // Note section
                VStack(alignment: .leading, spacing: 8) {
                    Label("OBSERVATION NOTE", systemImage: "note.text")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)

                    TextField(
                        "Tap to add clinical observation…",
                        text: $localNote,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(14)

                Divider()

                // Footer
                HStack(spacing: 12) {
                    Button(action: onLogReport) {
                        Label("Log Incident", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ncAlert)
                }
                .padding(14)
            }
            .frame(width: 340)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 6)
            .scaleEffect(isSelected ? 1.0 : 0.82)
            .opacity(isSelected ? 1.0 : 0.65)
            .animation(.spring(response: 0.32), value: isSelected)
            .onTapGesture {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.selectedMarkerID = isSelected ? nil : markerID
                }
            }
            .onAppear {
                localNote = marker.note
            }
            .onChange(of: localNote) { _, new in
                viewModel.updateMarkerNote(markerID, note: new)
            }
        )
    }

    private func typeColor(_ type: InjuryType) -> Color {
        switch type {
        case .bruise:   return Color(red: 0.45, green: 0.15, blue: 0.65)
        case .cut:      return Color(red: 0.88, green: 0.12, blue: 0.12)
        case .swelling: return Color(red: 0.98, green: 0.52, blue: 0.04)
        case .burn:     return Color(red: 0.96, green: 0.30, blue: 0.08)
        case .redness:  return Color(red: 0.92, green: 0.22, blue: 0.28)
        }
    }
}
