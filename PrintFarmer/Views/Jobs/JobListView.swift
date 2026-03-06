import SwiftUI

struct JobListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel = JobListViewModel()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.jobsPath) {
            Group {
                if viewModel.isLoading && viewModel.queueOverview.isEmpty {
                    ProgressView("Loading queue…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.queueOverview.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No Printers in Queue",
                        message: "The queue is empty. Add jobs to see them here."
                    )
                } else {
                    queueList
                }
            }
            .navigationTitle("Job Queue")
            .refreshable {
                await viewModel.loadJobs()
            }
            .navigationDestination(for: AppDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .task {
            viewModel.configure(jobService: services.jobService)
            await viewModel.loadJobs()
        }
    }

    // MARK: - Queue List

    private var queueList: some View {
        List {
            if !viewModel.printersWithActiveJobs.isEmpty {
                Section("Active") {
                    ForEach(viewModel.printersWithActiveJobs) { overview in
                        QueueOverviewRow(overview: overview)
                            .onTapGesture {
                                if let jobId = overview.currentJobId {
                                    router.jobsPath.append(AppDestination.jobDetail(id: jobId))
                                }
                            }
                    }
                }
            }

            if !viewModel.printersWithQueuedJobs.isEmpty {
                Section("Queued") {
                    ForEach(viewModel.printersWithQueuedJobs) { overview in
                        QueueOverviewRow(overview: overview)
                    }
                }
            }

            if !viewModel.availablePrinters.isEmpty {
                Section("Available") {
                    ForEach(viewModel.availablePrinters) { overview in
                        QueueOverviewRow(overview: overview)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Queue Overview Row

private struct QueueOverviewRow: View {
    let overview: QueueOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(overview.printerName)
                    .font(.headline)
                Spacer()
                if overview.isAvailable {
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if let jobName = overview.currentJobName {
                Text(jobName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(overview.printerModel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                if overview.queuedJobsCount > 0 {
                    Text("\(overview.queuedJobsCount) queued")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
