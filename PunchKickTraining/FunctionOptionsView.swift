import SwiftUI
import AVKit

struct FunctionOptionsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var userProfileManager: UserProfileManager

    @State private var animateBoxes = false
    @State private var selectedTraining: SavedTraining? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Dopamineo Menu")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    GeometryReader { geo in
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            optionBox(
                                title: "Learning",
                                icon: "book.fill",
                                color: .orange,
                                height: geo.size.height * 0.22,
                                destination: LearningView()
                            )

                            optionBox(
                                title: "Trainings",
                                icon: "figure.strengthtraining.traditional",
                                color: .blue,
                                height: geo.size.height * 0.22,
                                destination:
                                    HomeScreen(selectedTraining: $selectedTraining)
                                        .environmentObject(bluetoothManager)
                                        .environmentObject(userProfileManager)
                            )

                            optionBox(
                                title: "Challenges",
                                icon: "flame.fill",
                                color: .red,
                                height: geo.size.height * 0.22,
                                destination:
                                    ChallengeHomeView()
                                        .environmentObject(bluetoothManager)
                                        .environmentObject(userProfileManager)
                            )

                            optionBox(
                                title: "Activity Dashboard",
                                icon: "chart.bar.fill",
                                color: .green,
                                height: geo.size.height * 0.22,
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

    // MARK: - Reusable Box
    private func optionBox<Destination: View>(
        title: String,
        icon: String,
        color: Color,
        height: CGFloat,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(color)

                Text(title)
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(20)
            .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
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
