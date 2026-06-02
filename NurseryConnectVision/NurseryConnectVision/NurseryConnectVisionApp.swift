// NurseryConnectVisionApp.swift — NurseryConnectVision
// App entry point.
// SwiftData schema is byte-for-byte identical to the iPad target so the
// on-device store can be opened by both processes without migration.

import SwiftUI
import SwiftData

@main
struct NurseryConnectVisionApp: App {

    let container: ModelContainer = {
        let schema = Schema([
            Child.self,
            DailyLog.self,
            MealRecord.self,
            Incident.self,
            EYFSMilestone.self,
            AttendanceRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            VisionRootView()
                .modelContainer(container)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1120, height: 780)

        // Full-immersion body map — opened via toolbar in VisionIncidentInspectorView
        ImmersiveSpace(id: "BodyMapImmersive") {
            ImmersiveBodyMapView()
                .modelContainer(container)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
