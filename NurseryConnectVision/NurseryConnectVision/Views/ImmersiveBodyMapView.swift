// Views/ImmersiveBodyMapView.swift — NurseryConnectVision

import SwiftUI
import RealityKit
import RealityKitContent
import SwiftData

// MARK: - ImmersiveBodyMapView

struct ImmersiveBodyMapView: View {

    @Environment(SpatialIncidentViewModel.self) private var vm
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var bvm = vm

        RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            do {
                let scene = try await Entity(named: "Scene", in: realityKitContentBundle)

                let bodyRoot = scene.findEntity(named: "HumanBody") ?? scene
                bodyRoot.name = "BodyRoot"

                applyBodyMaterial(to: bodyRoot)
                addInteraction(to: bodyRoot)

                // HumanBody.obj is exported from 3ds Max — Y spans 0 to 20.68 units.
                // Scale = 1.35 / 20.74 = 0.065 gives a child-height body (1.35 m).
                // Foot Y-min is -0.057 units → 0.004 m lift keeps feet at floor level.
                scene.scale    = SIMD3(repeating: 0.065)
                scene.position = SIMD3(0, 0.004, -1.5)

                // Entrance: grow from near-zero to final transform
                let finalTransform = scene.transform
                scene.scale = SIMD3(repeating: 0.001)
                content.add(scene)
                scene.move(to: finalTransform, relativeTo: scene.parent,
                           duration: 0.9, timingFunction: .easeOut)

                // Floor glow disc
                let discMesh = MeshResource.generateCylinder(height: 0.003, radius: 0.58)
                var discMat  = UnlitMaterial()
                discMat.color = .init(tint: UIColor(red: 0.16, green: 0.55, blue: 0.88, alpha: 0.18))
                let disc = ModelEntity(mesh: discMesh, materials: [discMat])
                disc.position = SIMD3(0, 0.002, -1.5)
                content.add(disc)

                vm.bodyRootEntity  = scene
                vm.isBodyModelReady = true

            } catch {
                vm.buildBody(in: content)
            }
        } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            vm.syncPendingPin(in: content)
            for marker in vm.injuryMarkers {
                if let entity = attachments.entity(for: marker.id) {
                    entity.position = marker.worldPosition + SIMD3<Float>(0.20, 0.14, 0.14)
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
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let name = value.entity.name
                    if name == "injuryPin" || name == "injuryPinGlow" {
                        let pinEntity: Entity
                        if name == "injuryPinGlow" {
                            pinEntity = value.entity.parent ?? value.entity
                        } else {
                            pinEntity = value.entity
                        }
                        if let match = vm.injuryMarkers.first(
                            where: { $0.pinEntity === (pinEntity as? ModelEntity) }
                        ) {
                            withAnimation(.spring(response: 0.25)) {
                                vm.selectedMarkerID =
                                    vm.selectedMarkerID == match.id ? nil : match.id
                            }
                        }
                        return
                    }

                    let localPt = value.location3D
                    let local = SIMD3<Float>(Float(localPt.x), Float(localPt.y), Float(localPt.z))
                    let world = value.entity.convert(position: local, to: nil)
                    vm.pendingTapWorldPosition = world + SIMD3<Float>(0, 0, 0.03)
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
        if let model = entity as? ModelEntity {
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: UIColor(red: 0.89, green: 0.77, blue: 0.66, alpha: 1))
            mat.roughness = 0.70
            mat.metallic  = 0.0
            mat.emissiveColor     = .init(color: UIColor(red: 0.22, green: 0.13, blue: 0.06, alpha: 1))
            mat.emissiveIntensity = 0.10
            model.model?.materials = [mat]
        }
        for child in entity.children {
            applyBodyMaterial(to: child)
        }
    }

    private func addInteraction(to entity: Entity) {
        if let model = entity as? ModelEntity {
            model.generateCollisionShapes(recursive: false)
            model.components.set(InputTargetComponent(allowedInputTypes: .indirect))
            model.components.set(HoverEffectComponent())
        }
        for child in entity.children {
            addInteraction(to: child)
        }
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
