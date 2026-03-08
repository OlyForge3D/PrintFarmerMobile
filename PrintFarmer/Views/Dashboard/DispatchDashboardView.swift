import SwiftUI

struct DispatchDashboardView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel = DispatchViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.queueStatus == nil {
                ProgressView("Loading dispatch…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.queueStatus == nil {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task {
                            await viewModel.loadQueueStatus()
                            await viewModel.loadHistory()
                        }
                    }
                }
            } else {
                dispatchContent
            }
        }
        .navigationTitle("Dispatch")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            await viewModel.loadQueueStatus()
            await viewModel.loadHistory()
        }
        .task {
            viewModel.configure(dispatchService: services.dispatchService)
            await viewModel.loadQueueStatus()
            await viewModel.loadHistory()
        }
    }

    // MARK: - Content

    private var dispatchContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusCards
                historySection
            }
            .padding()
        }
    }

    // MARK: - Status Cards

    private var statusCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Queue Status")
                .font(.title2.bold())

            let columns = sizeClass == .regular
                ? Array(repeating: GridItem(.flexible()), count: 4)
                : Array(repeating: GridItem(.flexible()), count: 2)

            LazyVGrid(columns: columns, spacing: 12) {
                dispatchCard(
                    title: "Pending",
                    count: viewModel.pendingJobCount,
                    icon: "tray.full",
                    color: .pfSecondaryAccent
                )

                dispatchCard(
                    title: "Idle Printers",
                    count: viewModel.idlePrinterCount,
                    icon: "printer",
                    color: .pfSuccess
                )

                dispatchCard(
                    title: "Busy Printers",
                    count: viewModel.busyPrinterCount,
                    icon: "printer.fill",
                    color: .pfAccent
                )

                if let status = viewModel.queueStatus {
                    dispatchCard(
                        title: "Dispatched (24h)",
                        count: status.stats.dispatchesLast24Hours,
                        icon: "checkmark.circle",
                        color: .pfSuccess
                    )
                }
            }
        }
    }

    private func dispatchCard(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text("\(count)")
                .font(.title2.bold().monospacedDigit())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Dispatches")
                .font(.title2.bold())

            if viewModel.history.isEmpty {
                Text("No recent dispatch history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.history.prefix(20), id: \.id) { entry in
                    historyRow(entry)
                }
            }
        }
    }

    private func historyRow(_ entry: DispatchHistoryEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(Color.pfAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.jobName ?? "Job \(entry.printJobId.uuidString.prefix(8))")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let printer = entry.printerName {
                        Label(printer, systemImage: "printer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.action)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.createdAtUtc, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.pfBorder, lineWidth: 1)
        )
    }
}
