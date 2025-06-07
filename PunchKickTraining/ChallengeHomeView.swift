import SwiftUI
import Firebase

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct ChallengeHomeView: View {
    @State private var challenges: [Challenge] = []
    @State private var isLoading = true
    @State private var editingChallenge: Challenge? = nil
    @State private var showingParticipants: [String] = []
    @State private var showingComment: IdentifiableString?
    @State private var isPresentingNewChallenge = false
    @AppStorage("nickname") private var nickname: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if isLoading {
                        loadingView
                    } else if challenges.isEmpty {
                        emptyState
                    } else {
                        challengesList
                    }
                }
            }
            .sheet(item: $editingChallenge, onDismiss: fetchChallenges) { challenge in
                NewChallengeView(editingChallenge: .constant(challenge))
            }
            .sheet(isPresented: $isPresentingNewChallenge, onDismiss: fetchChallenges) {
                NewChallengeView(editingChallenge: .constant(nil))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingNewChallenge = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear(perform: fetchChallenges)
            .alert(item: $showingComment) { comment in
                Alert(title: Text("Comment"), message: Text(comment.value), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: Binding<Bool>(
                get: { !showingParticipants.isEmpty },
                set: { newVal in if !newVal { showingParticipants = [] } }
            )) {
                NavigationView {
                    List {
                        ForEach(showingParticipants, id: \.self) { participant in
                            Text(participant)
                        }
                    }
                    .navigationTitle("Participants")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showingParticipants = []
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Challenges")
                .font(.title.bold())
                .foregroundColor(.white)
                .padding(.horizontal)
            Divider().background(Color.gray)
        }
        .padding(.top)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading Challenges...")
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No upcoming challenges.")
                .foregroundColor(.gray)
            Spacer()
        }
    }

    private var challengesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(challenges) { challenge in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(challenge.challengeName)
                            .foregroundColor(isRegistered(challenge) ? .green : .white)
                            .bold()

                        HStack {
                            Text("By: \(challenge.creatorNickname)")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(repeating: "★", count: challenge.difficulty))
                                .foregroundColor(.gray)
                        }

                        Text("Training: \(challenge.trainingName)")
                            .foregroundColor(.white)

                        if !challenge.comment.isEmpty {
                            Text(truncatedComment(challenge.comment))
                                .foregroundColor(.white)
                                .italic()
                                .onTapGesture {
                                    showingComment = IdentifiableString(value: challenge.comment)
                                }
                        }

                        HStack {
                            if challenge.startTime > Date() {
                                Button(isRegistered(challenge) ? "Unregister" : "Register") {
                                    toggleRegistration(for: challenge)
                                }
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(6)
                            }

                            Spacer()

                            Button {
                                showingParticipants = challenge.registeredNicknames
                            } label: {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Text("\(challenge.registeredNicknames.count)")
                                }
                                .foregroundColor(.gray)
                            }
                        }

                        HStack {
                            if canEnterWaitingRoom(for: challenge) {
                                NavigationLink("Enter Waiting Room", destination: ChallengeWaitingRoomView(challenge: challenge))
                                    .font(.caption)
                                    .padding(6)
                                    .foregroundColor(.white)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            }

                            Spacer()

                            if challenge.creatorNickname == nickname {
                                Button {
                                    editingChallenge = challenge
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.gray)
                                }

                                Button {
                                    deleteChallenge(challenge)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Text(challenge.startTime.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.gray)
                            .font(.footnote)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }

    // MARK: - Firestore Logic

    private func fetchChallenges() {
        isLoading = true
        let db = Firestore.firestore()
        let now = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        let threeDaysAhead = Calendar.current.date(byAdding: .day, value: 3, to: now)!

        db.collection("challenges")
            .order(by: "startTime")
            .getDocuments { snapshot, error in
                defer { isLoading = false }

                guard let documents = snapshot?.documents else {
                    print("❌ Failed to fetch: \(error?.localizedDescription ?? "No snapshot")")
                    challenges = []
                    return
                }

                let loaded: [Challenge] = documents.compactMap { doc in
                    let data = doc.data()
                    guard
                        let name = data["challengeName"] as? String,
                        let trainingName = data["trainingName"] as? String,
                        let timestamp = data["startTime"] as? Timestamp,
                        let difficulty = data["difficulty"] as? Int,
                        let comment = data["comment"] as? String,
                        let creator = data["creatorNickname"] as? String,
                        let registered = data["registeredNicknames"] as? [String]
                    else {
                        return nil
                    }

                    let startTime = timestamp.dateValue()
                    guard startTime > oneHourAgo && startTime <= threeDaysAhead else {
                        return nil
                    }

                    return Challenge(
                        id: doc.documentID,
                        challengeName: name,
                        trainingName: trainingName,
                        startTime: startTime,
                        difficulty: difficulty,
                        comment: comment,
                        creatorNickname: creator,
                        registeredNicknames: registered
                    )
                }

                challenges = loaded
            }
    }

    private func toggleRegistration(for challenge: Challenge) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        let db = Firestore.firestore()
        let docRef = db.collection("challenges").document(challenge.id)

        var updated = challenge
        if isRegistered(challenge) {
            updated.registeredNicknames.removeAll { $0 == nickname }
        } else {
            updated.registeredNicknames.append(nickname)
        }

        docRef.updateData(["registeredNicknames": updated.registeredNicknames]) { error in
            if error == nil {
                challenges[index] = updated
            } else {
                print("❌ Error updating registration: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }

    private func deleteChallenge(_ challenge: Challenge) {
        let db = Firestore.firestore()
        db.collection("challenges").document(challenge.id).delete { error in
            if error == nil {
                challenges.removeAll { $0.id == challenge.id }
            } else {
                print("❌ Error deleting challenge: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }

    // MARK: - Helpers

    private func isRegistered(_ challenge: Challenge) -> Bool {
        challenge.registeredNicknames.contains(nickname)
    }

    private func truncatedComment(_ text: String) -> String {
        let words = text.split(separator: " ")
        return words.count <= 6 ? text : words.prefix(6).joined(separator: " ") + "..."
    }

    private func canEnterWaitingRoom(for challenge: Challenge) -> Bool {
        let now = Date()
        let threshold = challenge.startTime.addingTimeInterval(-15 * 60)
        return now >= threshold && now <= challenge.startTime && isRegistered(challenge)
    }
}
