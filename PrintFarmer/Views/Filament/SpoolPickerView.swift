import SwiftUI

struct SpoolPickerView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SpoolPickerViewModel()

    let onSelect: (SpoolmanSpool) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.errorMessage, viewModel.spools.isEmpty {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadSpools() }
                        }
                    }
                } else if viewModel.spools.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Spools", systemImage: "cylinder")
                    } description: {
                        Text("No spools available. Add spools in the Inventory tab.")
                    }
                } else {
                    spoolList
                }
            }
            .navigationTitle("Select Spool")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Filter by material, vendor…")
            .refreshable {
                await viewModel.loadSpools()
            }
            .overlay {
                if viewModel.isLoading && viewModel.spools.isEmpty {
                    ProgressView("Loading spools…")
                }
            }
            .task {
                viewModel.configure(spoolService: services.spoolService)
                await viewModel.loadSpools()
            }
        }
    }

    private var spoolList: some View {
        List(viewModel.filteredSpools) { spool in
            Button {
                onSelect(spool)
                dismiss()
            } label: {
                SpoolRowView(spool: spool)
            }
            .tint(Color.pfTextPrimary)
        }
    }
}

// MARK: - Spool Row

struct SpoolRowView: View {
    let spool: SpoolmanSpool

    var body: some View {
        HStack(spacing: 12) {
            // Color swatch
            Circle()
                .fill(Color(hex: spool.colorHex ?? "#808080"))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(Color.pfBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(spool.filamentName ?? spool.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pfTextPrimary)

                HStack(spacing: 6) {
                    Text(spool.material)
                        .font(.caption)
                        .foregroundStyle(Color.pfTextSecondary)

                    if let vendor = spool.vendor {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(Color.pfTextTertiary)
                        Text(vendor)
                            .font(.caption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
            }

            Spacer()

            if let remaining = spool.remainingWeightG {
                Text("\(Int(remaining))g")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.pfTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
