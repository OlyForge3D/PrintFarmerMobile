#if canImport(UIKit)
import Foundation
@preconcurrency import CoreNFC

// MARK: - NFC Service

/// Reads and writes NFC tags for spool identification.
/// Supports OpenSpool and OpenPrintTag NDEF formats.
final class NFCService: SpoolScannerProtocol, @unchecked Sendable {

    // MARK: - SpoolScannerProtocol

    var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    func scan() async -> SpoolScanResult {
        guard isAvailable else {
            return .error(.notSupported)
        }

        return await withCheckedContinuation { continuation in
            let delegate = NFCReadDelegate(continuation: continuation)
            let session = NFCNDEFReaderSession(delegate: delegate, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = "Hold your iPhone near a filament spool tag."
            // Keep delegate alive for session duration
            objc_setAssociatedObject(session, &NFCReadDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            session.begin()
        }
    }

    // MARK: - Tag Writing

    /// Writes OpenSpool-format NDEF data to an NFC tag from spool data.
    func writeTag(spool: SpoolmanSpool) async throws {
        guard isAvailable else {
            throw SpoolScanError.notSupported
        }

        guard let payload = NFCTagParser.createOpenSpoolPayload(from: spool) else {
            throw SpoolScanError.invalidPayload("Could not create tag payload from spool data.")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = NFCWriteDelegate(payload: payload, continuation: continuation)
            let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: delegate, queue: nil)
            session?.alertMessage = "Hold your iPhone near the NFC tag to write spool data."
            objc_setAssociatedObject(session as Any, &NFCWriteDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            session?.begin()
        }
    }
}

// MARK: - NFC Read Delegate

private final class NFCReadDelegate: NSObject, NFCNDEFReaderSessionDelegate, @unchecked Sendable {
    nonisolated(unsafe) static var associatedKey: UInt8 = 0
    private var continuation: CheckedContinuation<SpoolScanResult, Never>?

    init(continuation: CheckedContinuation<SpoolScanResult, Never>) {
        self.continuation = continuation
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as NSError
        // Code 200 = user cancelled
        if nfcError.domain == "NFCError" && nfcError.code == 200 {
            resume(with: .cancelled)
        } else {
            resume(with: .error(.invalidPayload(error.localizedDescription)))
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            if let result = parseMessage(message) {
                resume(with: result)
                return
            }
        }
        resume(with: .error(.invalidPayload("No recognized spool data on tag.")))
    }

    private func parseMessage(_ message: NFCNDEFMessage) -> SpoolScanResult? {
        for record in message.records {
            let typeString = String(data: record.type, encoding: .utf8) ?? ""

            if typeString == "application/openspool" {
                if let data = parsePayloadData(record),
                   let spoolData = NFCTagParser.parseOpenSpool(data) {
                    if let spoolId = spoolData.spoolmanId {
                        return .spoolId(spoolId)
                    }
                    return .newSpoolData(spoolData)
                }
            }

            if typeString == "application/openprinttag" {
                if let data = parsePayloadData(record),
                   let spoolData = NFCTagParser.parseOpenPrintTag(data) {
                    if let spoolId = spoolData.spoolmanId {
                        return .spoolId(spoolId)
                    }
                    return .newSpoolData(spoolData)
                }
            }

            // Fallback: try plain text as QR code format
            if record.typeNameFormat == .nfcWellKnown,
               let text = record.wellKnownTypeTextPayload().0,
               let spoolId = QRCodeParser.parse(text) {
                return .spoolId(spoolId)
            }
        }
        return nil
    }

    private func parsePayloadData(_ record: NFCNDEFPayload) -> Data? {
        // Media-type records store the payload directly
        if record.typeNameFormat == .media {
            return record.payload
        }
        // For other formats, the first byte may be a status byte (text records)
        if record.payload.count > 1 {
            return record.payload.advanced(by: 1)
        }
        return record.payload.isEmpty ? nil : record.payload
    }

    private func resume(with result: SpoolScanResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

// MARK: - NFC Write Delegate

private final class NFCWriteDelegate: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
    nonisolated(unsafe) static var associatedKey: UInt8 = 0
    private let payload: Data
    private var continuation: CheckedContinuation<Void, Error>?

    init(payload: Data, continuation: CheckedContinuation<Void, Error>) {
        self.payload = payload
        self.continuation = continuation
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as NSError
        if nfcError.domain == "NFCError" && nfcError.code == 200 {
            resume(throwing: SpoolScanError.cancelled)
        } else {
            resume(throwing: SpoolScanError.invalidPayload(error.localizedDescription))
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag detected.")
            resume(throwing: SpoolScanError.invalidPayload("No tag detected."))
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: "Connection failed.")
                self.resume(throwing: SpoolScanError.invalidPayload(error.localizedDescription))
                return
            }

            var ndefTag: NFCNDEFTag?
            switch tag {
            case .iso7816(let t): ndefTag = t
            case .miFare(let t): ndefTag = t
            case .iso15693(let t): ndefTag = t
            case .feliCa(let t): ndefTag = t
            @unknown default: break
            }

            guard let ndef = ndefTag else {
                session.invalidate(errorMessage: "Tag does not support NDEF.")
                self.resume(throwing: SpoolScanError.invalidPayload("Tag does not support NDEF."))
                return
            }

            // Create OpenSpool NDEF record
            let typeData = Data("application/openspool".utf8)
            let ndefPayload = NFCNDEFPayload(
                format: .media,
                type: typeData,
                identifier: Data(),
                payload: self.payload
            )
            let ndefMessage = NFCNDEFMessage(records: [ndefPayload])

            ndef.writeNDEF(ndefMessage) { writeError in
                if let writeError {
                    session.invalidate(errorMessage: "Write failed.")
                    self.resume(throwing: SpoolScanError.invalidPayload(writeError.localizedDescription))
                } else {
                    session.alertMessage = "Spool data written successfully!"
                    session.invalidate()
                    self.resume(returning: ())
                }
            }
        }
    }

    private func resume(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private func resume(returning value: Void) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
#endif
