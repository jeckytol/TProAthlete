import SwiftUI

struct ExerciseView: View {
    @Binding var exercise: Exercise
    var onSave: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Edit Exercise")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Group {
                    customTextField("Name", text: $exercise.name)
                    customTextField("Image URL", text: $exercise.imageUrl)
                    customTextField("Description", text: $exercise.description)
                    customTextField("Video URL", text: $exercise.videoUrl)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Stance")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    Picker("Stance", selection: $exercise.stance) {
                        ForEach(Stance.allCases, id: \.self) { stance in
                            Text(stance.rawValue.capitalized).tag(stance)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Complexity")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    Picker("Complexity", selection: $exercise.complexity) {
                        ForEach(Complexity.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                VStack(alignment: .leading, spacing: 16) {
                    labeledSlider(title: "Points Factor", value: $exercise.pointsFactor, range: 0...2, step: 0.1)
                    labeledSlider(title: "Sensitivity", value: $exercise.sensitivity, range: 0...3, step: 0.05)
                    labeledSlider(title: "Cooldown", value: $exercise.cooldown, range: 0...1, step: 0.05)
                    labeledSlider(title: "Min Motion Duration", value: $exercise.minMotionDuration, range: 0...1, step: 0.05)
                }

                HStack(spacing: 16) {
                    Button(action: onSave) {
                        Text("Save")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }

                    Button(action: onDelete) {
                        Text("Delete")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Custom Input Field
    private func customTextField(_ placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(placeholder)
                .foregroundColor(.gray)
                .font(.subheadline)
            TextField(placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .foregroundColor(.white)
                .background(Color.white.opacity(0.1))
        }
    }

    // MARK: - Labeled Slider Helper
    private func labeledSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(String(format: "%.2f", value.wrappedValue))")
                .foregroundColor(.white)
            Slider(value: value, in: range, step: step)
        }
    }
}
