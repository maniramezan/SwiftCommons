import Foundation
import SwiftData

extension ModelContainer {
    /// Creates a `ModelContainer` for the given model types, with a single
    /// switch between a persistent on-disk store and a transient in-memory
    /// store.
    ///
    ///     // App: persists to disk.
    ///     let container = try ModelContainer.make(for: Item.self, Tag.self)
    ///
    ///     // Previews and tests: nothing touches disk.
    ///     let previewContainer = try ModelContainer.make(for: Item.self, inMemory: true)
    ///
    /// This is a thin convenience over `ModelContainer.init(for:configurations:)`
    /// for the common case of a single store that is either fully persistent or
    /// fully in-memory. Apps needing multiple configurations, migration plans,
    /// or CloudKit integration should construct a `ModelContainer` directly.
    ///
    /// - Parameters:
    ///   - types: The `PersistentModel` types the container should manage.
    ///   - inMemory: When `true`, uses a transient, in-memory store — useful
    ///     for SwiftUI previews and unit tests so runs don't leave state
    ///     behind or interfere with each other. Defaults to `false`.
    /// - Returns: A configured `ModelContainer`.
    /// - Throws: Any error thrown by `ModelContainer.init(for:configurations:)`,
    ///   for example if the on-disk store can't be created or migrated.
    public static func make(
        for types: any PersistentModel.Type...,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(types)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
