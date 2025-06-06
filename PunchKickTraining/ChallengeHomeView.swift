import SwiftUI
import Firebase

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct ChallengeHomeView: View {
    @State private var challenges: [Challenge] = []
    @State private var isLoading = true
    @State private var isPresentingNewChallenge = false
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    @State private var showingParticipants: [String] = []
    @State private var showingComment: IdentifiableString?
    @AppStorage("nickname") private var nickname: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    headerView

                    if isLoading {
                        loadingView
                    } else if challenges.isEmpty {
                        emptyStateView
                    } else {
                        challengesList
                    }
                }

                if showConfirmation {
                    confirmationOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresentingNewChallenge = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewChallenge, onDismiss: fetchChallenges) {
                NewChallengeView()
            }
            .onAppear(perform: fetchChallenges)
            .alert(item: $showingComment) { comment in
                Alert(title: Text("Full Comment"), message: Text(comment.value), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: Binding<Bool>(
                get: { !showingParticipants.isEmpty },
                set: { newValue in if !newValue { showingParticipants = [] } }
            )) {
                NavigationView {
                    List {
                        ForEach(showingParticipants, id: \.self) { name in
                            Text(name)
                        }
                    }
                    .navigationTitle("Participants")
                    .navigationBarTitleDisplayMode(.inline)
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

    private var headerView: some View {
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
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("No upcoming challenges.")
                .foregroundColor(.gray)
                .padding()
            Spacer()
        }
    }

    private var challengesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(challenges) { challenge in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(challenge.challengeName)
                            .font(.headline.bold())
                            .foregroundColor(isRegistered(for: challenge) ? .green : .gray)

                        HStack {
                            Text("By: \(challenge.creatorNickname)")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(difficultyStars(for: challenge.difficulty))
                                .foregroundColor(.white)
                        }

                        Text("Training: \(challenge.trainingName)")
                            .font(.subheadline)
                            .foregroundColor(.white)

                        if !challenge.comment.isEmpty {
                            Text(truncatedComment(challenge.comment))
                                .foregroundColor(.white)
                                .font(.body)
                                .italic()
                                .padding(6)
                                .background(Color.gray.opacity(0.25))
                                .cornerRadius(6)
                                .onTapGesture {
                                    showingComment = IdentifiableString(value: challenge.comment)
                                }
                        }

                        HStack {
                            Button(action: {
                                toggleRegistration(for: challenge)
                            }) {
                                Text(isRegistered(for: challenge) ? "Unregister" : "Register")
                                    .font(.caption)
                                    .padding(6)
                                    .foregroundColor(.white)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(6)
                            }

                            Spacer()

                            Button(action: {
                                showingParticipants = challenge.registeredNicknames
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.gray)
                                    Text("\(challenge.registeredNicknames.count)")
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        HStack {
                            if canEnterWaitingRoom(for: challenge) {
                                NavigationLink(destination: ChallengeWaitingRoomView(challenge: challenge)) {
                                    Text("Enter Waiting Room")
                                        .font(.caption)
                                        .padding(6)
                                        .foregroundColor(.white)
                                        .background(Color.blue.opacity(0.7))
                                        .cornerRadius(6)
                                }
                            }

                            Spacer()

                            if challenge.creatorNickname == nickname {
                                Button(action: {
                                    deleteChallenge(challenge)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Text(challenge.startTime.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
            }
            .padding()
        }
    }

    private var confirmationOverlay: some View {
        VStack {
            Spacer()
            Text(confirmationMessage)
                .foregroundColor(.green)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .transition(.opacity)
            Spacer().frame(height: 40)
        }
        .animation(.easeInOut, value: showConfirmation)
    }

    // MARK: - Utility Functions

    private func fetchChallenges() {
        isLoading = true
        let db = Firestore.firestore()
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: 3, to: now)!

        db.collection("challenges")
            .order(by: "startTime")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false

                    guard let documents = snapshot?.documents else {
                        print("❌ No snapshot or error: \(error?.localizedDescription ?? "Unknown error")")
                        self.challenges = []
                        return
                    }

                    let loadedChallenges: [Challenge] = documents.compactMap { doc in
                        let data = doc.data()
                        guard
                            let challengeName = data["challengeName"] as? String,
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
                        if startTime < now || startTime > cutoff { return nil }

                        return Challenge(
                            id: doc.documentID,
                            challengeName: challengeName,
                            trainingName: trainingName,
                            startTime: startTime,
                            difficulty: difficulty,
                            comment: comment,
                            creatorNickname: creator,
                            registeredNicknames: registered
                        )
                    }

                    self.challenges = loadedChallenges
                }
            }
    }

    private func difficultyStars(for level: Int) -> String {
        String(repeating: "★", count: level)
    }

    private func truncatedComment(_ text: String) -> String {
        let words = text.split(separator: " ")
        return words.count <= 6 ? text : words.prefix(6).joined(separator: " ") + "..."
    }

    private func isRegistered(for challenge: Challenge) -> Bool {
        challenge.registeredNicknames.contains(nickname)
    }

    private func toggleRegistration(for challenge: Challenge) {
        let db = Firestore.firestore()
        let docRef = db.collection("challenges").document(challenge.id)

        var updated = challenge
        if isRegistered(for: challenge) {
            updated.registeredNicknames.removeAll { $0 == nickname }
            confirmationMessage = "Unregistered successfully"
        } else {
            updated.registeredNicknames.append(nickname)
            confirmationMessage = "Registered successfully"
        }

        docRef.updateData(["registeredNicknames": updated.registeredNicknames]) { error in
            if error == nil {
                if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                    challenges[index] = updated
                    showConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showConfirmation = false
                    }
                }
            }
        }
    }

    private func deleteChallenge(_ challenge: Challenge) {
        let db = Firestore.firestore()
        db.collection("challenges").document(challenge.id).delete { error in
            if error == nil {
                challenges.removeAll { $0.id == challenge.id }
            }
        }
    }

    private func canEnterWaitingRoom(for challenge: Challenge) -> Bool {
        let now = Date()
        let threshold = challenge.startTime.addingTimeInterval(-15 * 60) // 15 minutes before start
        return now >= threshold && now <= challenge.startTime && isRegistered(for: challenge)
    }
}
