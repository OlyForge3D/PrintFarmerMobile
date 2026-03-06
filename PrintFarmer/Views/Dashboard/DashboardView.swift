import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Overview")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    Text("Dashboard content will be implemented here.")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}
