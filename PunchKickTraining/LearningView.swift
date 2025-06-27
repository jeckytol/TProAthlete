import SwiftUI


struct LearningView: View {
    @StateObject private var manager = ExerciseManager.shared
    @State private var selectedVideoURL: URL?
    @State private var editingExercise: Exercise? = nil
    @State private var draftExercise = Exercise(
        name: "",
        imageUrl: "",
        description: "",
        videoUrl: "",
        stance: .front,
        complexity: .easy
    )
    @State private var isEditing: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(manager.exercises) { exercise in
                            ExerciseCardView(
                                exercise: exercise,
                                onVideoTap: {
                                    selectedVideoURL = URL(string: exercise.videoUrl)
                                },
                                onEditTap: {
                                    if let found = manager.exercises.first(where: { $0.id == exercise.id }) {
                                        draftExercise = found
                                        editingExercise = found
                                        isEditing = true
                                    }
                                }
                            )
                            .scaleEffect(1.0)
                            .opacity(1.0)
                            .animation(.spring(), value: manager.exercises)
                        }
                    }
                    .padding()
                }

                Button(action: {
                    // Prepare new empty draft
                    draftExercise = Exercise(
                        name: "",
                        imageUrl: "",
                        description: "",
                        videoUrl: "",
                        stance: .front,
                        complexity: .easy
                    )
                    editingExercise = nil
                    isEditing = true
                }) {
                    Text("➕ Add New Exercise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }

            if let videoURL = selectedVideoURL {
                VideoOverlayView(url: videoURL) {
                    selectedVideoURL = nil
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let existing = editingExercise,
               let index = manager.exercises.firstIndex(where: { $0.id == existing.id }) {
                // Editing existing
                let binding = Binding(get: {
                    manager.exercises[index]
                }, set: { newValue in
                    manager.exercises[index] = newValue
                })

                ExerciseView(
                    exercise: binding,
                    onSave: {
                        isEditing = false
                        manager.saveExercise(binding.wrappedValue)
                    },
                    onDelete: {
                        isEditing = false
                        manager.deleteExercise(binding.wrappedValue)
                    }
                )
            } else {
                // Adding new
                ExerciseView(
                    exercise: $draftExercise,
                    onSave: {
                        isEditing = false
                        manager.saveExercise(draftExercise)
                    },
                    onDelete: {
                        isEditing = false
                    }
                )
            }
        }
        .navigationTitle("Learning")
        .foregroundColor(.white)
        .onAppear {
            manager.fetchExercises()
        }
    }
}
