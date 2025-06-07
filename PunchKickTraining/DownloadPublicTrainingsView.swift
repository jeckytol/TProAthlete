import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct DownloadPublicTrainingsView: View {
    var onDownload: (SavedTraining) -> Void
    @Environment(\.dismiss) var dismiss
    @AppStorage("nickname") private var currentNickname: String = ""

    @State private var publicTrainings: [SavedTraining] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Public Trainings")
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                                .padding(.top, 10)
                                .padding(.horizontal)

                            Divider()
                                .background(Color.gray)
                                .padding(.horizontal)
                        }

                        // Content States
                        if loading {
                            ProgressView("Loading...")
                                .padding()
                                .foregroundColor(.white)
                        } else if let errorMessage = errorMessage {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        } else if publicTrainings.isEmpty {
                            Text("No public trainings available from other users in the last 7 days.")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(publicTrainings) { training in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(training.name)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text(training.classification.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }

                                        Text("Created by \(training.creatorNickname)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)

                                        Text("Created on \(training.creationDate.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.gray)

                                        Text("Rounds: \(training.rounds.count)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)

                                        Button(action: {
                                            downloadTraining(training)
                                        }) {
                                            HStack {
                                                Image(systemName: "arrow.down.circle.fill")
                                                Text("Download")
                                            }
                                        }
                                        .padding(.top, 6)
                                        .foregroundColor(.green)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)

                                    Divider()
                                        .background(Color.gray.opacity(0.6))
                                        .padding(.horizontal)
                                }
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.top)
                }
            }
            .onAppear(perform: fetchPublicTrainings)
        }
    }

    private func fetchPublicTrainings() {
        loading = true
        errorMessage = nil

        let db = Firestore.firestore()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let downloadedTrainings = Set(SavedTraining.loadAll().map {
            DownloadedTrainingKey(name: $0.name, creator: $0.creatorNickname, roundCount: $0.rounds.count, creationDate: $0.creationDate)
        })

        db.collection("public_trainings")
            .whereField("creationDate", isGreaterThan: Timestamp(date: cutoffDate))
            .getDocuments { snapshot, error in
                loading = false

                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }

                guard let documents = snapshot?.documents else {
                    errorMessage = "No data received."
                    return
                }

                self.publicTrainings = documents.compactMap { doc -> SavedTraining? in
                    let data = doc.data()

                    guard
                        let name = data["name"] as? String,
                        let creator = data["creatorNickname"] as? String,
                        let timestamp = data["creationDate"] as? Timestamp,
                        let isPublic = data["isPublic"] as? Bool,
                        let classificationStr = data["classification"] as? String,
                        let classification = TrainingClassification(rawValue: classificationStr),
                        let roundsData = data["rounds"] as? [[String: Any]]
                    else {
                        return nil
                    }

                    guard creator != currentNickname else {
                        return nil
                    }

                    let creationDate = timestamp.dateValue()

                    let rounds: [TrainingRound] = roundsData.compactMap { roundDict in
                        guard
                            let name = roundDict["name"] as? String,
                            let goalForce = roundDict["goalForce"] as? Double
                        else {
                            return nil
                        }
                        let cutoff = (roundDict["cutoffTime"] as? Double).map { Int($0) }
                        return TrainingRound(name: name, goalForce: goalForce, cutoffTime: cutoff)
                    }

                    let key = DownloadedTrainingKey(name: name, creator: creator, roundCount: rounds.count, creationDate: creationDate)
                    if downloadedTrainings.contains(key) {
                        return nil
                    }

                    return SavedTraining(
                        id: UUID(),
                        name: name,
                        rounds: rounds,
                        creatorNickname: creator,
                        creationDate: creationDate,
                        isPublic: isPublic,
                        classification: classification,
                        isDownloadedFromPublic: true
                    )
                }.sorted(by: { $0.creationDate > $1.creationDate })
            }
    }

    private func downloadTraining(_ training: SavedTraining) {
        var allTrainings = SavedTraining.loadAll()

        if allTrainings.contains(where: { $0.name == training.name && $0.creatorNickname == training.creatorNickname }) {
            print("Training already downloaded.")
            return
        }

        allTrainings.append(training)
        SavedTraining.saveAll(allTrainings)
        print("✅ Downloaded training: \(training.name)")
        onDownload(training)
        dismiss()
    }
}

// MARK: - Helper struct for comparison
struct DownloadedTrainingKey: Hashable {
    let name: String
    let creator: String
    let roundCount: Int
    let creationDate: Date
}
