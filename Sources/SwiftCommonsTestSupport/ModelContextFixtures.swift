import Foundation
import SwiftCommons
import SwiftData

/// Creates an in-memory `ModelContext` for the given model types.
///
/// A thin convenience over `ModelContainer.make(for:inMemory:)` (from the
/// `SwiftCommons` module) for the common test/preview need of "give me a
/// context I can insert fixtures into right now":
///
///     let context = try makeInMemoryModelContext(for: Item.self, Tag.self)
///     context.insert(Item(name: "widget"))
///     try context.save()
///
/// Each call creates a fresh, independent in-memory store — nothing is shared
/// across calls, so tests don't need to worry about state leaking between
/// runs.
///
/// - Parameter types: The `PersistentModel` types the context's container
///   should manage.
/// - Returns: A `ModelContext` backed by a fresh in-memory `ModelContainer`.
/// - Throws: Any error thrown by `ModelContainer.init(for:configurations:)`.
public func makeInMemoryModelContext(
    for types: any PersistentModel.Type...
) throws -> ModelContext {
    let container = try ModelContainer.make(for: types, inMemory: true)
    return ModelContext(container)
}
