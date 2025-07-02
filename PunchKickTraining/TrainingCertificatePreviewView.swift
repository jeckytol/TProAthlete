import SwiftUI

struct TrainingCertificatePreviewView: View {
    let summary: TrainingSummary
    @State private var showShareScreen = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                TrainingCertificateView(summary: summary)
                    .frame(maxWidth: 350, maxHeight: 500)
                    .cornerRadius(20)

                Button(action: {
                    showShareScreen = true
                }) {
                    Text("📤 Share your achievement")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.vertical, 10)
                        .frame(width: 280) // Matches certificate width with padding
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }

                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.blue)
                .padding(.bottom)
            }
            .padding(.top, 40)
        }
        .sheet(isPresented: $showShareScreen) {
            CertificateShareView(summary: summary)
        }
    }
}
