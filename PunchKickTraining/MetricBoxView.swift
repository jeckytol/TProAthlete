import SwiftUI

struct MetricBoxView: View {
    var label: String
    var value: String
    var kpi: MetricKPI?

    init(label: String, value: String) {
        self.label = label
        self.value = value
        self.kpi = nil
    }

    init(kpi: MetricKPI) {
        self.label = kpi.label
        self.value = "\(kpi.value)"
        self.kpi = kpi
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }

            Spacer()

            if let kpi = kpi {
                Image(systemName: kpi.trendIcon)
                    .foregroundColor(kpi.trendColor)
                Text(kpi.trendText)
                    .foregroundColor(kpi.trendColor)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }
}
