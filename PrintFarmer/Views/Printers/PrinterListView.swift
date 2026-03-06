import SwiftUI

struct PrinterListView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Printer list will be implemented here.")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Printers")
        }
    }
}
