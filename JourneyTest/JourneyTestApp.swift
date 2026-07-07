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
    var body: some Scene {
        WindowGroup {
            TabView {
                JourneyMapView()
                    .tabItem { Label("Journey", systemImage: "map") }

                ContentView()
                    .tabItem { Label("HealthKit", systemImage: "heart.text.square") }
            }
        }
        .modelContainer(for: JourneyProgress.self)
    }
}
