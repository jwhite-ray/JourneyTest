//
//  JourneyTestApp.swift
//  JourneyTest
//
//  Created by Justin Whitehead on 7/7/26.
//

import SwiftUI
import SwiftData

@main
struct JourneyTestApp: App {
    // Shared across every tab so there's a single set of HealthKit observer
    // queries / background delivery registrations and a single authorization
    // request, instead of each view standing up its own manager.
    @State private var healthKitManager = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            TabView {
                JourneyMapView()
                    .tabItem { Label("Journey", systemImage: "map") }

                ContentView()
                    .tabItem { Label("HealthKit", systemImage: "heart.text.square") }
            }
            .environment(healthKitManager)
        }
        .modelContainer(for: JourneyProgress.self)
    }
}
