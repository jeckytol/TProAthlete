import SwiftUI
import Firebase

enum NavigationIntent: Identifiable, Equatable {
    case editing(SavedTraining)
    case creating

    var id: UUID {
        switch self {
        case .editing(let training): return training.id
        case .creating: return UUID()
        }
    }

    static func == (lhs: NavigationIntent, rhs: NavigationIntent) -> Bool {
        switch (lhs, rhs) {
        case (.creating, .creating): return true
        case (.editing(let l), .editing(let r)): return l.id == r.id
        default: return false
        }
    }
}

struct HomeScreen: View {
    @Binding var selectedTraining: SavedTraining?
    @State private var trainings: [SavedTraining] = []
    @State private var navigationIntent: NavigationIntent? = nil
    @AppStorage("nickname") private var nickname: String = ""
    @State private var isShowingDownloadModal = false
    @State private var isShowingChallengeModal = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Text("Dopamineo Trainings")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    if trainings.isEmpty {
                        Spacer()
                        Text("No saved trainings yet.")
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(trainings.indices, id: \.self) { index in
                                    let training = trainings[index]

                                    VStack(alignment: .leading, spacing: 4) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(training.name)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                if training.isPublic {
                                                    Image(systemName: "person.2.fill")
                                                        .foregroundColor(.yellow)
                                                }
                                            }
                                            Text("\(training.rounds.count) rounds")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }

                                        HStack {
                                            Button(action: {
                                                selectedTraining = training
                                            }) {
                                                Text("Select")
                                                    .foregroundColor(.green)
                                            }
                                            .buttonStyle(.borderless)

                                            Spacer()

                                            if !training.isPublic || training.creatorNickname == nickname {
                                                Button(action: {
                                                    navigationIntent = .editing(training)
                                                }) {
                                                    Image(systemName: "pencil")
                                                        .foregroundColor(.blue)
                                                }
                                                .buttonStyle(.borderless)
                                            }

                                            Button(action: {
                                                deleteTraining(training)
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding()
                                    .background(Color.black)

                                    if index < trainings.count - 1 {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 1)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .background(Color.black)
                        }
                    }

                    // MARK: - Button Section
                    VStack(spacing: 12) {
                        HStack(spacing: 20) {
                            Button(action: {
                                navigationIntent = .creating
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("New Training")
                                        .fontWeight(.bold)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }

                            Button(action: {
                                isShowingDownloadModal = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Download")
                                        .fontWeight(.bold)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .background(Color.orange)
                                .cornerRadius(10)
                            }
                        }

                        Button(action: {
                            isShowingChallengeModal = true
                        }) {
                            HStack {
                                Image(systemName: "flag.checkered")
                                Text("Challenge")
                                    .fontWeight(.bold)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .background(Color.purple)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                refreshDownloadedPublicTrainings { updated in
                    trainings = updated
                }
            }
            .sheet(item: $navigationIntent) { intent in
                switch intent {
                case .creating:
                    TrainingEditorView(initialTraining: nil, onSave: handleSave)
                case .editing(let training):
                    TrainingEditorView(initialTraining: training, onSave: handleSave)
                }
            }
            .sheet(isPresented: $isShowingDownloadModal) {
                DownloadPublicTrainingsView(onDownload: handleDownloadedPublicTraining)
            }
            .sheet(isPresented: $isShowingChallengeModal) {
                ChallengeHomeView()
            }
        }
    }

    private func handleSave(_ saved: SavedTraining) {
        if let index = trainings.firstIndex(where: { $0.id == saved.id }) {
            trainings[index] = saved
        } else {
            trainings.append(saved)
        }
        SavedTraining.saveAll(trainings)
        navigationIntent = nil
    }

    private func deleteTraining(_ training: SavedTraining) {
        trainings.removeAll { $0.id == training.id }
        SavedTraining.saveAll(trainings)

        if selectedTraining?.id == training.id {
            selectedTraining = nil
        }

        if training.isPublic && training.creatorNickname == nickname {
            let db = Firestore.firestore()
            db.collection("public_trainings").document(training.name).delete { error in
                if let error = error {
                    print("❌ Failed to delete public training from DB: \(error)")
                } else {
                    print("✅ Public training deleted from DB")
                }
            }
        }
    }

    private func handleDownloadedPublicTraining(_ downloaded: SavedTraining) {
        trainings.append(downloaded)
        SavedTraining.saveAll(trainings)
    }

    private func refreshDownloadedPublicTrainings(completion: @escaping ([SavedTraining]) -> Void) {
        let db = Firestore.firestore()
        let allLocalTrainings = SavedTraining.loadAll()
        var updatedTrainings = allLocalTrainings

        let group = DispatchGroup()

        for (index, training) in allLocalTrainings.enumerated() {
            guard training.isDownloadedFromPublic else { continue }

            group.enter()
            db.collection("public_trainings").document(training.name).getDocument { snapshot, error in
                if let data = snapshot?.data(),
                   let updated = decodeFirestoreTraining(name: training.name, data: data) {
                    updatedTrainings[index] = updated
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            SavedTraining.saveAll(updatedTrainings)
            completion(updatedTrainings)
        }
    }

    private func decodeFirestoreTraining(name: String, data: [String: Any]) -> SavedTraining? {
        guard
            let creator = data["creatorNickname"] as? String,
            let timestamp = data["creationDate"] as? Timestamp,
            let isPublic = data["isPublic"] as? Bool,
            let classStr = data["classification"] as? String,
            let classif = TrainingClassification(rawValue: classStr),
            let roundArray = data["rounds"] as? [[String: Any]]
        else {
            return nil
        }

        let rounds = roundArray.compactMap { roundDict -> TrainingRound? in
            guard
                let name = roundDict["name"] as? String,
                let force = roundDict["goalForce"] as? Double
            else {
                return nil
            }
            let cutoff = (roundDict["cutoffTime"] as? Double).map { Int($0) }
            return TrainingRound(name: name, goalForce: force, cutoffTime: cutoff)
        }

        return SavedTraining(
            id: UUID(),
            name: name,
            rounds: rounds,
            creatorNickname: creator,
            creationDate: timestamp.dateValue(),
            isPublic: isPublic,
            classification: classif,
            isDownloadedFromPublic: true
        )
    }
}
