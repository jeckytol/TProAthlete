import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

// MARK: - KPI Struct
struct MetricKPI: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: Int
    let previousValue: Int

    var trend: Double {
        guard previousValue > 0 else { return 0 }
        return (Double(value - previousValue) / Double(previousValue)) * 100
    }

    var trendText: String {
        guard previousValue > 0 else { return "--" }
        let formatted = String(format: "%.0f%%", abs(trend))
        return trend >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    var trendIcon: String {
        trend >= 0 ? "arrow.up" : "arrow.down"
    }

    var trendColor: Color {
        trend >= 0 ? .green : .red
    }
}

class ActivityDashboardViewModel: ObservableObject {
    // MARK: - Filter Inputs
    @Published var timeRangeInDays: Int = 7
    @Published var selectedTrainingName: String = "All"
    @Published var trainingNames: [String] = []
    @Published var isLoading: Bool = false
    @Published var individualKPIs: [MetricKPI] = []

    // MARK: - Dashboard Outputs
    @Published var numberOfTrainings: Int = 0
    @Published var numberOfChallenges: Int = 0
    @Published var totalTrainingTimeFormatted: String = "0s"
    @Published var successRate: Int = 0

    private let db = Firestore.firestore()
    @Published var nickname: String = ""

    init(nickname: String) {
        self.nickname = nickname
    }

    func loadDashboardData() {
        isLoading = true

        let now = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -timeRangeInDays, to: now),
              let priorStart = Calendar.current.date(byAdding: .day, value: -2 * timeRangeInDays, to: now),
              let priorEnd = Calendar.current.date(byAdding: .day, value: -timeRangeInDays, to: now) else {
            isLoading = false
            return
        }

        let group = DispatchGroup()
        var summaries: [TrainingSummary] = []
        var progressEntries: [ChallengeProgress] = []
        var priorSummaries: [TrainingSummary] = []

        // Current Period: Summaries
        group.enter()
        db.collection("training_summaries")
            .whereField("nickname", isEqualTo: nickname)
            .whereField("date", isGreaterThan: startDate)
            .whereField("date", isLessThan: now)
            .getDocuments { snapshot, _ in
                summaries = snapshot?.documents.compactMap { try? $0.data(as: TrainingSummary.self) } ?? []
                group.leave()
            }

        // Challenge Progress
        group.enter()
        db.collection("challenge_progress")
            .whereField("nickname", isEqualTo: nickname)
            .whereField("updatedAt", isGreaterThan: startDate)
            .whereField("updatedAt", isLessThan: now)
            .getDocuments { snapshot, _ in
                progressEntries = snapshot?.documents.compactMap { try? $0.data(as: ChallengeProgress.self) } ?? []
                group.leave()
            }

        // Prior Period: for trends
        group.enter()
        db.collection("training_summaries")
            .whereField("nickname", isEqualTo: nickname)
            .whereField("date", isGreaterThan: priorStart)
            .whereField("date", isLessThan: priorEnd)
            .getDocuments { snapshot, _ in
                priorSummaries = snapshot?.documents.compactMap { try? $0.data(as: TrainingSummary.self) } ?? []
                group.leave()
            }

        // Load Training Names
        loadTrainingNames()

        // Finalize
        group.notify(queue: .main) {
            self.isLoading = false

            let filteredCurrent = self.selectedTrainingName == "All"
                ? summaries
                : summaries.filter { $0.trainingName == self.selectedTrainingName }

            self.numberOfTrainings = filteredCurrent.count
            self.numberOfChallenges = progressEntries.count

            let totalSeconds = filteredCurrent.map(\.elapsedTime).reduce(0, +)
            self.totalTrainingTimeFormatted = self.formatTime(totalSeconds)

            let completed = filteredCurrent.filter { $0.trainingGoalCompletionPercentage == 100 }
            self.successRate = filteredCurrent.isEmpty ? 0 : Int((Double(completed.count) / Double(filteredCurrent.count)) * 100)

            func totals(from list: [TrainingSummary]) -> (points: Int, force: Int, strikes: Int) {
                var totalPoints = 0
                var totalForce = 0
                var totalStrikes = 0

                for s in list {
                    totalPoints += Int(s.totalPoints ?? 0)
                    totalForce += Int(s.totalForce)
                    totalStrikes += s.strikeCount
                }

                return (totalPoints, totalForce, totalStrikes)
            }

            let current = totals(from: filteredCurrent)
            let previous = totals(from: priorSummaries)

            self.individualKPIs = [
                MetricKPI(label: "Total Points", value: current.points, previousValue: previous.points),
                MetricKPI(label: "Total Force", value: current.force, previousValue: previous.force),
                MetricKPI(label: "Total Strikes", value: current.strikes, previousValue: previous.strikes)
            ]
        }
    }

    func loadTrainingNames() {
        db.collection("training_summaries")
            .whereField("nickname", isEqualTo: nickname)
            .getDocuments { snapshot, _ in
                let names = snapshot?.documents.compactMap {
                    $0.data()["trainingName"] as? String
                } ?? []
                DispatchQueue.main.async {
                    self.trainingNames = Array(Set(names)).sorted()
                }
            }
    }

    private func formatTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m \(secs)s"
        } else if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
