// NurseryConnectVisionApp.swift — NurseryConnectVision
// App entry point.  The SpatialIncidentViewModel is created once here and
// injected via @Environment so the windowed inspector and the immersive body
// map share exactly the same marker/pin state.

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

    // Single shared instance — passed to both the window and the immersive space
    // so pins placed in one are instantly visible in the other.
    @State private var sharedViewModel = SpatialIncidentViewModel()

    var body: some Scene {
        WindowGroup {
            VisionRootView()
                .modelContainer(container)
                .environment(sharedViewModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1120, height: 780)

        ImmersiveSpace(id: "BodyMapImmersive") {
            ImmersiveBodyMapView()
                .modelContainer(container)
                .environment(sharedViewModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
