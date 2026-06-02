// Views/VisionRootView.swift — NurseryConnectVision
// Three-column NavigationSplitView: child roster | incident inspector | (collapsed)
// Selecting a child immediately focuses the immersive spatial dashboard panel.

import SwiftUI
import SwiftData

struct VisionRootView: View {

    @Query(
        filter: #Predicate<Child> { $0.assignedKeyworkerName == "Sarah Thompson" },
        sort: [SortDescriptor(\Child.lastName, order: .forward)]
    )
    private var children: [Child]

    @Environment(\.modelContext) private var context

    @State private var selectedChildID: UUID? = nil
    @State private var searchText = ""
    @State private var viewModel = SpatialIncidentViewModel()

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
                SpatialWelcomeView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedChildID) { _, newID in
            guard let id = newID,
                  let child = children.first(where: { $0.id == id })
            else { return }
            viewModel.selectedChild = child
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            keyworkerBadge
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            List(filteredChildren, selection: $selectedChildID) { child in
                ChildRosterRow(child: child)
                    .tag(child.id)
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search children…")
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.secondary)
                    Text("\(filteredChildren.count) children")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var keyworkerBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.badge.key.fill")
                .font(.title3)
                .foregroundStyle(Color(hex: "2a6677"))
            VStack(alignment: .leading, spacing: 1) {
                Text("Keyworker")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(kKeyworkerName)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Child Roster Row

private struct ChildRosterRow: View {
    let child: Child

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 42, height: 42)
                Text(child.firstName.prefix(1) + child.lastName.prefix(1))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .topTrailing) {
                if child.hasActiveAlerts {
                    Circle()
                        .fill(Color(hex: "a83836"))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(child.fullName)
                    .font(.subheadline.weight(.medium))
                Text(child.ageDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let count = child.incidents.count
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "a83836"), in: Capsule())
                }
                if child.isBirthdayToday {
                    Image(systemName: "birthday.cake.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "f0a020"))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "2a6677"), Color(hex: "1b5a6b")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Spatial Welcome (empty state)

private struct SpatialWelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.child.and.lock")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "2a6677"), Color(hex: "3b6850")],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            VStack(spacing: 8) {
                Text("Spatial Safety Radar")
                    .font(.title2.weight(.bold))
                Text("Select a child from the roster to open\ntheir 3D Incident Inspector.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
        .padding(40)
    }
}

// Color(hex:) is defined in Utils/VisionDesignSystem.swift
