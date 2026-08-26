import Foundation
import SwiftData

@MainActor
enum AppModelContainer {
    enum StorageMode: Equatable {
        case iCloud
        case localFallback(String)
    }

    private(set) static var storageMode: StorageMode = .localFallback(
        "iCloud is unavailable with Personal Team signing."
    )

    static func make() -> ModelContainer {
        let schema = Schema([
            WorkoutRecord.self,
            ExerciseRecord.self,
            SetRecord.self,
            CardioRecord.self
        ])
        let storeURL = persistentStoreURL()
        let localConfiguration = ModelConfiguration(
            "FormLocalFallback",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [localConfiguration]
            )
        } catch {
            fatalError("Form could not open its workout store: \(error)")
        }
    }

    private static func persistentStoreURL() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        // SwiftData's implicit configuration used default.store. Reusing the URL
        // preserves existing on-device history when CloudKit is enabled.
        return directory.appendingPathComponent("default.store")
    }
}
