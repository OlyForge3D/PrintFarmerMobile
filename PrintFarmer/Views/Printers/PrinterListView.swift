import SwiftUI

struct PrinterListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel = PrinterListViewModel()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.printersPath) {
            Group {
                if viewModel.isLoading && viewModel.printers.isEmpty {
                    ProgressView("Loading printers…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.printers.isEmpty {
                    EmptyStateView(
                        icon: "printer",
                        title: "No Printers",
                        message: "No printers are registered yet."
                    )
                } else {
                    printerList
                }
            }
            .navigationTitle("Printers")
            .searchable(text: $viewModel.searchText, prompt: "Search printers")
            .refreshable {
                await viewModel.loadPrinters()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    statusFilterMenu
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .task {
            viewModel.configure(printerService: services.printerService)
            await viewModel.loadPrinters()
        }
    }

    // MARK: - Printer List

    private var printerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Location filter pills
                if viewModel.availableLocations.count > 1 {
                    locationFilterBar
                }

                if viewModel.filteredPrinters.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .padding(.top, 40)
                } else {
                    ForEach(viewModel.filteredPrinters) { printer in
                        NavigationLink(value: AppDestination.printerDetail(id: printer.id)) {
                            PrinterCardView(printer: printer)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Filters

    private var statusFilterMenu: some View {
        Menu {
            ForEach(PrinterListViewModel.StatusFilter.allCases) { filter in
                Button {
                    viewModel.selectedStatus = filter
                } label: {
                    if viewModel.selectedStatus == filter {
                        Label(filter.rawValue, systemImage: "checkmark")
                    } else {
                        Text(filter.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .symbolVariant(viewModel.selectedStatus != .all ? .fill : .none)
        }
    }

    private var locationFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All Locations", isSelected: viewModel.selectedLocationId == nil) {
                    viewModel.selectedLocationId = nil
                }

                ForEach(viewModel.availableLocations, id: \.id) { location in
                    FilterChip(
                        title: location.name,
                        isSelected: viewModel.selectedLocationId == location.id
                    ) {
                        viewModel.selectedLocationId = location.id
                    }
                }
            }
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
