import SwiftUI

struct NewChallengeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var challengeName: String = ""
    @State private var challengeDate = Date()
    @State private var difficulty: Int = 0
    @State private var comment: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("New Challenge")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top)

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

                    // Difficulty Stars
                    VStack(alignment: .leading) {
                        Text("Difficulty")
                            .foregroundColor(.white)
                            .font(.headline)
                        HStack {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= difficulty ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.title2)
                                    .onTapGesture {
                                        difficulty = index
                                    }
                            }
                        }
                    }

                    //----------------------------
                    // Comment Box
                    
                    VStack(alignment: .leading) {
                        Text("Comment")
                            .foregroundColor(.white)
                            .font(.headline)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))

                            CustomTextEditor(text: $comment)
                                .frame(height: 120)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }

                    //-----
                    Button(action: {
                        // Handle save logic
                        dismiss()
                    }) {
                        Text("Save Challenge")
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
