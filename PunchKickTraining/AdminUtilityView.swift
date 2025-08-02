//
//  AdminUtilityView.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 02/08/2025.
//
import SwiftUI

struct AdminUtilityView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("⚙️ Firestore Field Utility")
                .font(.headline)

            Button("Run Field Rename") {
                FirestoreFieldRenamer().renameField(
                    in: "challenge_progress",
                    from: "totalStrikes",
                    to: "totalReps"
                )
                /*FirestoreFieldRenamer().renameFieldInArray(
                    collection: "public_trainings",
                    arrayField: "rounds",
                    oldField: "goalStrikes",
                    newField: "goalReps"
                )*/
            }
            .padding()
            .background(Color.red.opacity(0.2))
            .cornerRadius(10)
        }
        .padding()
    }
}
