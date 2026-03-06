import SwiftUI

struct JobListView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Job queue will be implemented here.")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Job Queue")
        }
    }
}
