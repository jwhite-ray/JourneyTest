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
            ContentView()
        }
        .modelContainer(for: JourneyProgress.self)
    }
}
