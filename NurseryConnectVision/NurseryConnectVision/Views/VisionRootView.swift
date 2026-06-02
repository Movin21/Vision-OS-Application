// Views/VisionRootView.swift — NurseryConnectVision
// Three-column NavigationSplitView: child roster | spatial inspector / dashboard
// Defaults to the aggregate Safety Dashboard when no child is selected.

import SwiftUI
import SwiftData

struct VisionRootView: View {

    @Query(
        filter: #Predicate<Child> { $0.assignedKeyworkerName == "Sarah Thompson" },
        sort: [SortDescriptor(\Child.lastName, order: .forward)]
    )
    private var children: [Child]

    @Environment(\.modelContext) private var context
    @Environment(SpatialIncidentViewModel.self) private var viewModel

    @State private var selectedChildID: UUID? = nil
    @State private var searchText = ""

    private var selectedChild: Child? {
        guard let id = selectedChildID else { return nil }
        return children.first { $0.id == id }
    }

    private var filteredChildren: [Child] {
        guard !searchText.isEmpty else { return children }
        let q = searchText.lowercased()
        return children.filter {
            $0.firstName.lowercased().contains(q) || $0.lastName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("NurseryConnect")
        } detail: {
            if let child = selectedChild {
                VisionIncidentInspectorView(child: child, viewModel: viewModel)
                    .id(child.id)
            } else {
                SpatialDashboardView(children: children)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedChildID) { _, newID in
            guard let id = newID,
                  let child = children.first(where: { $0.id == id })
            else { return }
            viewModel.selectedChild = child
        }
        .task {
            if children.isEmpty { seedDemoChildren() }
        }
    }

    // MARK: - Demo Seed

    private func seedDemoChildren() {
        let cal = Calendar.current
        func dob(yearsAgo: Int, monthsAgo: Int = 0) -> Date {
            cal.date(byAdding: DateComponents(year: -yearsAgo, month: -monthsAgo), to: Date()) ?? Date()
        }

        let lily = Child(
            firstName: "Lily", lastName: "Parker",
            dateOfBirth: dob(yearsAgo: 3, monthsAgo: 2),
            assignedKeyworkerName: kKeyworkerName,
            allergies: ["Peanuts", "Tree nuts"],
            medicalNotes: "Carries EpiPen — spare held in office safe.",
            dietaryRequirements: "Strict nut-free diet.",
            emergencyContactName: "Claire Parker",
            emergencyContactPhone: "07700 900123"
        )
        let oliver = Child(
            firstName: "Oliver", lastName: "Patel",
            dateOfBirth: dob(yearsAgo: 4, monthsAgo: 1),
            assignedKeyworkerName: kKeyworkerName,
            allergies: ["Dairy"],
            medicalNotes: "",
            dietaryRequirements: "Dairy-free alternatives required.",
            emergencyContactName: "Priya Patel",
            emergencyContactPhone: "07700 900456"
        )
        let amara = Child(
            firstName: "Amara", lastName: "Johnson",
            dateOfBirth: dob(yearsAgo: 2, monthsAgo: 9),
            assignedKeyworkerName: kKeyworkerName,
            allergies: [],
            medicalNotes: "Mild asthma — blue Ventolin inhaler kept in child's bag.",
            dietaryRequirements: "",
            emergencyContactName: "David Johnson",
            emergencyContactPhone: "07700 900789"
        )
        let noah = Child(
            firstName: "Noah", lastName: "Williams",
            dateOfBirth: dob(yearsAgo: 3, monthsAgo: 6),
            assignedKeyworkerName: kKeyworkerName,
            emergencyContactName: "Sarah Williams",
            emergencyContactPhone: "07700 900321"
        )
        let freya = Child(
            firstName: "Freya", lastName: "Chen",
            dateOfBirth: dob(yearsAgo: 4, monthsAgo: 4),
            assignedKeyworkerName: kKeyworkerName,
            allergies: ["Eggs", "Sesame"],
            medicalNotes: "Eczema — apply Aveeno cream after water play.",
            emergencyContactName: "Wei Chen",
            emergencyContactPhone: "07700 900654"
        )

        for child in [lily, oliver, amara, noah, freya] { context.insert(child) }
        try? context.save()
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Keyworker identity badge
            keyworkerBadge
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Dashboard overview button
            Button {
                withAnimation(.spring(response: 0.35)) { selectedChildID = nil }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedChildID == nil ? Color.ncAccent : Color.ncAccent.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selectedChildID == nil ? .white : Color.ncAccent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Overview Dashboard")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedChildID == nil ? .primary : .primary)
                        Text("Today's safety summary")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedChildID == nil {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.ncAccent)
                    }
                }
                .padding(10)
                .background(
                    selectedChildID == nil ? Color.ncAccent.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            // Children section label
            HStack {
                Text("CHILDREN")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
                Spacer()
                if !filteredChildren.isEmpty {
                    let alertCount = filteredChildren.filter { $0.hasActiveAlerts }.count
                    if alertCount > 0 {
                        AlertBadge(count: alertCount, color: Color.ncAlert)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            List(filteredChildren, selection: $selectedChildID) { child in
                ChildRosterRow(child: child)
                    .tag(child.id)
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search children…")
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack(spacing: 8) {
                    let alertCount = children.filter { $0.hasActiveAlerts }.count
                    if alertCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.ncAlert)
                            Text("\(alertCount) alert\(alertCount == 1 ? "" : "s")")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.ncAlert)
                        }
                        Divider().frame(height: 12)
                    }
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                    Text("\(filteredChildren.count) children")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Keyworker Badge

    private var keyworkerBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.badge.key.fill")
                .font(.title3)
                .foregroundStyle(Color.ncAccent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Keyworker")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(kKeyworkerName)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            StatusIndicator(color: .green, isPulsing: true, size: 7)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Child Roster Row

private struct ChildRosterRow: View {
    let child: Child
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            ChildAvatar(child: child, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(child.fullName)
                    .font(.subheadline.weight(.medium))
                Text(child.ageDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                let count = child.incidents.count
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.ncAlert, in: Capsule())
                }
                if child.isBirthdayToday {
                    Image(systemName: "birthday.cake.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.ncWarning)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.4), value: appeared)
        .onAppear { appeared = true }
    }
}

// Color(hex:) is defined in Utils/VisionDesignSystem.swift
