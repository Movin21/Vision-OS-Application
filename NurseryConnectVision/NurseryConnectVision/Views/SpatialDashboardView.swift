// Views/SpatialDashboardView.swift — NurseryConnectVision
// Aggregate keyworker dashboard shown when no child is selected.
// Uses a 2-column GlassCard layout so content never overflows the
// detail column width (~720-800 pt on the default 1120×780 window).

import SwiftUI

struct SpatialDashboardView: View {
    let children: [Child]
    @State private var appeared = false

    // MARK: - Computed KPIs

    private var alertChildren: [Child]     { children.filter { $0.hasActiveAlerts } }
    private var allIncidents: [Incident]   { children.flatMap { $0.incidents } }
    private var pendingIncidents: [Incident] {
        allIncidents.filter { $0.reviewStatus == .pendingReview }
    }
    private var requiresAction: [Incident] {
        allIncidents.filter { $0.reviewStatus == .requiresAction }
    }
    private var recentIncidents: [Incident] {
        allIncidents.sorted { $0.timestamp > $1.timestamp }.prefix(6).map { $0 }
    }
    private var birthdayChildren: [Child]  { children.filter { $0.isBirthdayToday } }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {

                // ── Greeting header ───────────────────────────
                dashboardHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -16)
                    .animation(.easeOut(duration: 0.45), value: appeared)

                // ── 4 KPI cards, each flex-equal width ────────
                metricsRow
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                // ── 2-column grid ──────────────────────────────
                HStack(alignment: .top, spacing: 20) {
                    // Left column
                    VStack(spacing: 20) {
                        alertChildrenPanel
                        if !birthdayChildren.isEmpty { birthdayPanel }
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -20)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                    // Right column
                    VStack(spacing: 20) {
                        recentIncidentsPanel
                        compliancePanel
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
                }
            }
            .padding(28)
        }
        .navigationTitle("Safety Dashboard")
        .onAppear { withAnimation { appeared = true } }
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Good \(greetingTime), \(kKeyworkerName.components(separatedBy: " ").first ?? "Keyworker")")
                    .font(.largeTitle.bold())
            }
            Spacer()
            HStack(spacing: 8) {
                StatusIndicator(color: .green, isPulsing: true, size: 8)
                Text("System Active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var greetingTime: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Morning" }
        if h < 17 { return "Afternoon" }
        return "Evening"
    }

    // MARK: - KPI Row (4 cards, each maxWidth: .infinity)

    private var metricsRow: some View {
        HStack(spacing: 14) {
            metricCard(
                title: "Children",
                value: "\(children.count)",
                subtitle: "Assigned to keyworker",
                icon: "figure.2.and.child.holdinghands",
                color: Color.ncAccent
            )
            metricCard(
                title: "Safety Alerts",
                value: "\(alertChildren.count)",
                subtitle: "\(children.count - alertChildren.count) clear",
                icon: "exclamationmark.triangle.fill",
                color: alertChildren.isEmpty ? Color.ncSecondary : Color.ncAlert,
                isAlert: !alertChildren.isEmpty
            )
            metricCard(
                title: "Incidents",
                value: "\(allIncidents.count)",
                subtitle: "\(pendingIncidents.count) pending review",
                icon: "list.clipboard.fill",
                color: .orange
            )
            metricCard(
                title: "Requires Action",
                value: "\(requiresAction.count)",
                subtitle: requiresAction.isEmpty ? "All clear" : "Manager review needed",
                icon: "exclamationmark.shield.fill",
                color: requiresAction.isEmpty ? Color.ncSecondary : Color.ncAlert,
                isAlert: !requiresAction.isEmpty
            )
        }
    }

    private func metricCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        color: Color,
        isAlert: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .symbolEffect(.pulse, options: .repeating, isActive: isAlert)

            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
        .hoverEffect(.highlight)
    }

    // MARK: - Alert Children Panel

    private var alertChildrenPanel: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SpatialSectionHeader(
                        title: "Safety Alerts",
                        iconName: "exclamationmark.triangle.fill",
                        accentColor: Color.ncAlert
                    )
                    AlertBadge(count: alertChildren.count, color: Color.ncAlert)
                }

                if alertChildren.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(Color.ncSecondary).font(.title3)
                        Text("All children clear")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(alertChildren) { child in
                        HStack(spacing: 10) {
                            ChildAvatar(child: child, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(child.fullName).font(.subheadline.bold())
                                if !child.allergies.isEmpty {
                                    Text(child.allergies.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(Color.ncAlert)
                                        .lineLimit(1)
                                }
                                if !child.medicalNotes.isEmpty {
                                    Text(child.medicalNotes)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(Color.ncAlert)
                        }
                        if child.id != alertChildren.last?.id { Divider() }
                    }
                }
            }
        }
    }

    // MARK: - Birthday Panel

    private var birthdayPanel: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                SpatialSectionHeader(
                    title: "Birthdays Today",
                    iconName: "birthday.cake.fill",
                    accentColor: Color.ncWarning
                )
                ForEach(birthdayChildren) { child in
                    HStack(spacing: 10) {
                        ChildAvatar(child: child, size: 32)
                        Text(child.fullName).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("🎂").font(.title3)
                    }
                }
            }
        }
    }

    // MARK: - Recent Incidents Panel

    private var recentIncidentsPanel: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SpatialSectionHeader(
                        title: "Recent Incidents",
                        iconName: "clock.arrow.circlepath",
                        accentColor: .orange
                    )
                    AlertBadge(count: pendingIncidents.count, color: .orange)
                }

                if recentIncidents.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.ncSecondary)
                        Text("No incidents recorded yet")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(recentIncidents) { incident in
                        incidentQueueRow(incident)
                        if incident.id != recentIncidents.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func incidentQueueRow(_ incident: Incident) -> some View {
        let color: Color = {
            switch incident.reviewStatus {
            case .pendingReview:  return .orange
            case .underReview:    return Color.ncAccent
            case .countersigned:  return Color.ncSecondary
            case .requiresAction: return Color.ncAlert
            }
        }()
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: incident.reviewStatus.sfSymbol)
                    .font(.caption.weight(.semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(incident.child?.fullName ?? "—")
                    .font(.subheadline.bold())
                Text(incident.title)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(incident.incidentType.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                Text(incident.timestamp.shortDate)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Compliance Panel

    private var compliancePanel: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                SpatialSectionHeader(
                    title: "Compliance",
                    iconName: "checkmark.seal.fill",
                    accentColor: Color.ncSecondary
                )

                let countersigned = allIncidents.filter { $0.reviewStatus == .countersigned }.count
                let total         = allIncidents.count

                complianceRow(label: "Countersigned", count: countersigned,
                              total: total, color: Color.ncSecondary)
                complianceRow(label: "Pending Review", count: pendingIncidents.count,
                              total: total, color: .orange)
                complianceRow(label: "Requires Action", count: requiresAction.count,
                              total: total, color: Color.ncAlert)

                let riddor = allIncidents.filter { $0.riddorRequired }.count
                if riddor > 0 {
                    Divider()
                    Label("\(riddor) possible RIDDOR report\(riddor == 1 ? "" : "s")",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ncWarning)
                }

                // Incident type breakdown
                Divider()
                Text("BY TYPE")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)

                let typeCounts = IncidentType.allCases.compactMap { type -> (IncidentType, Int)? in
                    let c = allIncidents.filter { $0.incidentType == type }.count
                    return c > 0 ? (type, c) : nil
                }
                if typeCounts.isEmpty {
                    Text("No incidents yet").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(typeCounts, id: \.0) { type, count in
                        HStack {
                            Circle().fill(incidentTypeColor(type)).frame(width: 7, height: 7)
                            Text(type.rawValue).font(.caption)
                            Spacer()
                            Text("\(count)").font(.caption.bold())
                                .foregroundStyle(incidentTypeColor(type))
                        }
                    }
                }
            }
        }
    }

    private func complianceRow(label: String, count: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label).font(.subheadline)
                Spacer()
                Text("\(count)").font(.subheadline.bold()).foregroundStyle(color)
            }
            GeometryReader { geo in
                let w = total == 0 ? 0.0 : geo.size.width * CGFloat(count) / CGFloat(total)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 4)
                    Capsule().fill(color).frame(width: w, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func incidentTypeColor(_ type: IncidentType) -> Color {
        switch type {
        case .accident:     return Color.ncAlert
        case .nearMiss:     return Color.ncWarning
        case .illness:      return Color.ncAccent
        case .behavioural:  return .purple
        case .safeguarding: return Color(red: 0.55, green: 0, blue: 0)
        }
    }
}
