import SwiftUI

struct JobDetailView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: JobDetailViewModel

    init(jobId: UUID) {
        _viewModel = State(initialValue: JobDetailViewModel(jobId: jobId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.job == nil {
                ProgressView("Loading job…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.job == nil {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadJob() }
                    }
                }
            } else if let job = viewModel.job {
                jobContent(job)
            }
        }
        .navigationTitle(viewModel.job?.name ?? "Job")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            await viewModel.loadJob()
        }
        .alert("Cancel Job?", isPresented: $viewModel.showCancelConfirmation) {
            Button("Keep", role: .cancel) {}
            Button("Cancel Job", role: .destructive) {
                Task { await viewModel.cancelJob() }
            }
        } message: {
            Text("This will cancel the print job. This action cannot be undone.")
        }
        .alert("Action Failed", isPresented: .constant(viewModel.actionError != nil)) {
            Button("OK") { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError {
                Text(error)
            }
        }
        .task {
            viewModel.configure(jobService: services.jobService)
            await viewModel.loadJob()
        }
    }

    // MARK: - Content

    private func jobContent(_ job: PrintJob) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status + Progress
                statusSection(job)

                // Info
                infoSection(job)

                // Timestamps
                timestampsSection(job)

                // Actions
                actionSection(job)
            }
            .padding()
        }
    }

    // MARK: - Status

    private func statusSection(_ job: PrintJob) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusBadge(jobStatus: job.status)
                Spacer()
                if job.isMultiCopy {
                    Label("\(job.completedCopies) / \(job.copies) copies", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isActive {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress")
                        .font(.headline)

                    if let eta = job.estimatedPrintTime?.timeSpanSeconds, let started = job.actualStartTime {
                        let elapsed = Date.now.timeIntervalSince(started)
                        let remaining = max(0, eta - elapsed)
                        let progress = eta > 0 ? min(1.0, elapsed / eta) : 0
                        PrintProgressBar(progress: progress, height: 12, color: progressColor(for: job))

                        if remaining > 0 {
                            HStack {
                                Spacer()
                                Label("~\(remaining.durationFormatted) remaining", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.pfBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Info

    private func infoSection(_ job: PrintJob) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 0) {
                infoRow(label: "File", value: job.gcodeFileName, icon: "doc")

                if let printerName = job.assignedPrinterName {
                    Divider()
                    if let printerId = job.assignedPrinterId {
                        NavigationLink(value: AppDestination.printerDetail(id: printerId)) {
                            infoRow(label: "Printer", value: printerName, icon: "printer")
                                .foregroundStyle(.primary)
                        }
                    } else {
                        infoRow(label: "Printer", value: printerName, icon: "printer")
                    }
                }

                if let priority = PrintJobPriority.from(intValue: job.priority) {
                    Divider()
                    infoRow(label: "Priority", value: priorityLabel(priority), icon: "flag")
                }

                if let filament = job.filamentName {
                    Divider()
                    infoRow(label: "Filament", value: filament, icon: "circle.fill")
                }

                if let eta = job.estimatedPrintTime {
                    Divider()
                    infoRow(label: "Est. Time", value: eta.timeSpanFormatted, icon: "clock")
                }

            }
            .padding()
            .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.pfBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Timestamps

    private func timestampsSection(_ job: PrintJob) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)

            VStack(spacing: 0) {
                infoRow(label: "Created", value: job.createdAt.formatted(date: .abbreviated, time: .shortened), icon: "calendar")

                if let started = job.actualStartTime {
                    Divider()
                    infoRow(label: "Started", value: started.formatted(date: .abbreviated, time: .shortened), icon: "play.circle")
                }

                if let completed = job.actualEndTime {
                    Divider()
                    infoRow(label: "Completed", value: completed.formatted(date: .abbreviated, time: .shortened), icon: "checkmark.circle")
                }

                if let actual = job.actualPrintTime {
                    Divider()
                    infoRow(label: "Print Time", value: actual.timeSpanFormatted, icon: "timer")
                }
            }
            .padding()
            .background(Color.pfCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.pfBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func actionSection(_ job: PrintJob) -> some View {
        VStack(spacing: 10) {
            if viewModel.canDispatch {
                Button {
                    Task { await viewModel.dispatchJob() }
                } label: {
                    Label("Dispatch to Printer", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.canCancel {
                Button(role: .destructive) {
                    viewModel.showCancelConfirmation = true
                } label: {
                    Label("Cancel Job", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if viewModel.canAbort {
                Button(role: .destructive) {
                    Task { await viewModel.abortJob() }
                } label: {
                    Label("Abort Print", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pfError)
            }
        }
        .disabled(viewModel.isPerformingAction)
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Spacer()

            Text(value)
                .font(.subheadline)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
    }

    private func progressColor(for job: PrintJob) -> Color {
        switch job.status {
        case .printing: .pfAccent
        case .paused: .pfWarning
        case .failed: .pfError
        default: .pfAccent
        }
    }

    private func priorityLabel(_ priority: PrintJobPriority) -> String {
        switch priority {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }
}
