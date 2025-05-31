//
//  RootLauncherView.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 10/05/2025.
//

import SwiftUI

struct RootLauncherView: View {
    @EnvironmentObject var profileManager: UserProfileManager
    @Binding var selectedTraining: SavedTraining?

    var body: some View {
        Group {
            if profileManager.isLoading {
                LoadingView()
            } else if profileManager.profile == nil {
                UserProfileView(profileManager: profileManager)
            } else if let training = selectedTraining {
                ContentView(training: training, selectedTraining: $selectedTraining)
            } else {
                HomeScreen(selectedTraining: $selectedTraining)
            }
        }
        .onAppear {
            profileManager.loadProfile()
        }
    }
}
