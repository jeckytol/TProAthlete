import SwiftUI

struct ExerciseView: View {
    @Binding var exercise: Exercise
    var onSave: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Edit Exercise")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Group {
                    styledTextField("Name", text: $exercise.name)
                    styledTextField("Image URL", text: $exercise.imageUrl)
                    styledTextEditor("Description", text: $exercise.description)
                    styledTextField("Video URL", text: $exercise.videoUrl)
                }

                // Stance Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stance")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    HStack {
                        ForEach(Stance.allCases, id: \.self) { stance in
                            Text(stance.rawValue.capitalized)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(exercise.stance == stance ? Color.orange : Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .onTapGesture {
                                    exercise.stance = stance
                                }
                        }
                    }
                }

                // Complexity Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Complexity")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    HStack {
                        ForEach(Complexity.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(exercise.complexity == level ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .onTapGesture {
                                    exercise.complexity = level
                                }
                        }
                    }
                }

                // Sliders
                VStack(alignment: .leading, spacing: 10) {
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
                            .background(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                            .foregroundColor(.green)
                    }

                    Button(action: onDelete) {
                        Text("Delete")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .onTapGesture {
            hideKeyboard()
        }
    }

    // MARK: - Styled Components

    private func styledTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
                .font(.subheadline)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                TextField("", text: text)
                    .padding(10)
                    .foregroundColor(.white)
                    .submitLabel(.done)
                    .onSubmit {
                        hideKeyboard()
                    }
            }
        }
    }

    private func styledTextEditor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
                .font(.subheadline)

            TextEditor(text: text)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.white)
                .cornerRadius(8)
                .frame(height: 120)
                .scrollContentBackground(.hidden) // <- IMPORTANT!
        }
    }

    private func labeledSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(String(format: "%.2f", value.wrappedValue))")
                .foregroundColor(.white)
            Slider(value: value, in: range, step: step)
        }
    }

    private func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}
