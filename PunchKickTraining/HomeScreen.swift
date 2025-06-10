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
    @EnvironmentObject var bluetoothManager: BluetoothManager
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

                //VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Dopa Trainings")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        //.padding(.bottom, 12)
                    
                    Divider()
                        .background(Color.gray)
                        .padding(.bottom, 8)

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
                                                        .foregroundColor(.gray)
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
                                                        .foregroundColor(.gray)
                                                }
                                                .buttonStyle(.borderless)
                                            }

                                            Button(action: {
                                                deleteTraining(training)
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.gray)
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

                    VStack(spacing: 12) {
                        HStack(spacing: 20) {
                            Button(action: {
                                navigationIntent = .creating
                            }) {
                                Label("New Training", systemImage: "plus.circle.fill")
                                    .fontWeight(.bold)
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                                    .background(Color.black)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 2))
                            }

                            Button(action: {
                                isShowingDownloadModal = true
                            }) {
                                Label("Download", systemImage: "arrow.down.circle")
                                    .fontWeight(.bold)
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                                    .background(Color.black)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange, lineWidth: 2))
                            }
                        }

                        Button(action: {
                            isShowingChallengeModal = true
                        }) {
                            Label("Challenge", systemImage: "flag.checkered")
                                .fontWeight(.bold)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .background(Color.black)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple, lineWidth: 2))
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
                    .environmentObject(bluetoothManager)
            }
        }
    }

   
    //---
    private func handleSave(_ saved: SavedTraining) {
        trainings.removeAll { $0.id == saved.id }
        trainings.append(saved)
        trainings.sort { $0.creationDate > $1.creationDate }
        SavedTraining.saveAll(trainings)
        navigationIntent = nil
    }
    //---

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
