import SwiftUI

struct TrainingCertificateView: View {
    let summary: TrainingSummary
    var onShare: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            ZStack {
                // Faded DopaIcon as background
                Image("DopaIcon")
                    .resizable()
                    .scaledToFit()
                    .opacity(0.14)
                    .frame(width: 240, height: 240)
                    .offset(y: -10)

                VStack(spacing: 14) {
                    Spacer(minLength: 16)

                    certificateRow(label: "Athlete Name", value: summary.nickname, icon: "person.circle")
                    certificateRow(label: "Training", value: summary.trainingName, icon: "figure.strengthtraining.traditional")
                    certificateRow(label: "Date", value: formattedDate(summary.date), icon: "calendar")
                    certificateRow(label: "Elapsed Time", value: formatTime(summary.elapsedTime), icon: "timer")
                    certificateRow(label: "Total Force", value: String(format: "%.0f", summary.totalForce), icon: "bolt.fill")
                    certificateRow(label: "Total Points", value: String(format: "%.0f", summary.totalPoints ?? 0.0), icon: "star.circle.fill")
                    certificateRow(label: "Reps", value: "\(summary.repCount)", icon: "flame.fill")
                    certificateRow(label: "Goal Completion", value: "\(Int(summary.trainingGoalCompletionPercentage))%", icon: "checkmark.seal.fill")

                    Spacer(minLength: 16)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue, lineWidth: 2)
                )
            }

            if let onShare = onShare {
                Button(action: onShare) {
                    Text("📤 Share your achievement")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 1.5)
                        )
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }

            Spacer(minLength: 20)
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }

    func certificateRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)

            Text("\(label):")
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.headline)
                .bold()
                .foregroundColor(.white)
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
