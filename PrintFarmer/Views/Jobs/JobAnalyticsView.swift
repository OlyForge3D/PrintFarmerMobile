import SwiftUI

struct JobAnalyticsView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel = JobAnalyticsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.jobs.isEmpty && viewModel.stats == nil {
                ProgressView("Loading analytics…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.jobs.isEmpty {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task {
                            await viewModel.loadJobs()
                            await viewModel.loadStats()
                        }
                    }
                }
            } else {
                analyticsContent
            }
        }
        .navigationTitle("Job Analytics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            await viewModel.loadJobs()
            await viewModel.loadStats()
        }
        .task {
            viewModel.configure(jobAnalyticsService: services.jobAnalyticsService)
            await viewModel.loadStats()
            await viewModel.loadJobs()
        }
    }

    // MARK: - Content

    private var analyticsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Stats summary
                if let stats = viewModel.stats {
                    JobStatsCard(stats: stats)
                }

                // Filter bar
                filterBar

                // Model stats
                if !viewModel.modelStats.isEmpty {
                    modelStatsSection
                }
            }
            .padding()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filters")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All Statuses", isSelected: viewModel.selectedStatus == nil) {
                        viewModel.selectedStatus = nil
                        Task { await viewModel.applyFilters() }
                    }

                    ForEach(["queued", "printing", "completed", "failed", "cancelled"], id: \.self) { status in
                        filterChip(status.capitalized, isSelected: viewModel.selectedStatus == status) {
                            viewModel.selectedStatus = status
                            Task { await viewModel.applyFilters() }
                        }
                    }
                }
            }

            if viewModel.selectedModel != nil || viewModel.selectedMaterial != nil {
                Button {
                    viewModel.clearFilters()
                    Task { await viewModel.applyFilters() }
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                        .font(.caption)
                }
            }
        }
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.pfAccent : Color.pfBackgroundTertiary,
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Model Stats

    private var modelStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Printer Model")
                .font(.title2.bold())

            let columns = sizeClass == .regular
                ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())]

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.modelStats, id: \.modelName) { stat in
                    VStack(spacing: 6) {
                        Text(stat.modelName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)

                        Text("\(stat.totalQueued)")
                            .font(.title3.bold().monospacedDigit())

                        Text("jobs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.pfBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

}
