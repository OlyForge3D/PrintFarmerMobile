import SwiftUI

struct PrinterListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ServiceContainer.self) private var services
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel = PrinterListViewModel()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.printersPath) {
            Group {
                if viewModel.isLoading && viewModel.printers.isEmpty {
                    ProgressView("Loading printers…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.printers.isEmpty {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadPrinters() }
                        }
                    }
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
                } else if sizeClass == .regular {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(viewModel.filteredPrinters) { printer in
                            NavigationLink(value: AppDestination.printerDetail(id: printer.id)) {
                                PrinterCardView(printer: printer)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                "\(printer.name), \(printer.state ?? "unknown") status"
                                + "\(printer.isOnline ? ", online" : ", offline")"
                            )
                        }
                    }
                } else {
                    ForEach(viewModel.filteredPrinters) { printer in
                        NavigationLink(value: AppDestination.printerDetail(id: printer.id)) {
                            PrinterCardView(printer: printer)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(printer.name), \(printer.state ?? "unknown") status\(printer.isOnline ? ", online" : ", offline")")
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
                .background(isSelected ? Color.pfAccent : Color.pfBorder.opacity(0.5), in: Capsule())
                .foregroundStyle(isSelected ? .white : Color.pfTextPrimary)
        }
        .buttonStyle(.plain)
    }
}
