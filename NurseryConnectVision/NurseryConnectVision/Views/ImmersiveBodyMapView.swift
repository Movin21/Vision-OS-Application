// Views/ImmersiveBodyMapView.swift — NurseryConnectVision
// Full-immersion body map scene. Opened from the toolbar "Full Immersion" toggle.
// The same procedural body model from BodyMap3DCanvasView is re-built here in
// world space at a comfortable reaching distance from the user.

import SwiftUI
import RealityKit

struct ImmersiveBodyMapView: View {
    @State private var vm = SpatialIncidentViewModel()

    var body: some View {
        RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            vm.buildBody(in: content)
            vm.bodyRootEntity.position = SIMD3<Float>(0, 0.15, -0.95)
            vm.bodyRootEntity.scale    = SIMD3<Float>(repeating: 1.15)
        } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            vm.syncPendingPin(in: content)
            for marker in vm.injuryMarkers {
                if let entity = attachments.entity(for: marker.id) {
                    entity.position = marker.worldPosition + SIMD3<Float>(0, 0.15, 0.10)
                    if entity.parent == nil { content.add(entity) }
                }
            }
        } attachments: {
            ForEach(vm.injuryMarkers) { marker in
                Attachment(id: marker.id) {
                    InjuryAttachmentPanel(markerID: marker.id, viewModel: vm)
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if value.entity.name == "injuryPin" {
                        if let match = vm.injuryMarkers.first(
                            where: { $0.pinEntity === (value.entity as? ModelEntity) }
                        ) {
                            withAnimation(.spring(response: 0.25)) {
                                vm.selectedMarkerID =
                                    vm.selectedMarkerID == match.id ? nil : match.id
                            }
                        }
                        return
                    }
                    let pos = value.entity.position(relativeTo: nil)
                    vm.pendingTapWorldPosition = pos + SIMD3<Float>(0, 0, 0.07)
                }
        )
    }
}
