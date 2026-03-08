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
                } else if viewModel.hasActiveSearch && viewModel.filteredSpools.isEmpty {
                    VStack(spacing: 0) {
                        materialFilterChips
                        statusFilterChips
                        Spacer()
                        ContentUnavailableView {
                            Label("No Matching Spools", systemImage: "line.3.horizontal.decrease.circle")
                        } description: {
                            Text(viewModel.activeFilterDescription)
                        } actions: {
                            Button("Clear Filters") {
                                withAnimation {
                                    viewModel.clearFilters()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.pfAccent)
                        }
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        materialFilterChips
                        statusFilterChips
                        spoolList
                    }
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
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.isQRScannerPresented = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                        }
                        .accessibilityLabel("Scan QR code")

                        Button {
                            viewModel.handleNFCScan()
                        } label: {
                            Image(systemName: "wave.3.right")
                        }
                        .accessibilityLabel("Scan NFC tag")
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
                    ProgressView("Loading spools…")
                }
                if viewModel.isScanning {
                    ProgressView("Looking up spool…")
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
            #if os(iOS)
            .sheet(isPresented: $viewModel.isQRScannerPresented) {
                QRScannerView(
                    onScan: { qrText in
                        viewModel.handleQRScan(qrText: qrText)
                    },
                    onCancel: {
                        viewModel.isQRScannerPresented = false
                    }
                )
            }
            #endif
            .sheet(isPresented: $viewModel.showScannedDataSheet) {
                if let data = viewModel.scannedSpoolData {
                    AddSpoolView(scannedData: data)
                        .onDisappear {
                            Task { await viewModel.loadSpools() }
                        }
                }
            }
            .task {
                viewModel.configure(spoolService: services.spoolService)
                #if canImport(UIKit)
                viewModel.configureNFCScanner(services.nfcService)
                #endif
                viewModel.onAutoSelect = { spool in
                    onSelect(spool)
                    dismiss()
                }
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
            // Color swatch
            Circle()
                .fill(Color(hex: spool.colorHex ?? "#808080"))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(Color.pfBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
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

            VStack(alignment: .trailing, spacing: 4) {
                if let remaining = spool.remainingWeightG {
                    Text("\(Int(remaining))g")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.pfTextSecondary)
                }

                if let initial = spool.initialWeightG, let remaining = spool.remainingWeightG, initial > 0 {
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
                    .frame(width: 50, height: 3)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
