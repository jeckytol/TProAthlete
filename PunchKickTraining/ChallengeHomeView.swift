import SwiftUI
import Firebase

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct ChallengeHomeView: View {
    @StateObject private var viewModel = ChallengeListViewModel()

    @State private var editingChallenge: Challenge? = nil
    @State private var showingParticipants: [String] = []
    @State private var showingComment: IdentifiableString?
    @State private var isPresentingNewChallenge = false
    @State private var selectedChallenge: Challenge? = nil

    @AppStorage("nickname") private var nickname: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.challenges.isEmpty {
                        emptyState
                    } else {
                        challengesList
                    }
                }
            }
            .navigationDestination(item: $selectedChallenge) { challenge in
                ChallengeWaitingRoomView(challenge: challenge)
            }
            .sheet(item: $editingChallenge) { challenge in
                NewChallengeView(editingChallenge: $editingChallenge) {
                    viewModel.fetchChallenges()
                    editingChallenge = nil
                }
            }
            .sheet(isPresented: $isPresentingNewChallenge) {
                NewChallengeView(editingChallenge: .constant(nil)) {
                    viewModel.fetchChallenges()
                    isPresentingNewChallenge = false
                }
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
            .onAppear {
                viewModel.fetchChallenges()
            }
            .alert(item: $showingComment) { comment in
                Alert(title: Text("Comment"), message: Text(comment.value), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: Binding<Bool>(
                get: { !showingParticipants.isEmpty },
                set: { newVal in if !newVal { showingParticipants = [] } }
            )) {
                NavigationView {
                    List {
                        ForEach(showingParticipants, id: \ .self) { participant in
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
                ForEach(viewModel.challenges, id: \ .id) { challenge in
                    challengeCard(for: challenge)
                }
            }
            .padding()
        }
    }

    private func challengeCard(for challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(challenge.challengeName)
                .foregroundColor(viewModel.isRegistered(challenge) ? .green : .white)
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
                Text(viewModel.truncatedComment(challenge.comment))
                    .foregroundColor(.white)
                    .italic()
                    .onTapGesture {
                        showingComment = IdentifiableString(value: challenge.comment)
                    }
            }

            HStack {
                if challenge.startTime > Date() {
                    Button(viewModel.isRegistered(challenge) ? "Unregister" : "Register") {
                        viewModel.toggleRegistration(for: challenge)
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
                if viewModel.canEnterWaitingRoom(for: challenge) {
                    Button("Enter Waiting Room") {
                        selectedChallenge = challenge
                    }
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
                        viewModel.deleteChallenge(challenge)
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
