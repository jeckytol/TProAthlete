import SwiftUI
import Firebase

struct NewChallengeView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("nickname") private var nickname: String = ""

    @Binding var editingChallenge: Challenge?
    var onUpdate: (() -> Void)? = nil

    @State private var challengeName: String = ""
    @State private var challengeDate = Date()
    @State private var difficulty: Int = 0
    @State private var comment: String = ""
    @State private var publicTrainings: [SavedTraining] = []
    @State private var selectedTraining: SavedTraining?

    var isSaveEnabled: Bool {
        !challengeName.isEmpty && selectedTraining != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    formContent
                        .padding()
                }

                saveButton
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear(perform: initializeData)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(editingChallenge == nil ? "New Challenge" : "Edit Challenge")
                .font(.title.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            Divider().background(Color.gray)
        }
        .padding(.top)
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 20) {
            TextField("< Enter Challenge Name >", text: $challengeName)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.white)
                .italic()
                .bold()
                .cornerRadius(8)

            trainingPicker

            DatePicker("Challenge Date & Time", selection: $challengeDate)
                .colorScheme(.dark)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.white)

            difficultyStars
            commentEditor
        }
    }

    private var trainingPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Select Public Training")
                .foregroundColor(.white)
                .font(.headline)

            Menu {
                ForEach(publicTrainings, id: \.id) { training in
                    Button {
                        selectedTraining = training
                    } label: {
                        VStack(alignment: .leading) {
                            Text(training.name).bold()
                            Text("By \(training.creatorNickname) • \(training.rounds.count) rounds • Total Goal: \(totalForce(of: training))")
                                .font(.caption)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedTraining?.name ?? "< Select a public training >")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }

    private var difficultyStars: some View {
        HStack {
            Text("Difficulty")
                .foregroundColor(.white)
                .font(.headline)

            Spacer()

            HStack {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= difficulty ? "star.fill" : "star")
                        .foregroundColor(.white)
                        .font(.title2)
                        .onTapGesture {
                            difficulty = index
                        }
                }
            }
        }
    }

    private var commentEditor: some View {
        VStack(alignment: .leading) {
            Text("Comment")
                .foregroundColor(.white)
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))

                CustomTextEditor(text: $comment)
                    .frame(height: 120)
                    .foregroundColor(.white)
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
        }
    }

    private var saveButton: some View {
        Button(action: saveChallenge) {
            Text(editingChallenge == nil ? "Save Challenge" : "Update Challenge")
                .bold()
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSaveEnabled ? Color.green : Color.gray, lineWidth: 1)
                )
                .cornerRadius(10)
                .padding([.horizontal, .bottom])
        }
        .disabled(!isSaveEnabled)
    }

    // MARK: - Logic

    private func initializeData() {
        fetchPublicTrainings()

        if let challenge = editingChallenge {
            challengeName = challenge.challengeName
            challengeDate = challenge.startTime
            difficulty = challenge.difficulty
            comment = challenge.comment
        }
    }

    private func fetchPublicTrainings() {
        let db = Firestore.firestore()
        db.collection("public_trainings").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else { return }

            self.publicTrainings = documents.compactMap { doc in
                let data = doc.data()
                guard
                    let name = data["name"] as? String,
                    let creator = data["creatorNickname"] as? String,
                    let timestamp = data["creationDate"] as? Timestamp,
                    let classificationStr = data["classification"] as? String,
                    let classification = TrainingClassification(rawValue: classificationStr),
                    let roundsData = data["rounds"] as? [[String: Any]]
                else {
                    return nil
                }

                let rounds = roundsData.compactMap { dict -> TrainingRound? in
                    guard let name = dict["name"] as? String,
                          let goal = dict["goalForce"] as? Double else { return nil }
                    let cutoff = (dict["cutoffTime"] as? Double).map { Int($0) }
                    return TrainingRound(name: name, goalForce: goal, cutoffTime: cutoff)
                }

                return SavedTraining(
                    id: UUID(),
                    name: name,
                    rounds: rounds,
                    creatorNickname: creator,
                    creationDate: timestamp.dateValue(),
                    isPublic: true,
                    classification: classification,
                    isDownloadedFromPublic: false
                )
            }

            // Restore selected training if editing
            if let editing = editingChallenge {
                selectedTraining = publicTrainings.first { $0.name == editing.trainingName }
            }
        }
    }

    private func totalForce(of training: SavedTraining) -> Int {
        training.rounds.reduce(0) { $0 + Int($1.goalForce) }
    }

    private func saveChallenge() {
        guard let selected = selectedTraining else { return }

        let db = Firestore.firestore()
        let challengeID = editingChallenge?.id ?? UUID().uuidString

        let updated = Challenge(
            id: challengeID,
            challengeName: challengeName,
            trainingName: selected.name,
            startTime: challengeDate,
            difficulty: difficulty,
            comment: comment,
            creatorNickname: nickname,
            registeredNicknames: editingChallenge?.registeredNicknames ?? []
        )

        let challengeData: [String: Any] = [
            "challengeName": updated.challengeName,
            "trainingName": updated.trainingName,
            "startTime": Timestamp(date: updated.startTime),
            "difficulty": updated.difficulty,
            "comment": updated.comment,
            "creatorNickname": updated.creatorNickname,
            "registeredNicknames": updated.registeredNicknames
        ]

        db.collection("challenges").document(challengeID).setData(challengeData) { error in
            if let error = error {
                print("❌ Error saving challenge: \(error)")
            } else {
                onUpdate?()  // 🔁 Refresh parent view
                dismiss()
            }
        }
    }
}
