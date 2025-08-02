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
    @State private var trainingType: TrainingType = .forceDriven
    @State private var exercises: [Exercise] = []
    @State private var selectedVideoURL: URL? = nil

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

                            
                            Text("Training Type")
                                .foregroundColor(.white)
                                .font(.subheadline.bold())

                            HStack {
                                ForEach(TrainingType.allCases, id: \.self) { type in
                                    Text(type.label)
                                        .font(.subheadline)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(trainingType == type ? Color.blue : Color.gray.opacity(0.3))
                                        .foregroundColor(trainingType == type ? .white : .gray)
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            trainingType = type
                                        }
                                }
                            }

                            Text(trainingType.description)
                                .font(.footnote.italic())
                                .foregroundColor(.gray)

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
                                            ForEach(exercises.map { $0.name }, id: \.self) { exercise in
                                                Text(exercise)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                        .foregroundColor(.blue)
                                    }

                                    if let urlString = exercises.first(where: { $0.name == rounds[index].name })?.videoUrl,
                                       let url = URL(string: urlString) {
                                        Button(action: {
                                            selectedVideoURL = url
                                        }) {
                                            Text("▶️ Watch Video")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }

                                    if trainingType == .forceDriven {
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
                                    }

                                    if trainingType == .repsDriven {
                                        HStack {
                                            Text("Reps Goal")
                                                .foregroundColor(.gray)
                                            Spacer()
                                            TextField("", value: Binding(
                                                get: { rounds[index].goalReps ?? 0 },
                                                set: { rounds[index].goalReps = $0 == 0 ? nil : $0 }
                                            ), formatter: NumberFormatter())
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
                                    }

                                    if trainingType == .timeDriven {
                                        HStack {
                                            Text("Round Time (sec)")
                                                .foregroundColor(.gray)
                                            Spacer()
                                            TextField("", value: Binding(
                                                get: { rounds[index].roundTime ?? 60 },
                                                set: { rounds[index].roundTime = $0 }
                                            ), formatter: NumberFormatter())
                                                .keyboardType(.numberPad)
                                                .padding(8)
                                                .frame(width: 100)
                                                .background(Color.gray.opacity(0.2))
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                    }

                                    HStack {
                                        Text("Rest Time (sec)")
                                            .foregroundColor(.gray)
                                        Spacer()
                                        TextField("", value: $rounds[index].restTime, formatter: NumberFormatter())
                                            .keyboardType(.numberPad)
                                            .padding(8)
                                            .frame(width: 100)
                                            .background(Color.gray.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                            .disabled(index == rounds.count - 1) // 🔒 Disable if last round
                                            .opacity(index == rounds.count - 1 ? 0.4 : 1.0) // 🔘 Dim if disabled
                                    }

                                    Divider().background(Color.gray.opacity(0.3))
                                }
                            }

                            Button(action: {
                                rounds.append(TrainingRound(
                                    name: exercises.first?.name ?? "New Round",
                                    goalForce: trainingType == .forceDriven ? 1000 : 0,
                                    goalReps: trainingType == .repsDriven ? 10 : nil,
                                    cutoffTime: nil,
                                    roundTime: trainingType == .timeDriven ? 60 : nil,
                                    restTime: 0
                                ))
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

            if let url = selectedVideoURL {
                VideoOverlayView(url: url) {
                    selectedVideoURL = nil
                }
            }
        }
        .onAppear {
            fetchExercises()
            if let training = initialTraining {
                self.name = training.name
                self.rounds = training.rounds
                self.isPublic = training.isPublic
                self.classification = training.classification
                self.trainingType = training.trainingType
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

    private func fetchExercises() {
        let db = Firestore.firestore()
        db.collection("exercises").order(by: "createdAt", descending: true).getDocuments { snapshot, error in
            if let error = error {
                alertMessage = "Failed to load exercises: \(error.localizedDescription)"
                showAlert = true
                return
            }

            if let documents = snapshot?.documents {
                self.exercises = documents.compactMap { try? $0.data(as: Exercise.self) }
            }
        }
    }

    private func saveTraining() {
        var sanitizedRounds = rounds

        for i in sanitizedRounds.indices {
            switch trainingType {
            case .forceDriven:
                sanitizedRounds[i].goalReps = nil
                sanitizedRounds[i].roundTime = nil
            case .repsDriven:
                sanitizedRounds[i].goalForce = 0
                sanitizedRounds[i].roundTime = nil
            case .timeDriven:
                sanitizedRounds[i].goalForce = 0
                sanitizedRounds[i].goalReps = nil
                sanitizedRounds[i].cutoffTime = nil
            }
        }

        let newTraining = SavedTraining(
            id: initialTraining?.id ?? UUID(),
            name: name,
            rounds: sanitizedRounds,
            creatorNickname: nickname,
            creationDate: initialTraining?.creationDate ?? Date(),
            isPublic: isPublic,
            classification: classification,
            trainingType: trainingType
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
            "trainingType": training.trainingType.rawValue,
            "rounds": training.rounds.map { [
                "name": $0.name,
                "goalForce": $0.goalForce,
                "goalReps": $0.goalReps ?? 0,
                "cutoffTime": $0.cutoffTime ?? 0,
                "roundTime": $0.roundTime ?? 0,
                "restTime": $0.restTime
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
