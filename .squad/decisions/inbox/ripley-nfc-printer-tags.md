# Decision: NFC Printer Tag Write Delegate Architecture

**Date:** 2026-03-08
**Author:** Ripley (iOS Developer)
**Status:** Implemented

## Context
The existing NFCWriteDelegate takes raw `Data` bytes and wraps them in an OpenSpool media-type NDEF record. Printer tags need a URI record (`printfarmer://printer/{UUID}`) plus a text record with the printer name.

## Decision
Created a separate `NFCMessageWriteDelegate` that accepts a full `NFCNDEFMessage` rather than refactoring the existing delegate. The `writePrinterTag` method on `NFCService` is concrete (not added to `SpoolScannerProtocol`) since printer tag writing is NFC-specific and doesn't apply to QR scanner implementations.

## Rationale
- Keeps the existing spool writing path untouched and stable
- `NFCMessageWriteDelegate` is more flexible — can write any NDEF message composition
- Accessing via `nfcScanner as? NFCService` cast is acceptable since printer tag writing is inherently NFC-only
- iOS handles URI record recognition automatically — no need to modify the read delegate for printer tags

## Alternatives Considered
- Refactoring NFCWriteDelegate to accept either Data or NFCNDEFMessage — rejected, adds complexity to working code
- Adding `writePrinterTag` to SpoolScannerProtocol — rejected, QR scanners can't write NFC tags
