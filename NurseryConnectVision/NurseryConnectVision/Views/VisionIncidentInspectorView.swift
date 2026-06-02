// Views/VisionIncidentInspectorView.swift — NurseryConnectVision
//
// Two-column Spatial Safety Inspector
// ──────────────────────────────────────────────────────────────
//  Left  — 3D body map (RealityView + SpatialTapGesture), fills
//           all available space so the model has room to breathe.
//  Right — Fixed 300 pt info sidebar: child overview card,
//           collapsible safety alerts (allergens / medical /
//           dietary), incident log, and "Log New Incident" CTA.
//  Bottom ornament — live stats + full-immersion toggle.
//
// Height bug fix: top-level HStack uses maxHeight: .infinity so
// both columns stretch to fill the window, not shrink to content.

import SwiftUI
import RealityKit
import RealityKitContent
import SwiftData

// MARK: - Main View

struct VisionIncidentInspectorView: View {

    let child: Child
    @Bindable var viewModel: SpatialIncidentViewModel

    @Environment(\.modelContext) private var context
    @Environment(\.openImmersiveSpace)    private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var selectedIncident: Incident? = nil
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {

            // ── Left: 3D body map ──────────────────────────────
            bodyMapColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.97)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

            Divider()

            // ── Right: info sidebar ───────────────────────────
            infoSidebar
                .frame(width: 300, alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(child.fullName)
        .toolbar { inspectorToolbar }
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            bottomOrnament
        }
        .sheet(isPresented: $viewModel.showIncidentForm) {
            IncidentFormSheet(child: child, viewModel: viewModel, context: context)
        }
        .overlay(alignment: .top) {
            if viewModel.showSaveConfirmation {
                SaveConfirmationBanner()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        withAnimation { viewModel.showSaveConfirmation = false }
                    }
            }
        }
        .onAppear {
            viewModel.selectedChild = child
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .onChange(of: child.id) { _, _ in
            selectedIncident = nil
            appeared = false
            viewModel.selectedChild = child
            viewModel.resetDraftForm()
            withAnimation(.easeOut(duration: 0.6).delay(0.05)) { appeared = true }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var inspectorToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 10) {
                ChildAvatar(child: child, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(child.ageDescription)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if child.hasActiveAlerts {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.ncAlert)
                            Text("\(child.allergies.count) allergen\(child.allergies.count == 1 ? "" : "s")")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.ncAlert)
                        }
                    }
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.showIncidentForm = true
            } label: {
                Label("Log Incident", systemImage: "plus.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ncAlert)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task {
                    if viewModel.isImmersiveSpaceOpen {
                        await dismissImmersiveSpace()
                        viewModel.isImmersiveSpaceOpen = false
                    } else {
                        await openImmersiveSpace(id: "BodyMapImmersive")
                        viewModel.isImmersiveSpaceOpen = true
                    }
                }
            } label: {
                Label(
                    viewModel.isImmersiveSpaceOpen ? "Exit Immersive" : "Full Immersion",
                    systemImage: viewModel.isImmersiveSpaceOpen ? "arrow.down.right.and.arrow.up.left" : "visionpro"
                )
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Body Map Column (left, flexible)

    private var bodyMapColumn: some View {
        ZStack(alignment: .bottom) {
            // 3D canvas fills the entire column
            BodyMap3DCanvasView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Active markers strip anchored to bottom
            if !viewModel.injuryMarkers.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color.ncAccent)
                        .font(.caption)
                    Text("\(viewModel.injuryMarkers.count) marker\(viewModel.injuryMarkers.count == 1 ? "" : "s") placed — tap to classify")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button("Clear All") {
                        withAnimation { viewModel.resetDraftForm() }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Info Sidebar (right, 300 pt fixed)

    private var infoSidebar: some View {
        VStack(spacing: 0) {

            // ── Child overview card ────────────────────────────
            childOverviewCard

            Divider()

            // ── Scrollable content ─────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Safety alerts section
                    if child.hasActiveAlerts {
                        safetySectionGroup
                    } else {
                        clearStatusRow
                    }

                    Divider()

                    // Incident log section
                    incidentLogGroup
                }
                .padding(14)
            }

            Divider()

            // ── New incident CTA ───────────────────────────────
            Button {
                viewModel.showIncidentForm = true
            } label: {
                Label("Log New Incident", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ncAlert)
            .padding(12)
        }
    }

    // ── Child overview card ────────────────────────────────────

    private var childOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ChildAvatar(child: child, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.fullName)
                        .font(.headline.bold())
                    Text(child.ageDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(child.ageBand.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if child.isBirthdayToday {
                    Text("🎂")
                        .font(.title3)
                }
            }

            // Quick stat pills
            HStack(spacing: 6) {
                let total   = child.incidents.count
                let pending = child.incidents.filter { $0.reviewStatus == .pendingReview }.count
                let action  = child.incidents.filter { $0.reviewStatus == .requiresAction }.count

                if child.hasActiveAlerts {
                    quickPill("Alert", icon: "exclamationmark.triangle.fill", color: Color.ncAlert)
                }
                if action > 0 {
                    quickPill("\(action) Action", icon: "exclamationmark.shield.fill", color: Color.ncAlert)
                }
                if pending > 0 {
                    quickPill("\(pending) Pending", icon: "clock.fill", color: .orange)
                }
                quickPill("\(total) Total", icon: "list.clipboard", color: Color.ncAccent)
            }
        }
        .padding(16)
    }

    private func quickPill(_ label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(label).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }

    // ── Safety section ─────────────────────────────────────────

    private var safetySectionGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("SAFETY ALERTS", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Color.ncAlert)

            if !child.allergies.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ALLERGENS")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.ncAlert.opacity(0.7))
                    ForEach(child.allergies, id: \.self) { allergen in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.ncAlert)
                            Text(allergen)
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.ncAlert.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if !child.medicalNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MEDICAL NOTES")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.ncWarning.opacity(0.8))
                    Text(child.medicalNotes)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if !child.dietaryRequirements.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DIETARY")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.ncAccent.opacity(0.8))
                    Text(child.dietaryRequirements)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if !child.emergencyContactName.isEmpty || !child.emergencyContactPhone.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EMERGENCY CONTACT")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.ncAccent.opacity(0.8))
                    if !child.emergencyContactName.isEmpty {
                        Label(child.emergencyContactName, systemImage: "person.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    if !child.emergencyContactPhone.isEmpty {
                        Label(child.emergencyContactPhone, systemImage: "phone.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.ncAccent)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var clearStatusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title3)
                .foregroundStyle(Color.ncSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No Active Alerts")
                    .font(.subheadline.weight(.semibold))
                Text("No allergens or medical notes on file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ncSecondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    // ── Incident log ───────────────────────────────────────────

    private var incidentLogGroup: some View {
        let sorted = child.incidents.sorted { $0.timestamp > $1.timestamp }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("INCIDENT LOG", systemImage: "list.clipboard.fill")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Color.ncAccent)
                Spacer()
                let pending = child.incidents.filter { $0.reviewStatus == .pendingReview }.count
                AlertBadge(count: pending, color: .orange)
            }

            if sorted.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(Color.ncSecondary)
                    Text("No incidents yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, incident in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedIncident = selectedIncident?.id == incident.id ? nil : incident
                            }
                        } label: {
                            incidentRow(incident, isLast: idx == sorted.count - 1, isSelected: selectedIncident?.id == incident.id)
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                    }
                }

                // Selected incident detail card
                if let inc = selectedIncident {
                    selectedIncidentCard(inc)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func incidentRow(_ incident: Incident, isLast: Bool, isSelected: Bool) -> some View {
        let color = statusColor(for: incident.reviewStatus)
        return HStack(alignment: .top, spacing: 10) {
            // Spine
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: incident.reviewStatus.sfSymbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color)
                }
                if !isLast {
                    Rectangle().fill(Color.secondary.opacity(0.2))
                        .frame(width: 1.5).frame(minHeight: 18)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(incident.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(incident.incidentType.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                    if incident.riddorRequired {
                        Text("RIDDOR")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Color.ncWarning)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.ncWarning.opacity(0.18), in: Capsule())
                    }
                }
                Text(incident.timestamp.shortDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, isLast ? 0 : 14)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isSelected ? Color.ncAccent.opacity(0.07) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
    }

    private func selectedIncidentCard(_ incident: Incident) -> some View {
        let color = statusColor(for: incident.reviewStatus)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusBadge(text: incident.reviewStatus.rawValue, color: color)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedIncident = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if !incident.descriptionText.isEmpty {
                Text(incident.descriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !incident.location.isEmpty {
                Label(incident.location, systemImage: "mappin.circle")
                    .font(.caption).foregroundStyle(Color.ncAccent)
            }
            if !incident.witnessNames.isEmpty {
                Label(incident.witnessNames, systemImage: "person.2")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(incident.timestamp.fullDateTime)
                .font(.caption2).foregroundStyle(.secondary)

            if incident.riddorRequired {
                Label("RIDDOR reporting may be required", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ncWarning)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ncWarning.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.25), lineWidth: 1))
    }

    private func statusColor(for status: ReviewStatus) -> Color {
        switch status {
        case .pendingReview:  return .orange
        case .underReview:    return Color.ncAccent
        case .countersigned:  return Color.ncSecondary
        case .requiresAction: return Color.ncAlert
        }
    }

    // MARK: - Bottom Ornament

    private var bottomOrnament: some View {
        HStack(spacing: 14) {
            let markers = viewModel.injuryMarkers.count
            let total   = child.incidents.count

            if markers > 0 {
                Label("\(markers) pin\(markers == 1 ? "" : "s") placed", systemImage: "mappin.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.ncAccent)
                Divider().frame(height: 18)
            }

            Label("\(total) incident\(total == 1 ? "" : "s")", systemImage: "list.clipboard")
                .font(.caption)
                .foregroundStyle(.secondary)

            if child.hasActiveAlerts {
                Divider().frame(height: 18)
                Label("\(child.allergies.count) allergen\(child.allergies.count == 1 ? "" : "s")",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.ncAlert)
            }

            Divider().frame(height: 18)
            Label("Tap body to mark injury", systemImage: "hand.tap.fill")
                .font(.caption).foregroundStyle(.secondary)
            Divider().frame(height: 18)

            Button {
                Task {
                    if viewModel.isImmersiveSpaceOpen {
                        await dismissImmersiveSpace()
                        viewModel.isImmersiveSpaceOpen = false
                    } else {
                        await openImmersiveSpace(id: "BodyMapImmersive")
                        viewModel.isImmersiveSpaceOpen = true
                    }
                }
            } label: {
                Label(
                    viewModel.isImmersiveSpaceOpen ? "Exit Immersive" : "Full Immersion",
                    systemImage: viewModel.isImmersiveSpaceOpen ? "xmark.circle.fill" : "visionpro.fill"
                )
                .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isImmersiveSpaceOpen ? Color.ncAlert : Color.ncAccent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassBackgroundEffect(in: Capsule())
    }
}

// MARK: - 3D Body Map Canvas

struct BodyMap3DCanvasView: View {
    @Bindable var viewModel: SpatialIncidentViewModel

    /// This view's own bodyRoot and bounds — kept locally so each open
    /// RealityView re-spawns its own pin entities from the shared marker list.
    @State private var localBodyRoot: Entity? = nil
    @State private var localBodyBounds: BoundingBox? = nil

    var body: some View {
        ZStack(alignment: .top) {
            RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
                var usdzShown = false

                // Smaller pins for the tiny windowed view
                viewModel.pinRadius     = 0.008
                viewModel.pinGlowRadius = 0.014

                // ── Try to load Child.usdz from RealityKitContent ─────────────
                let candidateNames = ["Child", "Child.usdz"]
                var loadedEntity: Entity? = nil
                for name in candidateNames {
                    do {
                        loadedEntity = try await Entity(named: name, in: realityKitContentBundle)
                        print("✅ [Inspector] Loaded USDZ as '\(name)'")
                        break
                    } catch {
                        print("⚠️ [Inspector] Could not load '\(name)': \(error.localizedDescription)")
                    }
                }

                if let modelEntity = loadedEntity {
                    let bodyRoot = Entity()
                    bodyRoot.name = "BodyRoot"
                    bodyRoot.addChild(modelEntity)

                    // Scale to ~0.40 m tall to fit the small windowed view.
                    autoScaleEntity(modelEntity, targetMetres: 0.40)
                    applyInspectorBodyMaterial(to: bodyRoot)
                    addInspectorInteraction(to: bodyRoot)

                    let bounds = modelEntity.visualBounds(relativeTo: bodyRoot)
                    let feetOffset = -bounds.min.y
                    bodyRoot.position = SIMD3(0, -0.20 + feetOffset, -0.05)

                    content.add(bodyRoot)
                    localBodyRoot   = bodyRoot
                    localBodyBounds = bounds
                    viewModel.bodyRootEntity = bodyRoot
                    viewModel.isBodyModelReady = true
                    usdzShown = true

                    print("📏 [Inspector] Bounds extents = \(bounds.extents)")
                }

                // ── Procedural fallback ───────────────────────────────────────
                if !usdzShown {
                    print("❌ [Inspector] No USDZ — using procedural body")
                    viewModel.buildBody(in: content)
                    viewModel.bodyRootEntity.scale    = SIMD3(repeating: 0.28)
                    viewModel.bodyRootEntity.position = SIMD3(0, -0.04, -0.05)
                    localBodyRoot   = viewModel.bodyRootEntity
                    localBodyBounds = BoundingBox(min: SIMD3(-0.18, -0.50, -0.06),
                                                  max: SIMD3( 0.18,  0.84,  0.06))
                }
            } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
                guard let bodyRoot = localBodyRoot else { return }

                // Spawn / reconcile pin entities from the shared marker list
                viewModel.syncPendingPin(in: content,
                                        bodyRoot: bodyRoot,
                                        bodyBounds: localBodyBounds)

                // Apply Front/Back/Left/Right rotation
                bodyRoot.transform.rotation =
                    simd_quatf(angle: viewModel.bodyViewMode.angleRadians,
                               axis: SIMD3(0, 1, 0))

                // Float attachment panels ABOVE the body (anchored at the body
                // top, not next to the pin) so they're easy to read and never
                // overlap the figure.
                let bodyWorldTop = bodyRoot.position(relativeTo: nil)
                    + SIMD3<Float>(0, (localBodyBounds?.max.y ?? 0.20) + 0.08, 0.08)
                for marker in viewModel.injuryMarkers {
                    if let entity = attachments.entity(for: marker.id),
                       bodyRoot.findEntity(named: "pin-\(marker.id.uuidString)") != nil {
                        entity.position = bodyWorldTop
                        if entity.parent == nil { content.add(entity) }
                    }
                }
            } attachments: {
                ForEach(viewModel.injuryMarkers) { marker in
                    Attachment(id: marker.id) {
                        InjuryAttachmentPanel(markerID: marker.id, viewModel: viewModel)
                    }
                }
            }
            .gesture(
                // Windowed inspector is view-only: tapping an existing pin
                // selects/inspects it, but tapping empty body does NOT add a
                // new marker. New markers can only be placed in the immersive
                // view.
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        guard let mid = viewModel.markerID(forTappedEntity: value.entity) else {
                            return
                        }
                        withAnimation(.spring(response: 0.25)) {
                            viewModel.selectedMarkerID =
                                viewModel.selectedMarkerID == mid ? nil : mid
                        }
                    }
            )

            // ── Front / Back / Left / Right view-mode picker ──────────────────
            BodyViewModePicker(viewModel: viewModel)
                .padding(.top, 8)

            // Hint — windowed view is view-only; users add markers in immersive.
            if viewModel.injuryMarkers.isEmpty && viewModel.isBodyModelReady {
                VStack(spacing: 6) {
                    Image(systemName: "visionpro")
                        .font(.title2)
                        .foregroundStyle(Color.ncAccent)
                    Text("Open Immersive view to mark injuries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Tap a marker here to inspect it")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .padding(14)
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
                .offset(y: 130)
            }
        }
    }
}

// MARK: - Injury Attachment Panel

struct InjuryAttachmentPanel: View {
    let markerID: UUID
    @Bindable var viewModel: SpatialIncidentViewModel

    private var marker: SpatialInjuryMarker? {
        viewModel.injuryMarkers.first { $0.id == markerID }
    }
    private var isSelected: Bool { viewModel.selectedMarkerID == markerID }

    var body: some View {
        if let marker {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(InjuryType.allCases) { type in
                        Button {
                            viewModel.updateMarkerType(markerID, to: type)
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: type.sfSymbol).font(.caption)
                                Text(type.rawValue).font(.system(size: 9, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(marker.injuryType == type ? typeColor(type).opacity(0.25) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(marker.injuryType == type ? typeColor(type) : Color.clear,
                                                  lineWidth: 1.2)
                            )
                            .foregroundStyle(marker.injuryType == type ? typeColor(type) : Color.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                HStack {
                    Label(marker.injuryType.rawValue, systemImage: marker.injuryType.sfSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(typeColor(marker.injuryType))
                    Spacer()
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3)) { viewModel.removeMarker(markerID) }
                    } label: {
                        Label("Remove", systemImage: "trash").font(.caption2).labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.ncAlert)
                }
            }
            .padding(12)
            .frame(width: 280)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .scaleEffect(isSelected ? 1.0 : 0.88)
            .opacity(isSelected ? 1.0 : 0.72)
            .animation(.spring(response: 0.3), value: isSelected)
            .onTapGesture {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.selectedMarkerID = isSelected ? nil : markerID
                }
            }
        }
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

// MARK: - Incident Form Sheet

struct IncidentFormSheet: View {
    let child: Child
    @Bindable var viewModel: SpatialIncidentViewModel
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        !viewModel.draftTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.draftDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !viewModel.injuryMarkers.isEmpty { markerSummaryCard }
                    spatialFormSection("Incident Details") {
                        VStack(spacing: 12) {
                            Picker("Type", selection: $viewModel.draftIncidentType) {
                                ForEach(IncidentType.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.menu)
                            SpatialTextField(label: "Title", placeholder: "Brief description", text: $viewModel.draftTitle)
                            SpatialTextField(label: "Description", placeholder: "Chronological account…",
                                             text: $viewModel.draftDescription, axis: .vertical, lineLimit: 4...8)
                            SpatialTextField(label: "Location", placeholder: "Where in the setting?",
                                             text: $viewModel.draftLocation)
                            SpatialTextField(label: "Witnesses", placeholder: "Names (comma separated)",
                                             text: $viewModel.draftWitnesses)
                        }
                    }
                    if viewModel.draftIncidentType.isRiddorRelevant { riddorNoticeCard }
                    complianceNote
                }
                .padding(20)
            }
            .navigationTitle("Log Incident — \(child.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        viewModel.saveIncident(for: child, context: context)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? Color.ncAlert : .secondary)
                }
            }
        }
        .glassBackgroundEffect()
        .frame(minWidth: 520, minHeight: 580)
    }

    private var markerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("3D Body Map — \(viewModel.injuryMarkers.count) marker\(viewModel.injuryMarkers.count == 1 ? "" : "s") placed",
                  systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ncSecondary)
            FlowLayout(spacing: 6) {
                ForEach(viewModel.injuryMarkers) { marker in
                    HStack(spacing: 4) {
                        Image(systemName: marker.injuryType.sfSymbol).font(.caption2)
                        Text(marker.injuryType.rawValue).font(.caption)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                }
            }
        }
        .padding(14)
        .background(Color.ncSecondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ncSecondary.opacity(0.28), lineWidth: 1))
    }

    private var riddorNoticeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ncWarning).font(.title3)
            Text("This incident type may require **RIDDOR reporting** to the HSE.")
                .font(.caption)
        }
        .padding(12)
        .background(Color.ncWarning.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var complianceNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.secondary).font(.title3)
            Text("Submitted as **Pending Review** — requires Manager countersignature.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func spatialFormSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            content()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Spatial Text Field

private struct SpatialTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            TextField(placeholder, text: $text, axis: axis == .vertical ? .vertical : .horizontal)
                .lineLimit(lineLimit)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        var rowX: CGFloat = 0; var rowY: CGFloat = 0; var rowH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if rowX + s.width > width && rowX > 0 { rowY += rowH + spacing; rowX = 0; rowH = 0 }
            rowX += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: rowY + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}

// MARK: - Save Confirmation Banner

private struct SaveConfirmationBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ncSecondary)
            Text("Incident submitted — Pending Review").font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .glassBackgroundEffect(in: Capsule())
    }
}

// MARK: - Front / Back / Left / Right View-mode Picker

struct BodyViewModePicker: View {
    @Bindable var viewModel: SpatialIncidentViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(BodyMapViewMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        viewModel.bodyViewMode = mode
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: mode.sfSymbol)
                            .font(.callout)
                        Text(mode.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(width: 56, height: 44)
                    .background(
                        viewModel.bodyViewMode == mode
                            ? Color.ncAccent.opacity(0.30)
                            : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                viewModel.bodyViewMode == mode
                                    ? Color.ncAccent
                                    : Color.white.opacity(0.18),
                                lineWidth: 1.2
                            )
                    )
                    .foregroundStyle(
                        viewModel.bodyViewMode == mode ? Color.ncAccent : Color.secondary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - USDZ Body Helpers

/// Scales an entity so its visual bounding-box height matches `targetMetres`.
/// Works regardless of the source model's native units (cm, mm, in, m).
@MainActor
func autoScaleEntity(_ entity: Entity, targetMetres: Float) {
    entity.scale = SIMD3<Float>(repeating: 1.0)
    let bounds = entity.visualBounds(relativeTo: entity)
    let rawHeight = bounds.extents.y
    guard rawHeight > 0.0001 else { return }
    let s = targetMetres / rawHeight
    entity.scale = SIMD3<Float>(repeating: s)
}

/// Applies a uniform skin-tone PBR material to every ModelComponent in the
/// hierarchy so the USDZ looks consistent regardless of its embedded textures.
@MainActor
func applyInspectorBodyMaterial(to entity: Entity) {
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
        applyInspectorBodyMaterial(to: child)
    }
}

/// Makes every ModelComponent in the hierarchy tappable so the user can place
/// injury pins anywhere on the body surface.
@MainActor
func addInspectorInteraction(to entity: Entity) {
    if entity.components[ModelComponent.self] != nil {
        entity.generateCollisionShapes(recursive: false)
        entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        entity.components.set(HoverEffectComponent())
    }
    for child in entity.children {
        addInspectorInteraction(to: child)
    }
}
