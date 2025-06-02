import SwiftUI
import Firebase

struct TrainingEditorView: View {
    var initialTraining: SavedTraining?
    var onSave: (SavedTraining) -> Void

    @Environment(\.dismiss) var dismiss
    @AppStorage("nickname") private var nickname: String = "Unknown"

    @State private var name: String = ""
    @State private var rounds: [TrainingRound] = []
    @State private var isPublic: Bool = false
    @State private var classification: TrainingClassification = .medium

    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(initialTraining == nil ? "New Training" : "Edit Training")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                            //.padding(.horizontal)
                            .padding(.top, 10)

                        Divider().background(Color.gray.opacity(0.3))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Training Info")
                                .foregroundColor(.white)
                                .font(.headline)

                            TextField("Training Name", text: $name)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .font(.system(.body, design: .default).bold().italic())
                                .cornerRadius(8)

                            HStack {
                                Text("Public Training")
                                    .foregroundColor(.gray)
                                Spacer()
                                Toggle("", isOn: $isPublic)
                            }

                            HStack {
                                Text("Classification")
                                    .foregroundColor(.gray)
                                Spacer()
                                Picker("Classification", selection: $classification) {
                                    ForEach(TrainingClassification.allCases, id: \.self) { level in
                                        Text(level.rawValue.capitalized)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.blue)
                            }
                        }

                        Divider().background(Color.gray.opacity(0.3))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rounds")
                                .foregroundColor(.white)
                                .font(.headline)

                            ForEach(rounds.indices, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Round \(index + 1)")
                                        .foregroundColor(.gray)

                                    HStack {
                                        Text("Exercise")
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Picker("Exercise", selection: $rounds[index].name) {
                                            ForEach(predefinedExercises, id: \.self) { exercise in
                                                Text(exercise)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                        .foregroundColor(.blue)
                                    }

                                    HStack {
                                        Text("Force Goal (N)")
                                            .foregroundColor(.gray)
                                        Spacer()
                                        TextField("", value: $rounds[index].goalForce, formatter: NumberFormatter())
                                            .keyboardType(.numberPad)
                                            .padding(8)
                                            .frame(width: 100)
                                            .background(Color.gray.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }

                                    HStack {
                                        Text("Cutoff Time (sec)")
                                            .foregroundColor(.gray)
                                        Spacer()
                                        TextField("Optional", value: Binding(
                                            get: { rounds[index].cutoffTime ?? 0 },
                                            set: { rounds[index].cutoffTime = $0 == 0 ? nil : $0 }
                                        ), formatter: NumberFormatter())
                                            .keyboardType(.numberPad)
                                            .padding(8)
                                            .frame(width: 100)
                                            .background(Color.gray.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }

                                    Divider().background(Color.gray.opacity(0.3))
                                }
                            }

                            Button(action: {
                                rounds.append(TrainingRound(name: predefinedExercises.first ?? "New Round", goalForce: 1000))
                            }) {
                                Label("Add Round", systemImage: "plus.circle")
                                    .foregroundColor(.gray)
                            }
                        }

                        if nickname == "Unknown" {
                            Text("⚠️ Please complete your profile in Settings before saving a training.")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    .padding()
                }

                // Save button pinned at the bottom
                Button(action: saveTraining) {
                    Text("Save")
                        .font(.footnote.bold())
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSaveEnabled ? Color.green : Color.gray, lineWidth: 3)
                        )
                        .cornerRadius(10)
                        .padding([.horizontal, .bottom])
                }
                .disabled(!isSaveEnabled)
            }
        }
        .onAppear {
            if let training = initialTraining {
                self.name = training.name
                self.rounds = training.rounds
                self.isPublic = training.isPublic
                self.classification = training.classification
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !rounds.isEmpty && nickname != "Unknown"
    }

    private func saveTraining() {
        let newTraining = SavedTraining(
            id: initialTraining?.id ?? UUID(),
            name: name,
            rounds: rounds,
            creatorNickname: nickname,
            creationDate: initialTraining?.creationDate ?? Date(),
            isPublic: isPublic,
            classification: classification
        )

        if isPublic {
            checkAndSavePublicTraining(newTraining)
        } else {
            onSave(newTraining)
            dismiss()
        }
    }

    private func checkAndSavePublicTraining(_ training: SavedTraining) {
        let db = Firestore.firestore()
        let ref = db.collection("public_trainings").document(training.name)

        ref.getDocument { snapshot, error in
            if let error = error {
                alertMessage = "Failed to check training: \(error.localizedDescription)"
                showAlert = true
                return
            }

            if let snapshot = snapshot, snapshot.exists {
                let creator = snapshot.get("creatorNickname") as? String ?? ""
                if training.creatorNickname == creator {
                    savePublicTraining(training)
                } else {
                    alertMessage = "You cannot modify this public training. Only the creator (\(creator)) can update it."
                    showAlert = true
                }
            } else {
                savePublicTraining(training)
            }
        }
    }

    private func savePublicTraining(_ training: SavedTraining) {
        let db = Firestore.firestore()
        let publicTrainingsRef = db.collection("public_trainings")

        let trainingData: [String: Any] = [
            "name": training.name,
            "creatorNickname": training.creatorNickname,
            "creationDate": Timestamp(date: training.creationDate),
            "isPublic": training.isPublic,
            "classification": training.classification.rawValue,
            "rounds": training.rounds.map { [
                "name": $0.name,
                "goalForce": $0.goalForce,
                "cutoffTime": $0.cutoffTime ?? 0
            ]}
        ]

        publicTrainingsRef.document(training.name).setData(trainingData) { error in
            if let error = error {
                alertMessage = "Failed to save training: \(error.localizedDescription)"
                showAlert = true
            } else {
                onSave(training)
                dismiss()
            }
        }
    }
}
