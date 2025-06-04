import SwiftUI
import Firebase

struct NewChallengeView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("nickname") private var nickname: String = ""

    @State private var challengeName: String = ""
    @State private var challengeDate = Date()
    @State private var difficulty: Int = 0
    @State private var comment: String = ""

    var isSaveEnabled: Bool {
        !challengeName.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Challenge")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    Divider().background(Color.gray)
                }
                .padding(.top)

                ScrollView {
                    VStack(spacing: 20) {
                        // Challenge Name
                        TextField("< Enter Challenge Name >", text: $challengeName)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .italic()
                            .bold()
                            .cornerRadius(8)

                        // Challenge Date
                        DatePicker("Challenge Date & Time", selection: $challengeDate)
                            .colorScheme(.dark)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)

                        // Difficulty Row
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

                        // Comment
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
                    .padding()
                }

                // Save Button at Bottom
                Button(action: saveChallenge) {
                    Text("Save Challenge")
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
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    
    //-----
    
    
    private func saveChallenge() {
        let db = Firestore.firestore()
        let challengeID = UUID().uuidString

        let newChallenge = Challenge(
            id: challengeID,
            trainingName: challengeName,
            startTime: challengeDate,
            difficulty: difficulty,
            comment: comment,
            creatorNickname: nickname,
            registeredNicknames: []
        )

        let challengeData: [String: Any] = [
            "trainingName": newChallenge.trainingName,
            "startTime": Timestamp(date: newChallenge.startTime),
            "difficulty": newChallenge.difficulty,
            "comment": newChallenge.comment,
            "creatorNickname": newChallenge.creatorNickname,
            "registeredNicknames": []
        ]

        db.collection("challenges").document(challengeID).setData(challengeData) { error in
            if let error = error {
                print("❌ Error saving challenge: \(error)")
            } else {
                dismiss()
            }
        }
    }
    
    //-----
}
