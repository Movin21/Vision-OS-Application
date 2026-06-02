// Views/ImmersiveBodyMapView.swift — NurseryConnectVision

import SwiftUI
import RealityKit
import RealityKitContent
import SwiftData
import Combine

// MARK: - ImmersiveBodyMapView

struct ImmersiveBodyMapView: View {

    @Environment(SpatialIncidentViewModel.self) private var vm
    @Environment(\.modelContext) private var modelContext

    /// Accumulated yaw from user drags (radians) — each new drag picks up
    /// where the previous one finished so the user can spin the body freely.
    @State private var dragStartYaw: Float = 0
    @State private var userYaw: Float = 0
    /// This view's own bodyRoot + bounds, used by syncPendingPin.
    @State private var localBodyRoot: Entity? = nil
    @State private var localBodyBounds: BoundingBox? = nil

    var body: some View {
        RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            var usdzShown = false

            // Small red pins (1 cm sphere with a 2 cm halo) — bright enough to
            // spot at arm's length but no longer chunky.
            vm.pinRadius     = 0.010
            vm.pinGlowRadius = 0.020

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

            var resolvedBodyRoot: Entity? = nil
            var resolvedBounds: BoundingBox? = nil

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
                resolvedBodyRoot = bodyRoot
                resolvedBounds   = bounds
                localBodyRoot    = bodyRoot
                localBodyBounds  = bounds
                vm.bodyRootEntity = bodyRoot
                usdzShown = true
            } else {
                print("❌ [BodyMap] No USDZ loaded — falling back to procedural body.")
            }

            if !usdzShown {
                vm.buildBody(in: content)
                vm.bodyRootEntity.scale    = SIMD3(repeating: 1.0)
                vm.bodyRootEntity.position = SIMD3(0, 0.505, -1.5)
                let bounds = BoundingBox(min: SIMD3(-0.18, -0.50, -0.06),
                                         max: SIMD3( 0.18,  0.84,  0.06))
                resolvedBodyRoot = vm.bodyRootEntity
                resolvedBounds   = bounds
                localBodyRoot    = vm.bodyRootEntity
                localBodyBounds  = bounds
            }

            vm.isBodyModelReady = true

            // Pre-spawn red pins for every existing marker so they appear
            // immediately when the immersive space opens — using the just-
            // built references, not the @State values (which SwiftUI defers).
            if let bodyRoot = resolvedBodyRoot {
                vm.syncPendingPin(in: content,
                                  bodyRoot: bodyRoot,
                                  bodyBounds: resolvedBounds)
            }

            // ── Floor glow disc ───────────────────────────────────────────────
            let discMesh = MeshResource.generateCylinder(height: 0.003, radius: 0.58)
            var discMat  = UnlitMaterial()
            discMat.color = .init(tint: UIColor(red: 0.16, green: 0.55, blue: 0.88, alpha: 0.18))
            let disc = ModelEntity(mesh: discMesh, materials: [discMat])
            disc.position = SIMD3(0, 0.002, -1.5)
            content.add(disc)

            // Floating rotation control panel — placed to the right of the body
            // at chest height so it's always in easy reach for the user.
            if let rotateUI = attachments.entity(for: "rotate-controls") {
                rotateUI.position = SIMD3(0.85, 0.55, -1.4)
                rotateUI.components.set(BillboardComponent())
                content.add(rotateUI)
            }

            // Today's stats panel — placed to the LEFT of the body, head height.
            if let statsUI = attachments.entity(for: "stats-overlay") {
                statsUI.position = SIMD3(-0.85, 0.85, -1.4)
                statsUI.components.set(BillboardComponent())
                content.add(statsUI)
            }
        } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            guard let bodyRoot = localBodyRoot else { return }

            vm.syncPendingPin(in: content,
                              bodyRoot: bodyRoot,
                              bodyBounds: localBodyBounds)

            // Combined Y-rotation: cardinal view-mode + user's drag yaw.
            let totalAngle = vm.bodyViewMode.angleRadians + userYaw
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
                    ImmersiveInjuryPanel(markerID: marker.id, viewModel: vm)
                }
            }
            // Floating rotation control panel — sits next to the body so the
            // user always has a guaranteed way to spin it even if the drag
            // gesture misses.
            Attachment(id: "rotate-controls") {
                ImmersiveRotateControls(userYaw: $userYaw, dragStartYaw: $dragStartYaw)
            }

            // Today's-stats glass card — meals, fluid, mood, attendance.
            Attachment(id: "stats-overlay") {
                ImmersiveStatsOverlay(viewModel: vm)
            }
        }
        .simultaneousGesture(
            // Immersive is VIEW-ONLY. Tapping a marker pops its info panel,
            // tapping empty body does nothing. New markers must be placed in
            // the windowed inspector.
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard let mid = vm.markerID(forTappedEntity: value.entity) else {
                        return
                    }
                    withAnimation(.spring(response: 0.25)) {
                        vm.selectedMarkerID =
                            vm.selectedMarkerID == mid ? nil : mid
                    }
                }
        )
        // Manual rotation: drag horizontally ANYWHERE in the immersive view
        // to spin the body around its Y axis. Dropping `.targetedToAnyEntity()`
        // lets the drag fire even on empty space, not only on the body mesh.
        .simultaneousGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    let deltaX = Float(value.translation.width) * 0.012
                    userYaw = dragStartYaw + deltaX
                }
                .onEnded { value in
                    let deltaX = Float(value.translation.width) * 0.012
                    dragStartYaw += deltaX
                    userYaw = dragStartYaw
                }
        )
        // .sheet intentionally NOT attached here — sheets aren't supported in
        // immersive contexts on visionOS, so the IncidentFormSheet must be
        // presented from the windowed inspector instead.
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

                // Footer — immersive panels are read-only; the "Log Incident"
                // workflow lives in the windowed inspector (sheets can't open
                // inside an immersive space on visionOS).
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Use the inspector window to log this incident")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

// MARK: - Immersive Rotation Controls

/// Floating glass panel placed beside the body in immersive space. Lets the
/// user spin the body in 45° steps or jump straight to cardinal directions —
/// a guaranteed UI fallback when the drag gesture is hard to hit.
struct ImmersiveRotateControls: View {
    @Binding var userYaw: Float
    @Binding var dragStartYaw: Float

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 4) {
                Image(systemName: "rotate.3d")
                Text("Rotate")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    bumpYaw(by: -.pi / 4)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    bumpYaw(by: .pi / 4)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
            }

            Button {
                userYaw = 0
                dragStartYaw = 0
            } label: {
                Label("Reset", systemImage: "arrow.uturn.left")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
        }
        .padding(14)
        .frame(width: 180)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
    }

    private func bumpYaw(by delta: Float) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            dragStartYaw += delta
            userYaw = dragStartYaw
        }
    }
}

// MARK: - Immersive Stats Overlay
//
// Floating glass card placed to the left of the body in immersive space.
// Shows today's meals, fluid total, latest mood, and attendance status.

struct ImmersiveStatsOverlay: View {
    let viewModel: SpatialIncidentViewModel

    private var child: Child? { viewModel.selectedChild }

    private var todayMeals: [MealRecord] {
        guard let child else { return [] }
        return child.mealRecords
            .filter { Calendar.current.isDateInToday($0.timestamp) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var todayFluidMl: Int {
        todayMeals.reduce(0) { $0 + $1.fluidMl }
    }

    private var latestMood: MoodLevel? {
        todayMeals.first?.mood
    }

    private var todayAttendance: AttendanceRecord? {
        child?.attendanceRecords.first(where: {
            Calendar.current.isDateInToday($0.date)
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if child == nil {
                Text("Select a child in the inspector window.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                attendanceRow
                Divider().opacity(0.4)
                fluidRow
                Divider().opacity(0.4)
                moodRow
                Divider().opacity(0.4)
                mealsRow
            }
        }
        .padding(18)
        .frame(width: 280)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 18))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.title3)
                .foregroundStyle(Color.ncAccent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Today")
                    .font(.headline.bold())
                if let name = child?.firstName {
                    Text(name)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var attendanceRow: some View {
        statRow(
            icon: todayAttendance?.status.sfSymbol ?? "person.slash",
            label: "Attendance",
            value: todayAttendance?.status.rawValue ?? "Not recorded",
            tint: attendanceColor(todayAttendance?.status)
        )
    }

    private var fluidRow: some View {
        statRow(
            icon: "drop.fill",
            label: "Fluid intake",
            value: "\(todayFluidMl) ml",
            tint: Color.ncAccent
        )
    }

    @ViewBuilder
    private var moodRow: some View {
        if let m = latestMood {
            HStack(spacing: 10) {
                Text(m.emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest mood")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(m.rawValue)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
            }
        } else {
            statRow(icon: "face.dashed", label: "Latest mood", value: "—", tint: .secondary)
        }
    }

    private var mealsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Color.ncSecondary)
                Text("Meals (\(todayMeals.count))")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            if todayMeals.isEmpty {
                Text("No meals logged yet today")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(todayMeals.prefix(3), id: \.id) { meal in
                    HStack(spacing: 6) {
                        Text(meal.mood.emoji).font(.caption)
                        Text(meal.mealType.rawValue)
                            .font(.caption.weight(.semibold))
                        Text("• \(meal.foodConsumed.rawValue)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(meal.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func statRow(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold))
            }
            Spacer()
        }
    }

    private func attendanceColor(_ s: AttendanceStatus?) -> Color {
        switch s {
        case .present:    return Color.ncSecondary
        case .signedOut:  return .orange
        case .absent, nil: return Color.ncAlert
        }
    }
}
