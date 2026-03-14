import SwiftUI

struct NFCWriteView: View {
    @Environment(\.dismiss) private var dismiss

    let spool: SpoolmanSpool
    let onWrite: () async -> Bool

    @State private var writeState: WriteState = .ready
    @State private var writeTask: Task<Void, Never>?

    private enum WriteState {
        case ready
        case writing
        case success
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                spoolSummary

                Divider()

                statusArea

                Spacer()

                actionButtons
            }
            .padding()
            .navigationTitle("Write NFC Tag")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onDisappear { writeTask?.cancel() }
        }
    }

    // MARK: - Spool Summary

    private var spoolSummary: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: spool.colorHex ?? "#808080"))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(Color.pfBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(spool.filamentName ?? spool.name)
                    .font(.headline)
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

                if let remaining = spool.remainingWeightG {
                    Text("\(Int(remaining))g remaining")
                        .font(.caption)
                        .foregroundStyle(Color.pfTextTertiary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Status Area

    @ViewBuilder
    private var statusArea: some View {
        switch writeState {
        case .ready:
            VStack(spacing: 12) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.pfAccent)

                Text("Ready to write spool data to an NFC tag")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

        case .writing:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Hold iPhone near blank NFC tag…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pfTextPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

        case .success:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.pfSuccess)
                    .symbolEffect(.bounce, value: true)

                Text("NFC tag written successfully!")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pfTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.pfError)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch writeState {
        case .ready:
            Button {
                writeTask = Task { await performWrite() }
            } label: {
                Label("Write Tag", systemImage: "wave.3.right")
                    .fullWidthActionButton(prominence: .prominent)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.pfAccent)

        case .writing:
            EmptyView()

        case .success:
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.pfAccent)
                .fullWidthActionButton()

        case .error:
            HStack(spacing: 10) {
                Button {
                    writeTask = Task { await performWrite() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pfAccent)

                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func performWrite() async {
        writeState = .writing
        let success = await onWrite()
        if success {
            writeState = .success
        } else {
            writeState = .error("Failed to write NFC tag. Make sure the tag is blank and close enough.")
        }
    }
}
