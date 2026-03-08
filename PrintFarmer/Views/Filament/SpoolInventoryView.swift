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
                } else if viewModel.hasActiveSearch && viewModel.filteredSpools.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    VStack(spacing: 0) {
                        materialFilterChips
                        statusFilterChips
                        spoolList
                    }
                }
            }
            .navigationTitle("Spool Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.handleNFCScan()
                        } label: {
                            Image(systemName: "wave.3.right")
                        }
                        .accessibilityLabel("Scan NFC tag")

                        Button {
                            showAddSpool = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add spool")
                    }
                }
                #endif
            }
            .searchable(text: $viewModel.searchText, prompt: "Search by name, material, color…")
            .refreshable {
                await viewModel.loadSpools()
            }
            .overlay {
                if viewModel.isLoading && viewModel.spools.isEmpty {
                    ProgressView("Loading inventory…")
                }
                if viewModel.isScanning {
                    ProgressView("Scanning…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("Scan Error", isPresented: .constant(viewModel.scanError != nil)) {
                Button("OK") { viewModel.scanError = nil }
            } message: {
                if let error = viewModel.scanError {
                    Text(error)
                }
            }
            .sheet(isPresented: $showAddSpool) {
                AddSpoolView()
                    .onDisappear {
                        Task { await viewModel.loadSpools() }
                    }
            }
            .sheet(isPresented: $viewModel.showScannedDataSheet) {
                if let data = viewModel.scannedSpoolData {
                    AddSpoolView(scannedData: data)
                        .onDisappear {
                            Task { await viewModel.loadSpools() }
                        }
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
                #if canImport(UIKit)
                viewModel.configureNFC(scanner: services.nfcService)
                #endif
                await viewModel.loadSpools()
            }
        }
    }

    private var materialFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                Button {
                    withAnimation {
                        viewModel.selectedMaterial = nil
                    }
                } label: {
                    Text("All")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(viewModel.selectedMaterial == nil ? .white : Color.pfTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.selectedMaterial == nil ? Color.pfAccent : Color.pfBackgroundTertiary,
                            in: Capsule()
                        )
                }
                
                // Material chips
                ForEach(viewModel.availableMaterials, id: \.self) { material in
                    Button {
                        withAnimation {
                            if viewModel.selectedMaterial == material {
                                viewModel.selectedMaterial = nil
                            } else {
                                viewModel.selectedMaterial = material
                            }
                        }
                    } label: {
                        Text(material)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(viewModel.selectedMaterial == material ? .white : Color.pfTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedMaterial == material ? Color.pfAccent : Color.pfBackgroundTertiary,
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var statusFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                Button {
                    withAnimation {
                        viewModel.selectedStatus = nil
                    }
                } label: {
                    Text("All")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(viewModel.selectedStatus == nil ? .white : Color.pfTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.selectedStatus == nil ? Color.pfAccent : Color.pfBackgroundTertiary,
                            in: Capsule()
                        )
                }
                
                // Status chips
                ForEach(SpoolStatus.allCases, id: \.self) { status in
                    Button {
                        withAnimation {
                            if viewModel.selectedStatus == status {
                                viewModel.selectedStatus = nil
                            } else {
                                viewModel.selectedStatus = status
                            }
                        }
                    } label: {
                        Text(status.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(viewModel.selectedStatus == status ? .white : Color.pfTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedStatus == status ? Color.pfAccent : Color.pfBackgroundTertiary,
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var spoolList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.filteredSpools) { spool in
                    SpoolInventoryRowView(spool: spool)
                        .listRowBackground(
                            viewModel.highlightedSpoolId == spool.id
                                ? Color.pfAccent.opacity(0.15)
                                : nil
                        )
                        .id(spool.id)
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
            .onChange(of: viewModel.highlightedSpoolId) { _, newId in
                if let newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { viewModel.clearHighlight() }
                    }
                }
            }
        }
    }
}

// MARK: - Inventory Row

struct SpoolInventoryRowView: View {
    let spool: SpoolmanSpool
    
    private var weightPercent: Double? {
        guard let remaining = spool.remainingWeightG,
              let initial = spool.initialWeightG,
              initial > 0 else { return nil }
        return remaining / initial
    }
    
    private var weightColor: Color {
        guard let percent = weightPercent else { return .gray }
        if percent > 0.5 { return .green }
        if percent > 0.2 { return .yellow }
        return .red
    }

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
                HStack(spacing: 6) {
                    Text(spool.filamentName ?? spool.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.pfTextPrimary)
                    
                    if spool.inUse {
                        Image(systemName: "printer.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.pfAccent)
                    }
                }

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

            VStack(alignment: .trailing, spacing: 4) {
                if let remaining = spool.remainingWeightG {
                    Text("\(Int(remaining))g")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.pfTextPrimary)
                }
                if let initial = spool.initialWeightG, let remaining = spool.remainingWeightG, initial > 0 {
                    Text("\(Int(remaining))/\(Int(initial))g")
                        .font(.caption2)
                        .foregroundStyle(Color.pfTextTertiary)
                    
                    // Weight progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.pfBackgroundTertiary)
                            
                            Capsule()
                                .fill(weightColor)
                                .frame(width: geo.size.width * (weightPercent ?? 0))
                        }
                    }
                    .frame(width: 60, height: 4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
