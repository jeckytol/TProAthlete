
import SwiftUI

struct TrainingCertificatePreviewView: View {
    let summary: TrainingSummary
    @State private var showShareScreen = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                TrainingCertificateView(summary: summary)
                    .frame(maxWidth: 350, maxHeight: 500)
                    .background(Color.black)
                    .cornerRadius(16)

                Button("📤 Share Certificate") {
                    showShareScreen = true
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)

                Button("Done") {
                    dismiss()
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showShareScreen) {
            CertificateShareView(summary: summary)
        }
    }
}
