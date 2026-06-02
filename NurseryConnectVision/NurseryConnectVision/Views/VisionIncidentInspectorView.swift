// Views/VisionIncidentInspectorView.swift — NurseryConnectVision
//
// Immersive "Spatial Safety Radar & 3D Incident Inspector"
// —————————————————————————————————————————————————————————
// Architecture:
//   • NavigationSplitView detail column (windowed visionOS scene)
//   • SpatialAlertBannerView  — floating glass medical/allergy strip (top overlay)
//   • BodyMap3DCanvasView     — RealityView procedural body + SpatialTapGesture pin placement
//   • InjuryAttachmentPanel   — per-pin billboarding SwiftUI panel (RealityView attachment)
//   • FilterOrnamentView      — native .ornament() glass menu anchored below the window
//   • IncidentFormSheet       — slide-up glass form to commit the incident to SwiftData
//   • IncidentTimelineView    — scrollable history of past incidents (timeline filter)
//   • SpatialAlertsDetailView — expanded alert detail (alerts filter)

import SwiftUI
import RealityKit
import SwiftData

// MARK: - Main View

struct VisionIncidentInspectorView: View {

    let child: Child
    @Bindable var viewModel: SpatialIncidentViewModel

    @Environment(\.modelContext) private var context
    @Environment(\.openImmersiveSpace)  private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        ZStack(alignment: .top) {
            // Primary canvas — switches with ornament filter
            Group {
                switch viewModel.activeFilter {
                case .bodyMap:
                    BodyMap3DCanvasView(viewModel: viewModel)
                case .timeline:
                    IncidentTimelineView(child: child)
                case .alerts:
                    SpatialAlertsDetailView(child: child)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // High-visibility safety banner — floats at top when body map is active
            if child.hasActiveAlerts {
                SpatialAlertBannerView(child: child, isExpanded: $viewModel.isAlertBannerExpanded)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: viewModel.isAlertBannerExpanded)
            }

            // Save confirmation toast
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
        .navigationTitle(child.fullName)
        .toolbar { inspectorToolbar }
        // Floating glass filter menu anchored below the window
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            FilterOrnamentView(viewModel: viewModel)
        }
        // Incident form sheet
        .sheet(isPresented: $viewModel.showIncidentForm) {
            IncidentFormSheet(child: child, viewModel: viewModel, context: context)
        }
        .onAppear {
            viewModel.selectedChild = child
        }
        .onChange(of: child.id) { _, _ in
            viewModel.selectedChild = child
            viewModel.resetDraftForm()
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var inspectorToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.showIncidentForm = true
            } label: {
                Label("New Incident", systemImage: "plus.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "a83836"))
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

        ToolbarItem(placement: .topBarLeading) {
            VStack(alignment: .leading, spacing: 1) {
                Text(child.ageDescription)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("\(child.incidents.count) incident\(child.incidents.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if child.hasActiveAlerts {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "a83836"))
                    }
                }
            }
        }
    }
}

// MARK: - Spatial Alert Banner

struct SpatialAlertBannerView: View {
    let child: Child
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed or expanded header
            Button {
                withAnimation(.spring(response: 0.35)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    // Pulsing alert icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "a83836").opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "a83836"))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("SAFETY ALERT — \(child.firstName.uppercased())")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Color(hex: "a83836"))
                        if !isExpanded {
                            Text(summaryLine)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 8) {
                    if !child.allergies.isEmpty {
                        alertSection(
                            icon: "allergens",
                            title: "ALLERGENS",
                            items: child.allergies,
                            accentColor: Color(hex: "a83836")
                        )
                    }
                    if !child.medicalNotes.isEmpty {
                        alertSection(
                            icon: "cross.case.fill",
                            title: "MEDICAL NOTES",
                            items: [child.medicalNotes],
                            accentColor: Color(hex: "f0a020")
                        )
                    }
                    if !child.dietaryRequirements.isEmpty {
                        alertSection(
                            icon: "fork.knife.circle.fill",
                            title: "DIETARY",
                            items: [child.dietaryRequirements],
                            accentColor: Color(hex: "2a6677")
                        )
                    }
                }
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(hex: "a83836").opacity(0.08))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(hex: "a83836").opacity(0.35), lineWidth: 1)
        )
    }

    private var summaryLine: String {
        var parts: [String] = []
        if !child.allergies.isEmpty { parts.append("⚠ \(child.allergies.count) allergen\(child.allergies.count > 1 ? "s" : "")") }
        if !child.medicalNotes.isEmpty { parts.append("Medical notes on file") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func alertSection(icon: String, title: String, items: [String], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(accentColor)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Circle().fill(accentColor).frame(width: 5, height: 5)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

// MARK: - 3D Body Map Canvas

struct BodyMap3DCanvasView: View {
    @Bindable var viewModel: SpatialIncidentViewModel

    var body: some View {
        ZStack {
            RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
                // Build procedural body once
                viewModel.buildBody(in: content)

            } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
                // Sync any new pin requested by tap gesture
                viewModel.syncPendingPin(in: content)

                // Position and register attachment panel entities
                for marker in viewModel.injuryMarkers {
                    if let attachEntity = attachments.entity(for: marker.id) {
                        // Float panel above and slightly in front of the pin
                        attachEntity.position = marker.worldPosition
                            + SIMD3<Float>(0, 0.13, 0.08)
                        if attachEntity.parent == nil {
                            content.add(attachEntity)
                        }
                    }
                }
            } attachments: {
                // One SwiftUI attachment panel per injury marker
                ForEach(viewModel.injuryMarkers) { marker in
                    Attachment(id: marker.id) {
                        InjuryAttachmentPanel(markerID: marker.id, viewModel: viewModel)
                    }
                }
            }
            .gesture(bodyTapGesture)

            // Instruction overlay when no pins placed
            if viewModel.injuryMarkers.isEmpty && viewModel.isBodyModelReady {
                tapInstructionOverlay
            }
        }
    }

    // MARK: Tap Gesture

    private var bodyTapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                let tappedEntity = value.entity

                if tappedEntity.name == "injuryPin" {
                    // Tap on existing pin → select it
                    if let match = viewModel.injuryMarkers.first(
                        where: { $0.pinEntity === (tappedEntity as? ModelEntity) }
                    ) {
                        withAnimation(.spring(response: 0.25)) {
                            viewModel.selectedMarkerID =
                                viewModel.selectedMarkerID == match.id ? nil : match.id
                        }
                    }
                    return
                }

                // Tap on a body part → place a new injury pin
                // World-space centre of the body part + small z-offset toward the viewer
                let entityWorldPos = tappedEntity.position(relativeTo: nil)
                viewModel.pendingTapWorldPosition = entityWorldPos + SIMD3<Float>(0, 0, 0.07)
            }
    }

    // MARK: Tap Instruction Overlay

    private var tapInstructionOverlay: some View {
        VStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(Color(hex: "2a6677"))
            Text("Tap any body part to mark an injury")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
        .offset(y: 140)
    }
}

// MARK: - Injury Attachment Panel (Spatial Popup)

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
                // Injury type grid
                HStack(spacing: 0) {
                    ForEach(InjuryType.allCases) { type in
                        Button {
                            viewModel.updateMarkerType(markerID, to: type)
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: type.sfSymbol)
                                    .font(.caption)
                                Text(type.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                marker.injuryType == type
                                    ? typeColor(type).opacity(0.25)
                                    : Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        marker.injuryType == type ? typeColor(type) : Color.clear,
                                        lineWidth: 1.2
                                    )
                            )
                            .foregroundStyle(
                                marker.injuryType == type ? typeColor(type) : Color.secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // Footer row: type label + delete
                HStack {
                    Label(marker.injuryType.rawValue, systemImage: marker.injuryType.sfSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(typeColor(marker.injuryType))

                    Spacer()

                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.removeMarker(markerID)
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.caption2)
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color(hex: "a83836"))
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

// MARK: - Filter Ornament (Anchored Below Window)

struct FilterOrnamentView: View {
    @Bindable var viewModel: SpatialIncidentViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SafetyViewFilter.allCases) { filter in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.activeFilter = filter
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: filter.sfSymbol)
                            .font(.subheadline)
                        Text(filter.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.activeFilter == filter
                            ? Color(hex: "2a6677").opacity(0.20)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .foregroundStyle(
                        viewModel.activeFilter == filter
                            ? Color(hex: "2a6677")
                            : Color.primary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 14))
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
                    // Marker summary card
                    if !viewModel.injuryMarkers.isEmpty {
                        markerSummaryCard
                    }

                    // Form fields
                    spatialFormSection("Incident Details") {
                        VStack(spacing: 12) {
                            Picker("Type", selection: $viewModel.draftIncidentType) {
                                ForEach(IncidentType.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.menu)

                            SpatialTextField(
                                label: "Title",
                                placeholder: "Brief description of what happened",
                                text: $viewModel.draftTitle
                            )

                            SpatialTextField(
                                label: "Description",
                                placeholder: "Chronological account of the incident…",
                                text: $viewModel.draftDescription,
                                axis: .vertical,
                                lineLimit: 4...8
                            )

                            SpatialTextField(
                                label: "Location",
                                placeholder: "Where in the setting?",
                                text: $viewModel.draftLocation
                            )

                            SpatialTextField(
                                label: "Witnesses",
                                placeholder: "Witness names (comma separated)",
                                text: $viewModel.draftWitnesses
                            )
                        }
                    }

                    // RIDDOR notice
                    if viewModel.draftIncidentType.isRiddorRelevant {
                        riddorNoticeCard
                    }

                    // Compliance note
                    complianceNote
                }
                .padding(20)
            }
            .navigationTitle("Log Incident — \(child.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        viewModel.saveIncident(for: child, context: context)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? Color(hex: "a83836") : .secondary)
                }
            }
        }
        .glassBackgroundEffect()
        .frame(minWidth: 520, minHeight: 600)
    }

    private var markerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("3D Body Map — \(viewModel.injuryMarkers.count) marker\(viewModel.injuryMarkers.count == 1 ? "" : "s") placed",
                  systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "3b6850"))

            FlowLayout(spacing: 6) {
                ForEach(viewModel.injuryMarkers) { marker in
                    HStack(spacing: 4) {
                        Image(systemName: marker.injuryType.sfSymbol)
                            .font(.caption2)
                        Text(marker.injuryType.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                }
            }
        }
        .padding(14)
        .background(Color(hex: "3b6850").opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: "3b6850").opacity(0.30), lineWidth: 1)
        )
    }

    private var riddorNoticeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "f0a020"))
                .font(.title3)
            Text("This incident type may require **RIDDOR reporting** to the HSE (Health & Safety Executive).")
                .font(.caption)
        }
        .padding(12)
        .background(Color(hex: "f0a020").opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var complianceNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(.secondary)
                .font(.title3)
            Text("Submitted as **Pending Review** — requires Manager countersignature before finalisation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func spatialFormSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
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
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text, axis: axis == .vertical ? .vertical : .horizontal)
                .lineLimit(lineLimit)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Flow Layout (for marker tags)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        var rowX: CGFloat = 0
        var rowY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowX + size.width > width && rowX > 0 {
                rowY += rowHeight + spacing
                rowX = 0
                rowHeight = 0
            }
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: rowY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var rowX = bounds.minX
        var rowY = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowX + size.width > bounds.maxX && rowX > bounds.minX {
                rowY += rowHeight + spacing
                rowX = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: rowX, y: rowY), proposal: ProposedViewSize(size))
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Save Confirmation Banner

private struct SaveConfirmationBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: "3b6850"))
            Text("Incident submitted — Pending Review")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassBackgroundEffect(in: Capsule())
    }
}

// MARK: - Incident Timeline View (timeline filter)

struct IncidentTimelineView: View {
    let child: Child

    private var sortedIncidents: [Incident] {
        child.incidents.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if sortedIncidents.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(sortedIncidents.enumerated()), id: \.element.id) { idx, incident in
                        TimelineRow(incident: incident, isLast: idx == sortedIncidents.count - 1)
                    }
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(Color(hex: "2a6677"))
            Text("No incidents recorded")
                .font(.title3.weight(.semibold))
            Text("Incidents logged via the 3D Body Map appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct TimelineRow: View {
    let incident: Incident
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline spine
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(statusColor.opacity(0.18)).frame(width: 36, height: 36)
                    Image(systemName: incident.reviewStatus.sfSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(incident.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(incident.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    typePill(incident.incidentType)
                    statusPill(incident.reviewStatus)
                    if incident.riddorRequired {
                        Text("RIDDOR")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color(hex: "f0a020").opacity(0.2), in: Capsule())
                            .foregroundStyle(Color(hex: "f0a020"))
                    }
                }

                if !incident.location.isEmpty {
                    Label(incident.location, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let markerCount = incident.bodyMapMarkers.count
                if markerCount > 0 {
                    Label("\(markerCount) body map marker\(markerCount == 1 ? "" : "s")",
                          systemImage: "figure.stand")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "2a6677"))
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
    }

    private var statusColor: Color {
        switch incident.reviewStatus {
        case .pendingReview:  return Color(hex: "f0a020")
        case .underReview:    return Color(hex: "2a6677")
        case .countersigned:  return Color(hex: "3b6850")
        case .requiresAction: return Color(hex: "a83836")
        }
    }

    private func typePill(_ type: IncidentType) -> some View {
        Text(type.rawValue)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
    }

    private func statusPill(_ status: ReviewStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(statusColor.opacity(0.12), in: Capsule())
            .foregroundStyle(statusColor)
    }
}

// MARK: - Spatial Alerts Detail View (alerts filter)

struct SpatialAlertsDetailView: View {
    let child: Child

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !child.allergies.isEmpty {
                    allergenCard
                }
                if !child.medicalNotes.isEmpty {
                    medicalCard
                }
                if !child.dietaryRequirements.isEmpty {
                    dietaryCard
                }
                if !child.hasActiveAlerts {
                    clearCard
                }

                emergencyContactCard
            }
            .padding(24)
        }
    }

    private var allergenCard: some View {
        alertCard(
            title: "Known Allergens",
            icon: "allergens",
            accentHex: "a83836"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(child.allergies, id: \.self) { allergen in
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: "a83836"))
                            .font(.subheadline)
                        Text(allergen)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "a83836").opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var medicalCard: some View {
        alertCard(title: "Medical Notes", icon: "cross.case.fill", accentHex: "f0a020") {
            Text(child.medicalNotes)
                .font(.subheadline)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var dietaryCard: some View {
        alertCard(title: "Dietary Requirements", icon: "fork.knife.circle.fill", accentHex: "2a6677") {
            Text(child.dietaryRequirements)
                .font(.subheadline)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var clearCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title)
                .foregroundStyle(Color(hex: "3b6850"))
            VStack(alignment: .leading, spacing: 2) {
                Text("No Active Safety Alerts")
                    .font(.subheadline.weight(.semibold))
                Text("No allergens, medical notes, or dietary restrictions on file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "3b6850").opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var emergencyContactCard: some View {
        alertCard(title: "Emergency Contact", icon: "phone.fill.arrow.up.right", accentHex: "2a6677") {
            VStack(alignment: .leading, spacing: 6) {
                if !child.emergencyContactName.isEmpty {
                    Label(child.emergencyContactName, systemImage: "person.fill")
                        .font(.subheadline.weight(.medium))
                }
                if !child.emergencyContactPhone.isEmpty {
                    Label(child.emergencyContactPhone, systemImage: "phone.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "2a6677"))
                }
                if child.emergencyContactName.isEmpty && child.emergencyContactPhone.isEmpty {
                    Text("No emergency contact on file.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func alertCard<Content: View>(
        title: String, icon: String, accentHex: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(hex: accentHex))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(hex: accentHex).opacity(0.25), lineWidth: 1)
        )
    }
}
