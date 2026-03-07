import SwiftUI

struct JobListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel = JobListViewModel()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.jobsPath) {
            Group {
                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    ProgressView("Loading jobs…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.jobs.isEmpty {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadJobs() }
                        }
                    }
                } else if !viewModel.hasAnyJobs {
                    EmptyStateView(
                        icon: "tray",
                        title: "No Print Jobs",
                        message: "No jobs in the queue. Jobs will appear here when queued."
                    )
                } else {
                    jobList
                }
            }
            .navigationTitle("Jobs")
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

    // MARK: - Job List

    private var jobList: some View {
        List {
            if !viewModel.activeJobs.isEmpty {
                Section {
                    ForEach(viewModel.activeJobs) { item in
                        activeJobRow(item)
                    }
                } header: {
                    Label("Printing", systemImage: "printer.fill")
                }
            }

            if !viewModel.queuedJobs.isEmpty {
                Section {
                    ForEach(viewModel.queuedJobs) { item in
                        queuedJobRow(item)
                    }
                } header: {
                    Label("In Queue", systemImage: "tray.full")
                }
            }

            if !viewModel.recentJobs.isEmpty {
                Section(isExpanded: $viewModel.showRecentJobs) {
                    ForEach(viewModel.recentJobs.prefix(10)) { item in
                        recentJobRow(item)
                    }
                } header: {
                    Label("Recent", systemImage: "clock")
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Active Job Row

    private func activeJobRow(_ item: QueuedPrintJobResponse) -> some View {
        Button {
            if let uuid = item.job.jobUUID {
                router.jobsPath.append(AppDestination.jobDetail(id: uuid))
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.job.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    StatusBadge(jobStatus: item.job.jobStatus)
                }

                if let printerName = item.job.printerName {
                    Label(printerName, systemImage: "printer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let startTime = item.job.actualStartTimeUtc,
                   let estSeconds = item.job.estimatedPrintTimeSeconds, estSeconds > 0 {
                    let elapsed = Date.now.timeIntervalSince(startTime)
                    let total = TimeInterval(estSeconds)
                    let progress = min(1.0, elapsed / total)
                    PrintProgressBar(progress: progress, height: 6, color: progressColor(for: item.job.jobStatus))

                    HStack {
                        if item.job.isMultiCopy {
                            Label("\(item.job.completedCopies)/\(item.job.copies)", systemImage: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        let remaining = max(0, total - elapsed)
                        Label("~\(remaining.durationFormatted) left", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Queued Job Row

    private func queuedJobRow(_ item: QueuedPrintJobResponse) -> some View {
        Button {
            if let uuid = item.job.jobUUID {
                router.jobsPath.append(AppDestination.jobDetail(id: uuid))
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.job.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    priorityIndicator(item.job.priority)
                }

                HStack(spacing: 12) {
                    if let printerName = item.job.printerName {
                        Label(printerName, systemImage: "printer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if item.job.isMultiCopy {
                        Label("\(item.job.copies) copies", systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let duration = item.job.estimatedDuration {
                        Label(duration.durationFormatted, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("#\(item.job.queuePosition) in queue")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(item.job.createdAtUtc.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Job Row

    private func recentJobRow(_ item: QueuedPrintJobResponse) -> some View {
        Button {
            if let uuid = item.job.jobUUID {
                router.jobsPath.append(AppDestination.jobDetail(id: uuid))
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.job.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    StatusBadge(jobStatus: item.job.jobStatus)
                }

                HStack {
                    if let printerName = item.job.printerName {
                        Text(printerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let endTime = item.job.actualEndTimeUtc {
                        Text(endTime.relativeFormatted)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let reason = item.job.failureReason, item.job.jobStatus == .failed {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(Color.pfError)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func progressColor(for status: PrintJobStatus?) -> Color {
        switch status {
        case .printing: .pfAccent
        case .paused: .pfWarning
        default: .pfAccent
        }
    }

    @ViewBuilder
    private func priorityIndicator(_ priority: Int) -> some View {
        if let p = PrintJobPriority.from(intValue: priority), p == .high || p == .urgent {
            HStack(spacing: 2) {
                Image(systemName: p == .urgent ? "exclamationmark.triangle.fill" : "flag.fill")
                    .font(.caption2)
                Text(p == .urgent ? "Urgent" : "High")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(p == .urgent ? Color.pfError : Color.pfWarning)
        }
    }
}
