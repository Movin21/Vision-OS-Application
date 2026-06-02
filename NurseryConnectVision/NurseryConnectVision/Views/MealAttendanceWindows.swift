// Views/MealAttendanceWindows.swift — NurseryConnectVision
//
// Two standalone SwiftUI windows opened via `openWindow(id:)`:
//   - "meal-log"   → MealLogWindow:   form for logging meals (with mood)
//   - "attendance" → AttendanceWindow: sign-in / sign-out + status
//
// Both float as independent windows so they're never occluded by the 3D body.

import SwiftUI
import SwiftData

// MARK: - Meal Log Window

struct MealLogWindow: View {
    @Environment(SpatialIncidentViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var mealType: MealType = .lunch
    @State private var foodOffered: String = ""
    @State private var consumed: ConsumptionLevel = .all
    @State private var fluidMl: Int = 100
    @State private var fluidType: String = "Water"
    @State private var allergenChecked: Bool = false
    @State private var allergenNotes: String = ""
    @State private var notes: String = ""
    @State private var mood: MoodLevel = .neutral
    @State private var saved = false

    private var trimmedFood: String {
        foodOffered.trimmingCharacters(in: .whitespaces)
    }
    private var isValid: Bool { !trimmedFood.isEmpty }

    var body: some View {
        if let child = viewModel.selectedChild {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 22) {
                        header(for: child)
                        mealSection
                        fluidSection
                        moodSection
                        allergenSection
                        notesSection

                        // Inline disabled-reason hint so users see WHY Save is
                        // greyed out instead of getting stuck on a toolbar
                        // button.
                        if !isValid {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Color.ncWarning)
                                Text("Enter what food was offered to enable Save.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.ncWarning.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(20)
                }
                .navigationTitle("Log Meal — \(child.firstName)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismissWindow(id: "meal-log") }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save(for: child) }
                            .disabled(!isValid)
                            .fontWeight(.semibold)
                    }
                }
            }
            .glassBackgroundEffect()
            .frame(minWidth: 520, minHeight: 580)
            .onChange(of: saved) { _, done in
                if done { dismissWindow(id: "meal-log") }
            }
        } else {
            unselectedChildPlaceholder
        }
    }

    private func header(for child: Child) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.ncSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(child.fullName)
                    .font(.title3.weight(.semibold))
                Text("Age \(child.ageInYears) • Keyworker \(kKeyworkerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.ncSecondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private var mealSection: some View {
        FormCard(title: "Meal") {
            Picker("Type", selection: $mealType) {
                ForEach(MealType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Food offered").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField("e.g. Vegetable pasta, banana", text: $foodOffered)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("How much eaten").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Consumed", selection: $consumed) {
                    ForEach(ConsumptionLevel.allCases, id: \.self) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var fluidSection: some View {
        FormCard(title: "Fluid Intake") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Type", selection: $fluidType) {
                        ForEach(["Water", "Milk", "Juice", "Formula"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount: \(fluidMl) ml").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { Double(fluidMl) },
                        set: { fluidMl = Int($0) }
                    ), in: 0...500, step: 25)
                }
            }
        }
    }

    private var moodSection: some View {
        FormCard(title: "Mood During Meal") {
            HStack(spacing: 6) {
                ForEach(MoodLevel.allCases, id: \.self) { m in
                    Button { mood = m } label: {
                        VStack(spacing: 4) {
                            Text(m.emoji).font(.title2)
                            Text(m.rawValue).font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mood == m ? Color.ncAccent.opacity(0.25) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(mood == m ? Color.ncAccent : Color.white.opacity(0.18),
                                              lineWidth: 1.2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var allergenSection: some View {
        FormCard(title: "Allergen Check") {
            Toggle(isOn: $allergenChecked) {
                Label("Allergen check completed", systemImage: "checkmark.shield.fill")
                    .font(.subheadline)
            }
            .tint(Color.ncSecondary)

            if allergenChecked {
                TextField("Any reaction notes (optional)", text: $allergenNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var notesSection: some View {
        FormCard(title: "Notes") {
            TextField("Any observations…", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var unselectedChildPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No child selected")
                .font(.title3)
            Text("Pick a child in the inspector to log a meal.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(40)
        .glassBackgroundEffect()
    }

    private func save(for child: Child) {
        let meal = MealRecord(
            keyworkerName: kKeyworkerName,
            mealType: mealType,
            foodOffered: trimmedFood,
            foodConsumed: consumed,
            foodNotes: notes.trimmingCharacters(in: .whitespaces),
            fluidMl: fluidMl,
            fluidType: fluidType,
            allergenChecked: allergenChecked,
            allergenNotes: allergenNotes.trimmingCharacters(in: .whitespaces),
            mood: mood
        )
        meal.child = child
        child.mealRecords.append(meal)
        modelContext.insert(meal)
        try? modelContext.save()
        saved = true
    }
}

// MARK: - Attendance Window

struct AttendanceWindow: View {
    @Environment(SpatialIncidentViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var notes: String = ""

    /// The active attendance record for *today*, creating one on first use.
    private func todayRecord(for child: Child) -> AttendanceRecord {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = child.attendanceRecords.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            return existing
        }
        let record = AttendanceRecord(date: today)
        record.child = child
        child.attendanceRecords.append(record)
        modelContext.insert(record)
        return record
    }

    var body: some View {
        if let child = viewModel.selectedChild {
            let record = todayRecord(for: child)
            NavigationStack {
                ScrollView {
                    VStack(spacing: 22) {
                        header(for: child, status: record.status)
                        actionsSection(record: record)
                        notesSection(record: record)
                        recentSection(child: child)
                    }
                    .padding(20)
                }
                .navigationTitle("Attendance — \(child.firstName)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismissWindow(id: "attendance") }
                    }
                }
            }
            .glassBackgroundEffect()
            .frame(minWidth: 520, minHeight: 580)
        } else {
            unselectedChildPlaceholder
        }
    }

    private func header(for child: Child, status: AttendanceStatus) -> some View {
        HStack(spacing: 14) {
            Image(systemName: status.sfSymbol)
                .font(.system(size: 36))
                .foregroundStyle(statusColor(status))
            VStack(alignment: .leading, spacing: 2) {
                Text(child.fullName)
                    .font(.title3.weight(.semibold))
                Text("Today • \(status.rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(statusColor(status).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func actionsSection(record: AttendanceRecord) -> some View {
        FormCard(title: "Sign In / Out") {
            HStack(spacing: 12) {
                Button {
                    record.signedInAt = Date()
                    record.status = .present
                    try? modelContext.save()
                } label: {
                    Label("Sign In", systemImage: "person.fill.checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ncSecondary)
                .disabled(record.status == .present)

                Button {
                    record.signedOutAt = Date()
                    record.status = .signedOut
                    try? modelContext.save()
                } label: {
                    Label("Sign Out", systemImage: "person.fill.xmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(record.status != .present)
            }

            HStack {
                if let inT = record.signedInAt {
                    Label("In: \(inT.formatted(date: .omitted, time: .shortened))",
                          systemImage: "arrow.right.circle")
                        .font(.caption)
                }
                Spacer()
                if let outT = record.signedOutAt {
                    Label("Out: \(outT.formatted(date: .omitted, time: .shortened))",
                          systemImage: "arrow.left.circle")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "clock.fill").font(.caption)
                Text("Duration: \(record.sessionDurationDescription)")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
    }

    private func notesSection(record: AttendanceRecord) -> some View {
        FormCard(title: "Notes") {
            TextField("Pickup arrangement, behaviour, etc.",
                      text: Binding(
                        get: { record.notes },
                        set: { record.notes = $0 }
                      ),
                      axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func recentSection(child: Child) -> some View {
        let recent = child.attendanceRecords
            .sorted { $0.date > $1.date }
            .prefix(5)
        return FormCard(title: "Last 5 Days") {
            if recent.isEmpty {
                Text("No records yet")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(recent), id: \.id) { r in
                    HStack {
                        Image(systemName: r.status.sfSymbol)
                            .foregroundStyle(statusColor(r.status))
                            .frame(width: 24)
                        Text(r.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                        Spacer()
                        Text(r.sessionDurationDescription)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if r.id != recent.last?.id { Divider().opacity(0.3) }
                }
            }
        }
    }

    private func statusColor(_ s: AttendanceStatus) -> Color {
        switch s {
        case .present:   return Color.ncSecondary
        case .signedOut: return .orange
        case .absent:    return Color.ncAlert
        }
    }

    private var unselectedChildPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No child selected").font(.title3)
            Text("Pick a child in the inspector to record attendance.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(40)
        .glassBackgroundEffect()
    }
}

// MARK: - Shared FormCard Container

private struct FormCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
            content
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
