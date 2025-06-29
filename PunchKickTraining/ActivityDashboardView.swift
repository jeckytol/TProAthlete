import SwiftUI

struct ActivityDashboardView: View {
    @EnvironmentObject var profileManager: UserProfileManager
    @StateObject private var viewModel: ActivityDashboardViewModel

    @State private var animateOverview = false
    @State private var animatePerformance = false

    init() {
        _viewModel = StateObject(wrappedValue: ActivityDashboardViewModel(nickname: ""))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Filter Section
                ActivityDashboardFilterView(viewModel: viewModel)

                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Overview")
                            .font(.headline)
                            .foregroundColor(.white)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            IconMetricBoxView(
                                label: "Trainings",
                                value: "\(viewModel.numberOfTrainings)",
                                systemImage: "figure.strengthtraining.traditional"
                            )
                            .scaleEffect(animateOverview ? 1.0 : 0.8)
                            .opacity(animateOverview ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: animateOverview)

                            IconMetricBoxView(
                                label: "Challenges",
                                value: "\(viewModel.numberOfChallenges)",
                                systemImage: "flag.checkered"
                            )
                            .scaleEffect(animateOverview ? 1.0 : 0.8)
                            .opacity(animateOverview ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: animateOverview)

                            IconMetricBoxView(
                                label: "Training Time",
                                value: viewModel.totalTrainingTimeFormatted,
                                systemImage: "timer"
                            )
                            .scaleEffect(animateOverview ? 1.0 : 0.8)
                            .opacity(animateOverview ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.3), value: animateOverview)

                            IconMetricBoxView(
                                label: "Success Rate",
                                value: "\(viewModel.successRate)%",
                                systemImage: "checkmark.seal"
                            )
                            .scaleEffect(animateOverview ? 1.0 : 0.8)
                            .opacity(animateOverview ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.4), value: animateOverview)
                        }

                        Text("Performance")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 10)

                        ForEach(viewModel.individualKPIs.indices, id: \.self) { index in
                            let kpi = viewModel.individualKPIs[index]
                            MetricBoxView(kpi: kpi)
                                .scaleEffect(animatePerformance ? 1.0 : 0.8)
                                .opacity(animatePerformance ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.2 + Double(index) * 0.1), value: animatePerformance)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if viewModel.nickname.isEmpty && profileManager.storedNickname != "Unknown" {
                viewModel.nickname = profileManager.storedNickname
                viewModel.loadDashboardData()
            }

            // Trigger initial animation
            withAnimation {
                animateOverview = true
                animatePerformance = true
            }
        }
        .onChange(of: viewModel.individualKPIs) { _ in
            // Re-trigger animation on refresh
            animateOverview = false
            animatePerformance = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    animateOverview = true
                    animatePerformance = true
                }
            }
        }
    }
}

// MARK: - IconMetricBoxView
struct IconMetricBoxView: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
                Spacer()
            }
            HStack {
                Text(value)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                Spacer()
            }
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }
}
