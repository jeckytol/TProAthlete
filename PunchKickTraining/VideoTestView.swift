//
//  VideoTestView.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 04/08/2025.
//

/*import SwiftUI
import AVKit

struct VideoTestView: View {
    var body: some View {
        VStack {
            if let path = Bundle.main.path(forResource: "Dynamic Arm Pull", ofType: "mp4") {
                let url = URL(fileURLWithPath: path)
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding()
            } else {
                Text("❌ Video not found in bundle")
                    .foregroundColor(.red)
            }
        }
    }
}*/

import SwiftUI

struct VideoTestView: View {
    var body: some View {
        let sampleSegments = [
            TrainingClipSegment(
                roundIndex: 0,
                exerciseName: "Dynamic Arm Pull",
                goalDescription: "10 reps",
                cutoffTime: 30,
                restTime: 10,
                videoFileName: "Dynamic Arm Pull"
            ),
            TrainingClipSegment(
                roundIndex: 1,
                exerciseName: "The Propellor Twist",
                goalDescription: "15 reps",
                cutoffTime: nil,
                restTime: 20,
                videoFileName: "The Propellor Twist"
            )
        ]
        
        // ✅ Use the actual view you want to test
        /*TrainingSummaryClipView(
            trainingName: "Test Training",
            trainingType: "reps",
            complexity: "medium",
            segments: sampleSegments
        )*/
    }
}
