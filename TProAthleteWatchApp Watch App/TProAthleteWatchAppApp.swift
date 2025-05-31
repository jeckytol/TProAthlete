//
//  TProAthleteWatchAppApp.swift
//  TProAthleteWatchApp Watch App
//
//  Created by Jecky Toledo on 21/05/2025.
//

import SwiftUI

@main
struct TProAthleteWatchApp_Watch_AppApp: App {
    init() {
        // ✅ Force early WCSession activation
        _ = WatchConnectivityManager.shared
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
