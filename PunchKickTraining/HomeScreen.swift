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
    @State private var isShowingClip = false
    @State private var selectedClipTraining: SavedTraining? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Dopa Trainings")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 10)

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

                                    ZStack(alignment: .topTrailing) {
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
                                            
                                            HStack {
                                                Spacer()
                                                Button(action: {
                                                    selectedClipTraining = training
                                                }) {
                                                    Text("View Clip")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .stroke(Color.gray, lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding()
                                        .background(Color.black)

                                        if let badge = badgeForType(training.trainingType) {
                                            Text(badge.label)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(badge.color.opacity(0.6))
                                                .clipShape(Capsule())
                                                .padding([.top, .trailing], 6)
                                        }
                                    }

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
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                let all = SavedTraining.loadAll()
                print("🔍 Loaded \(all.count) SavedTrainings from UserDefaults")
                for t in all {
                    print("📦 '\(t.name)' — \(t.rounds.count) rounds, downloadedFromPublic: \(t.isDownloadedFromPublic)")
                }
                refreshDownloadedPublicTrainings(from: all) { merged in
                    trainings = merged.sorted(by: { $0.creationDate > $1.creationDate })
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
            
            //---
            
            .sheet(item: $selectedClipTraining) { training in
                TrainingSummaryClipView(training: training)
            }
            
            //---
        }
    }

    private func badgeForType(_ type: TrainingType) -> (label: String, color: Color)? {
        switch type {
        case .timeDriven:
            return ("TIME", .blue)
        case .forceDriven:
            return ("FORCE", .purple)
        case .repsDriven:
            return ("REPS", .green)
        }
    }

    private func handleSave(_ saved: SavedTraining) {
        trainings.removeAll { $0.id == saved.id }
        trainings.append(saved)
        trainings.sort { $0.creationDate > $1.creationDate }
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

    private func refreshDownloadedPublicTrainings(from baseTrainings: [SavedTraining], completion: @escaping ([SavedTraining]) -> Void) {
        let db = Firestore.firestore()
        var updatedTrainings = baseTrainings
        let group = DispatchGroup()

        for (index, training) in baseTrainings.enumerated() {
            guard training.isDownloadedFromPublic else { continue }

            group.enter()
            db.collection("public_trainings").document(training.name).getDocument { snapshot, error in
                defer { group.leave() }

                guard let data = snapshot?.data(),
                      let updated = decodeFirestoreTraining(name: training.name, data: data) else {
                    return
                }

                updatedTrainings[index] = updated
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
            guard let name = roundDict["name"] as? String else { return nil }

            let goalForce = roundDict["goalForce"] as? Double ?? 0
            let goalReps = roundDict["goalReps"] as? Int
            let cutoffTime = roundDict["cutoffTime"] as? Int
            let roundTime = roundDict["roundTime"] as? Int
            let restTime = roundDict["restTime"] as? Int ?? 0

            return TrainingRound(
                name: name,
                goalForce: goalForce,
                goalReps: goalReps,
                cutoffTime: cutoffTime,
                roundTime: roundTime,
                restTime: restTime
            )
        }

        let trainingTypeRaw = data["trainingType"] as? String ?? ""
        let resolvedType: TrainingType = {
            if trainingTypeRaw == "strengthDriven" {
                return .forceDriven
            } else {
                return TrainingType(rawValue: trainingTypeRaw) ?? .forceDriven
            }
        }()

        return SavedTraining(
            id: UUID(),
            name: name,
            rounds: rounds,
            creatorNickname: creator,
            creationDate: timestamp.dateValue(),
            isPublic: isPublic,
            classification: classif,
            isDownloadedFromPublic: true,
            trainingType: resolvedType
        )
    }
}

