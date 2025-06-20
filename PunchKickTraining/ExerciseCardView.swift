import SwiftUI

struct ExerciseCardView: View {
    let exercise: Exercise
    var onVideoTap: () -> Void
    var onEditTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.title3.bold())
                    .foregroundColor(.orange)

                Spacer()

                Button(action: onEditTap) {
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
            }

            Text(exercise.description)
                .font(.subheadline)
                .foregroundColor(.white)

            HStack {
                Label(exercise.stance.rawValue.capitalized, systemImage: "figure.walk")
                    .foregroundColor(.blue)
                Spacer()
                Text(exercise.complexity.rawValue.capitalized)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(6)
            }

            Button(action: onVideoTap) {
                Text("▶️ Watch Video")
                    .foregroundColor(.cyan)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(radius: 6)
    }
}
