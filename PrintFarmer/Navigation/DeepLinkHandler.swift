import Foundation

enum DeepLinkDestination: Equatable {
    case printerDetail(id: UUID)
    case printerReady(id: UUID)
}

struct DeepLinkHandler {
    /// Parses `printfarmer://` URLs into navigation destinations.
    ///
    /// Supported routes:
    /// - `printfarmer://printer/{UUID}` → printer detail
    /// - `printfarmer://printer/{UUID}/ready` → printer detail + mark ready
    static func parse(url: URL) -> DeepLinkDestination? {
        guard url.scheme == "printfarmer" else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // url.host is "printer" for printfarmer://printer/{UUID}
        guard url.host == "printer" else { return nil }
        guard let first = pathComponents.first else { return nil }

        guard let printerId = UUID(uuidString: first) else { return nil }

        if pathComponents.count > 1, pathComponents[1].lowercased() == "ready" {
            return .printerReady(id: printerId)
        }
        return .printerDetail(id: printerId)
    }
}
