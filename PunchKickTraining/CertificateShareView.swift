import SwiftUI

// Identifiable wrapper for UIImage
struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct CertificateShareView: View {
    let summary: TrainingSummary

    @State private var selfieImage: UIImage? = nil
    @State private var annotationText: String = ""
    @State private var showImagePicker = false
    @State private var selectedSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var shareImage: ShareImage? = nil
    @State private var showAnnotationPrompt = false
    @State private var annotationInputText = ""

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                // Certificate preview
                ZStack {
                    TrainingCertificateView(summary: summary)
                        .frame(width: 350, height: 500)
                        .background(Color.black)
                        .cornerRadius(16)

                    if let selfie = selfieImage {
                        Image(uiImage: selfie)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 4)
                            .offset(x: 110, y: -190)
                    }

                    if !annotationText.isEmpty {
                        Text(annotationText)
                            .font(.headline)
                            .foregroundColor(.yellow)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .offset(y: 210)
                    }
                }

                Divider().padding(.vertical, 12)

                // Toggle for camera / photo library
                Picker("Source", selection: $selectedSource) {
                    Text("Photo Library").tag(UIImagePickerController.SourceType.photoLibrary)
                    Text("Camera").tag(UIImagePickerController.SourceType.camera)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

                HStack {
                    Button("📸 Add Selfie") {
                        showImagePicker = true
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("🖊️ Add Annotation") {
                        annotationInputText = annotationText
                        showAnnotationPrompt = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                Button("📤 Share Certificate") {
                    shareCertificate()
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding()

                Button("Done") {
                    dismiss()
                }
                .padding(.bottom)
            }
            .padding()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: selectedSource, selectedImage: $selfieImage)
        }
        .sheet(item: $shareImage) { wrappedImage in
            ShareSheet(activityItems: [wrappedImage.image])
        }
        .alert("Enter Annotation", isPresented: $showAnnotationPrompt, actions: {
            TextField("Your note...", text: $annotationInputText)
            Button("OK") {
                annotationText = annotationInputText
            }
            Button("Cancel", role: .cancel) {}
        })
    }

    // MARK: - Certificate Rendering & Sharing

    func shareCertificate() {
        let renderer = ImageRenderer(content:
            ZStack {
                TrainingCertificateView(summary: summary)
                    .frame(width: 350, height: 500)
                    .background(Color.black)

                if let selfie = selfieImage {
                    Image(uiImage: selfie)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                        .offset(x: 110, y: -190)
                }

                if !annotationText.isEmpty {
                    Text(annotationText)
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .offset(y: 210)
                }
            }
        )

        if let image = renderer.uiImage {
            shareImage = ShareImage(image: image)
        }
    }
}
