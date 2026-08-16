import Foundation
import SwiftData

@MainActor
enum AppModelContainer {
    static let cloudContainerIdentifier = "iCloud.com.eric.form"

    enum StorageMode: Equatable {
        case iCloud
        case localFallback(String)
    }

    private(set) static var storageMode: StorageMode = .iCloud

    static func make() -> ModelContainer {
        let schema = Schema([
            WorkoutRecord.self,
            ExerciseRecord.self,
            SetRecord.self,
            CardioRecord.self
        ])
        let storeURL = persistentStoreURL()
        let cloudConfiguration = ModelConfiguration(
            "FormCloud",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(cloudContainerIdentifier)
        )

        do {
            storageMode = .iCloud
            return try ModelContainer(
                for: schema,
                configurations: [cloudConfiguration]
            )
        } catch {
            // A local fallback keeps workouts usable if the selected signing team
            // cannot access the configured CloudKit container.
            storageMode = .localFallback(error.localizedDescription)
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
