import SwiftUI
import AVKit

struct TrainingClipSegment {
    let roundIndex: Int
    let exerciseName: String
    let goalDescription: String
    let cutoffTime: Int?  // in seconds
    let restTime: Int     // in seconds
    let videoFileName: String
}

struct TrainingSummaryClipView: View {
    let training: SavedTraining

    var body: some View {
        let segments = generateClipSegments(from: training)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("📋 \(training.name)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Text("Type: \(displayName(for: training.trainingType)) • Complexity: \(training.classification.rawValue.capitalized)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top)

                // Segments
                ForEach(segments.indices, id: \.self) { i in
                    let segment = segments[i]

                    VStack(alignment: .leading, spacing: 10) {
                        Text("🏁 Round \(segment.roundIndex + 1)")
                            .font(.headline)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Exercise: \(segment.exerciseName)")
                            Text("Goal: \(segment.goalDescription)")
                            if let cutoff = segment.cutoffTime {
                                Text("⏱ Cutoff: \(cutoff) sec")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.gray)

                        // Video preview
                        if let path = Bundle.main.path(forResource: segment.videoFileName, ofType: "mp4") {
                            let url = URL(fileURLWithPath: path)
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(height: 200)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        } else {
                            Text("❌ Video not found: \(segment.videoFileName)")
                                .foregroundColor(.red)
                        }

                        // Rest block
                        if segment.restTime > 0 {
                            HStack {
                                Spacer()
                                Text("💤 Rest Time: \(segment.restTime) sec")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    func displayName(for type: TrainingType) -> String {
        switch type {
        case .repsDriven:
            return "Reps"
        case .forceDriven:
            return "Force"
        case .timeDriven:
            return "Time"
        }
    }
}

func generateClipSegments(from training: SavedTraining) -> [TrainingClipSegment] {
    training.rounds.enumerated().map { (index, round) in
        let goalDescription: String
        switch training.trainingType {
        case .repsDriven:
            let reps = round.goalReps ?? 0
            goalDescription = "\(reps) reps"
        case .forceDriven:
            let force = Int(round.goalForce ?? 0)
            goalDescription = "\(force)N"
        case .timeDriven:
            let time = Int(round.roundTime ?? 0)
            goalDescription = "\(time) sec"
        }

        return TrainingClipSegment(
            roundIndex: index,
            exerciseName: round.name,
            goalDescription: goalDescription,
            cutoffTime: (round.cutoffTime ?? 0) > 0 ? Int(round.cutoffTime!) : nil,
            restTime: Int(round.restTime),
            videoFileName: round.name // assumes exact match with video file
        )
    }
    
    
}

