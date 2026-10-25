import XCTest
@testable import FormCore

final class HealthQueueRecoveryTests: XCTestCase {
    @MainActor
    func testSaveRetryDeduplicatesAndDeleteSupersedesSaveAcrossRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let record = WorkoutRecord(date: .now, routineName: "Audit", duration: 60)
        let payload = HealthWorkoutPayload(record: record)
        let queue = HealthSyncQueueStore(directory: directory)
        try await queue.enqueueSave(payload: payload, replacing: nil)
        try await queue.enqueueSave(payload: payload, replacing: nil)
        var jobs = try await queue.jobs()
        XCTAssertEqual(jobs.count, 1)
        let obsolete = jobs[0]
        try await queue.enqueueDelete(recordIdentifier: record.healthSyncIdentifier, workoutUUID: nil)
        try await queue.update(obsolete)
        jobs = try await HealthSyncQueueStore(directory: directory).jobs()
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].kind, .delete)
    }

    func testFailedRemovalKeepsPendingJobInMemoryAndOnDisk() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let moved = directory.appendingPathExtension("saved")
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: moved)
        }
        let queue = HealthSyncQueueStore(directory: directory)
        try await queue.enqueueDelete(recordIdentifier: UUID(), workoutUUID: nil)
        let original = try await queue.jobs()
        // Replace the parent with a regular file to force an actual filesystem write failure.
        try FileManager.default.moveItem(at: directory, to: moved)
        try Data().write(to: directory)
        do { try await queue.remove(original[0].id); XCTFail("Expected a write failure") }
        catch { }
        let cached = try await queue.jobs()
        XCTAssertEqual(cached, original)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: moved, to: directory)
        let reloaded = try await HealthSyncQueueStore(directory: directory).jobs()
        XCTAssertEqual(reloaded, original)
        try await queue.remove(original[0].id)
        let finished = try await queue.jobs()
        XCTAssertTrue(finished.isEmpty)
    }

    func testUnreadableQueueIsPreservedInsteadOfReplaced() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = HealthSyncQueueStore(directory: directory)
        let file = directory.appendingPathComponent("health-sync-queue.json")
        let data = Data("damaged queue".utf8)
        try data.write(to: file)
        do { try await queue.enqueueDelete(recordIdentifier: UUID(), workoutUUID: nil); XCTFail("Expected a read failure") }
        catch { }
        XCTAssertEqual(try Data(contentsOf: file), data)
    }
    func testFutureQueueVersionCannotBeOverwritten() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = HealthSyncQueueStore(directory: directory)
        let file = directory.appendingPathComponent("health-sync-queue.json")
        let data = Data(#"{"schemaVersion":999,"jobs":[]}"#.utf8)
        try data.write(to: file)
        do { try await queue.enqueueDelete(recordIdentifier: UUID(), workoutUUID: nil); XCTFail("Expected unsupported queue error") }
        catch { }
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

}
