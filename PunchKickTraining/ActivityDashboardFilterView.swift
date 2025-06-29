import SwiftUI

struct ActivityDashboardFilterView: View {
    @ObservedObject var viewModel: ActivityDashboardViewModel
    @FocusState private var isTimeFieldFocused: Bool

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Filter")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // Time Range Input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Period (in days):")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    HStack {
                        TextField("Days", value: $viewModel.timeRangeInDays, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .foregroundColor(.blue)
                            .focused($isTimeFieldFocused)
                            .padding(8)
                            .frame(width: 100)
                            .background(Color.black)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
                    }
                }

                // Training Name Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Training:")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Picker("Training", selection: $viewModel.selectedTrainingName) {
                        Text("All").tag("All")
                        ForEach(viewModel.trainingNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // Refresh Button
                Button(action: {
                    isTimeFieldFocused = false // dismiss keyboard
                    viewModel.loadDashboardData()
                }) {
                    Text("Calculate")
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1.5))
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(12)
        }
        .onTapGesture {
            isTimeFieldFocused = false
        }
    }
}
