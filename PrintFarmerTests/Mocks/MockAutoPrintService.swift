import Foundation
@testable import PrintFarmer

final class MockAutoPrintService: AutoPrintServiceProtocol, @unchecked Sendable {
    var allStatusToReturn: [AutoPrintStatus] = []
    var statusToReturn: AutoPrintStatus?
    var readyResultToReturn: AutoPrintReadyResult?
    var errorToThrow: Error?
    
    // Call tracking
    var getAllStatusCalled = false
    var getStatusCalledWith: UUID?
    var markReadyCalledWith: UUID?
    var skipCalledWith: UUID?
    var cancelCalledWith: UUID?
    var setEnabledCalledWith: (printerId: UUID, request: SetAutoPrintEnabledRequest)?
    
    func getAllStatus() async throws -> [AutoPrintStatus] {
        getAllStatusCalled = true
        if let error = errorToThrow { throw error }
        return allStatusToReturn
    }
    
    func getStatus(printerId: UUID) async throws -> AutoPrintStatus {
        getStatusCalledWith = printerId
        if let error = errorToThrow { throw error }
        return statusToReturn ?? allStatusToReturn.first!
    }
    
    func markReady(printerId: UUID) async throws -> AutoPrintReadyResult {
        markReadyCalledWith = printerId
        if let error = errorToThrow { throw error }
        return readyResultToReturn!
    }
    
    func skip(printerId: UUID) async throws -> AutoPrintStatus {
        skipCalledWith = printerId
        if let error = errorToThrow { throw error }
        return statusToReturn ?? allStatusToReturn.first!
    }
    
    func cancel(printerId: UUID) async throws -> AutoPrintStatus {
        cancelCalledWith = printerId
        if let error = errorToThrow { throw error }
        return statusToReturn ?? allStatusToReturn.first!
    }
    
    func setEnabled(printerId: UUID, request: SetAutoPrintEnabledRequest) async throws -> AutoPrintStatus {
        setEnabledCalledWith = (printerId, request)
        if let error = errorToThrow { throw error }
        return statusToReturn ?? allStatusToReturn.first!
    }
}
