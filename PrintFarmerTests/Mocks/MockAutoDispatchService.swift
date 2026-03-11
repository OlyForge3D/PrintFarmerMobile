import Foundation
@testable import PrintFarmer

final class MockAutoDispatchService: AutoDispatchServiceProtocol, @unchecked Sendable {
    var allStatusToReturn: [AutoDispatchStatus] = []
    var statusToReturn: AutoDispatchStatus?
    var readyResultToReturn: AutoDispatchReadyResult?
    var errorToThrow: Error?
    
    // Call tracking
    var getAllStatusCalled = false
    var getStatusCalledWith: UUID?
    var markReadyCalledWith: UUID?
    var skipCalledWith: UUID?
    var cancelCalledWith: UUID?
    var setEnabledCalledWith: (printerId: UUID, request: SetAutoDispatchEnabledRequest)?
    
    func getAllStatus() async throws -> [AutoDispatchStatus] {
        getAllStatusCalled = true
        if let error = errorToThrow { throw error }
        return allStatusToReturn
    }
    
    func getStatus(printerId: UUID) async throws -> AutoDispatchStatus {
        getStatusCalledWith = printerId
        if let error = errorToThrow { throw error }
        return statusToReturn ?? allStatusToReturn.first!
    }
    
    func markReady(printerId: UUID) async throws -> AutoDispatchReadyResult {
        markReadyCalledWith = printerId
        if let error = errorToThrow { throw error }
        return readyResultToReturn!
    }
    
    func skip(printerId: UUID) async throws -> AutoDispatchStatus {
        skipCalledWith = printerId
        if let error = errorToThrow { throw error }
        return statusToReturn ?? allStatusToReturn.first!
    }
    
    func cancel(printerId: UUID) async throws -> AutoDispatchStatus {
        cancelCalledWith = printerId
        if let error = errorToThrow { throw error }
        return statusToReturn ?? allStatusToReturn.first!
    }
    
    func setEnabled(printerId: UUID, request: SetAutoDispatchEnabledRequest) async throws -> AutoDispatchStatus {
        setEnabledCalledWith = (printerId, request)
        if let error = errorToThrow { throw error }
        return statusToReturn ?? allStatusToReturn.first!
    }
}
