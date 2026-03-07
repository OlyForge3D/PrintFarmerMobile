import SwiftUI

struct SpoolInventoryView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel = SpoolInventoryViewModel()
    @State private var showAddSpool = false
    @State private var nfcWriteSpool: SpoolmanSpool?

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
                        Text("Add your filament spools to track inventory and assign them to printers.")
                    } actions: {
                        Button("Add Spool") {
                            showAddSpool = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pfAccent)
                    }
                } else {
                    spoolList
                }
            }
            .navigationTitle("Spool Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSpool = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add spool")
                }
                #endif
            }
            .searchable(text: $viewModel.searchText, prompt: "Search spools…")
            .refreshable {
                await viewModel.loadSpools()
            }
            .overlay {
                if viewModel.isLoading && viewModel.spools.isEmpty {
                    ProgressView("Loading inventory…")
                }
            }
            .sheet(isPresented: $showAddSpool) {
                AddSpoolView()
                    .onDisappear {
                        Task { await viewModel.loadSpools() }
                    }
            }
            .sheet(item: $nfcWriteSpool) { spool in
                NFCWriteView(spool: spool) {
                    // Placeholder: Lambert's NFCService.writeTag() will be called here
                    // For now, return false since the service isn't wired yet
                    return false
                }
            }
            .task {
                viewModel.configure(spoolService: services.spoolService)
                await viewModel.loadSpools()
            }
        }
    }

    private var spoolList: some View {
        List {
            ForEach(viewModel.filteredSpools) { spool in
                SpoolInventoryRowView(spool: spool)
                    .contextMenu {
                        Button {
                            nfcWriteSpool = spool
                        } label: {
                            Label("Write NFC Tag", systemImage: "wave.3.right")
                        }
                    }
            }
            .onDelete { indexSet in
                let spoolsToDelete = indexSet.map { viewModel.filteredSpools[$0] }
                for spool in spoolsToDelete {
                    Task { await viewModel.deleteSpool(spool) }
                }
            }
        }
    }
}

// MARK: - Inventory Row

struct SpoolInventoryRowView: View {
    let spool: SpoolmanSpool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: spool.colorHex ?? "#808080"))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(Color.pfBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(spool.filamentName ?? spool.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pfTextPrimary)

                HStack(spacing: 6) {
                    Text(spool.material)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pfBackgroundTertiary, in: Capsule())

                    if let vendor = spool.vendor {
                        Text(vendor)
                            .font(.caption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let remaining = spool.remainingWeightG {
                    Text("\(Int(remaining))g")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.pfTextPrimary)
                }
                if let initial = spool.initialWeightG, let remaining = spool.remainingWeightG, initial > 0 {
                    Text("\(Int(remaining))/\(Int(initial))g")
                        .font(.caption2)
                        .foregroundStyle(Color.pfTextTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
