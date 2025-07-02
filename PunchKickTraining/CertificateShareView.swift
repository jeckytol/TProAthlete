import SwiftUI

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
    @State private var showSourcePicker = false

    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero

    @State private var annotationOffset: CGSize = .zero
    @State private var lastAnnotationOffset: CGSize = .zero

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    TrainingCertificateView(summary: summary)
                        .frame(width: 350, height: 500)
                        .background(Color.black)
                        .cornerRadius(16)

                    if let selfie = selfieImage {
                        Image(uiImage: selfie)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 4)
                            .offset(imageOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        imageOffset = CGSize(
                                            width: lastImageOffset.width + value.translation.width,
                                            height: lastImageOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastImageOffset = imageOffset
                                    }
                            )
                    }

                    if !annotationText.isEmpty {
                        Text(annotationText)
                            .font(.headline)
                            .foregroundColor(.yellow)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .offset(annotationOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        annotationOffset = CGSize(
                                            width: lastAnnotationOffset.width + value.translation.width,
                                            height: lastAnnotationOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastAnnotationOffset = annotationOffset
                                    }
                            )
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: {
                        showSourcePicker = true
                    }) {
                        Label("Add Picture", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.blue)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))

                    Button(action: {
                        annotationInputText = annotationText
                        showAnnotationPrompt = true
                    }) {
                        Label("Annotation", systemImage: "pencil.tip")
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.blue)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
                }
                .padding(.horizontal)

                Button(action: {
                    shareCertificate()
                }) {
                    Label("Share your achievement", systemImage: "paperplane")
                        .frame(maxWidth: 300)
                }
                .padding()
                .background(Color.black)
                .foregroundColor(.blue)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 1))
                .cornerRadius(12)

                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.blue)
                .padding(.top)
            }
            .padding()
        }
        .confirmationDialog("Select Picture Source", isPresented: $showSourcePicker, titleVisibility: .visible) {
            Button("Camera") {
                selectedSource = .camera
                showImagePicker = true
            }
            Button("Photo Library") {
                selectedSource = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: selectedSource, selectedImage: $selfieImage)
        }
        .sheet(item: $shareImage) { wrappedImage in
            ShareSheet(activityItems: [wrappedImage.image])
        }
        .alert("Enter Annotation", isPresented: $showAnnotationPrompt) {
            TextField("Your note...", text: $annotationInputText)
            Button("OK") {
                annotationText = annotationInputText
            }
            Button("Cancel", role: .cancel) {}
        }
    }

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
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 4)
                        .offset(imageOffset)
                }

                if !annotationText.isEmpty {
                    Text(annotationText)
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .offset(annotationOffset)
                }
            }
        )

        if let image = renderer.uiImage {
            shareImage = ShareImage(image: image)
        }
    }
}
