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

    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section(header: Text("Training Info").foregroundColor(.white)) {
                        ZStack(alignment: .leading) {
                            if name.isEmpty {
                                Text("Training Name")
                                    .foregroundColor(.gray)
                                    .italic()
                                    .bold()
                            }
                            TextField("", text: $name)
                                .foregroundColor(.black)
                                .italic()
                                .bold()
                                .focused($isNameFocused)
                        }

                        Toggle("Public Training", isOn: $isPublic)
                            .foregroundColor(.black)

                        Picker("Classification", selection: $classification) {
                            ForEach(TrainingClassification.allCases, id: \.self) { level in
                                Text(level.rawValue.capitalized)
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    Section(header: Text("Rounds").foregroundColor(.white)) {
                        ForEach(rounds.indices, id: \.self) { index in
                            VStack(alignment: .leading) {
                                Picker("Exercise", selection: $rounds[index].name) {
                                    ForEach(predefinedExercises, id: \.self) { exercise in
                                        Text(exercise).foregroundColor(.black)
                                    }
                                }

                                HStack {
                                    Text("Force Goal (N)").foregroundColor(.black)
                                    Spacer()
                                    TextField("Goal", value: $rounds[index].goalForce, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 100)
                                        .foregroundColor(.gray)
                                }

                                HStack {
                                    Text("Cutoff Time (sec)").foregroundColor(.black)
                                    Spacer()
                                    TextField("Optional", value: Binding(
                                        get: { rounds[index].cutoffTime ?? 0 },
                                        set: { rounds[index].cutoffTime = $0 == 0 ? nil : $0 }
                                    ), formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 100)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Button(action: {
                            rounds.append(TrainingRound(name: predefinedExercises.first ?? "New Round", goalForce: 1000))
                        }) {
                            Label("Add Round", systemImage: "plus.circle")
                                .foregroundColor(.gray)
                        }
                    }

                    if nickname == "Unknown" {
                        Section {
                            Text("⚠️ Please complete your profile in Settings before saving a training.")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(initialTraining == nil ? "New Training" : "Edit Training")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: {
                            let newTraining = SavedTraining(
                                id: initialTraining?.id ?? UUID(),
                                name: name,
                                rounds: rounds,
                                creatorNickname: nickname,
                                creationDate: initialTraining?.creationDate ?? Date(),
                                isPublic: isPublic,
                                classification: classification
                            )

                            print("🟢 Attempting to save with nickname: \(nickname)")

                            if isPublic {
                                checkAndSavePublicTraining(newTraining)
                            } else {
                                onSave(newTraining)
                                dismiss()
                            }
                        }) {
                            Text("Save")
                                .foregroundColor(isSaveEnabled ? .green : .gray)
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
                    print("👤 Current nickname: \(nickname)")
                }
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isNameFocused = false
                    }
            )
        }
    }

    private var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !rounds.isEmpty && nickname != "Unknown"
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
