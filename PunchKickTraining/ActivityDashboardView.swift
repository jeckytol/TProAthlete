import SwiftUI

struct ActivityDashboardView: View {
    @EnvironmentObject var profileManager: UserProfileManager
    @StateObject private var viewModel: ActivityDashboardViewModel

    init() {
        // Use a placeholder until the actual nickname is available in .onAppear
        _viewModel = StateObject(wrappedValue: ActivityDashboardViewModel(nickname: ""))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Filter Section (Pinned)
                ActivityDashboardFilterView(viewModel: viewModel)

                // Metrics Section
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Overview")
                            .font(.headline)
                            .foregroundColor(.white)


                        // Overview KPIs - 2x2 grid layout
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricBoxView(label: "Trainings", value: "\(viewModel.numberOfTrainings)")
                            MetricBoxView(label: "Challenges", value: "\(viewModel.numberOfChallenges)")
                            MetricBoxView(label: "Training Time", value: viewModel.totalTrainingTimeFormatted)
                            MetricBoxView(label: "Success Rate", value: "\(viewModel.successRate)%")
                        }

                        // Individual KPIs with trend indicators
                        Text("Performance")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(viewModel.individualKPIs, id: \.label) { kpi in
                            MetricBoxView(kpi: kpi)
                        }
                    }
                    .transition(.opacity.combined(with: .slide))
                    .animation(.easeInOut, value: viewModel.individualKPIs.count)
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
        }
    }
}
