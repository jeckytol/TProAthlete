import SwiftUI
import AVKit

struct FunctionOptionsView: View {
    @Binding var selectedTraining: SavedTraining?
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var userProfileManager: UserProfileManager

    @State private var animateBoxes = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Dopamineo")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    GeometryReader { geo in
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                            optionBox(
                                title: "Learning",
                                imageName: "learning",
                                height: geo.size.height * 0.26,
                                destination: LearningView()
                            )

                            optionBox(
                                title: "Trainings",
                                imageName: "training",
                                height: geo.size.height * 0.26,
                                destination:
                                    HomeScreen(selectedTraining: $selectedTraining)
                                        .environmentObject(bluetoothManager)
                                        .environmentObject(userProfileManager)
                            )

                            optionBox(
                                title: "Challenges",
                                imageName: "challenge",
                                height: geo.size.height * 0.26,
                                destination:
                                    ChallengeHomeView()
                                        .environmentObject(bluetoothManager)
                                        .environmentObject(userProfileManager)
                            )

                            optionBox(
                                title: "Activity Dashboard",
                                imageName: "activity",
                                height: geo.size.height * 0.26,
                                destination: ActivityDashboardView()
                            )
                        }
                        .padding(.horizontal)
                        .scaleEffect(animateBoxes ? 1.0 : 0.6)
                        .opacity(animateBoxes ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateBoxes)
                    }

                    Spacer()
                }
            }
            .onAppear {
                animateBoxes = true
            }
        }
    }

    // MARK: - Reusable Box with Enlarged Image
    private func optionBox<Destination: View>(
        title: String,
        imageName: String,
        height: CGFloat,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 16) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height * 0.6)
                    .padding(.top, 10)

                Text(title)
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(24)
            .shadow(color: .white.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Placeholder Views

struct LearningView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Learning Materials Coming Soon")
                .foregroundColor(.white)
        }
        .navigationTitle("Learning")
    }
}

struct ActivityDashboardView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Activity Dashboard Coming Soon")
                .foregroundColor(.white)
        }
        .navigationTitle("Dashboard")
    }
}
