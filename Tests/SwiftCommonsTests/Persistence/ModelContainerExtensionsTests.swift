import Foundation
import SwiftData
import Testing

@testable import SwiftCommons

@Model
private final class ModelContainerTestItem {
    init(name: String) {
        self.name = name
    }

    var name: String
}

@Suite("ModelContainer+Extensions")
struct ModelContainerExtensionsTests {
    @Test
    func inMemoryContainerPersistsWithinASession() throws {
        let container = try ModelContainer.make(for: ModelContainerTestItem.self, inMemory: true)
        let context = ModelContext(container)

        context.insert(ModelContainerTestItem(name: "widget"))
        try context.save()

        let items = try context.fetch(FetchDescriptor<ModelContainerTestItem>())
        #expect(items.map(\.name) == ["widget"])
    }

    @Test
    func separateInMemoryContainersDoNotShareState() throws {
        let first = try ModelContainer.make(for: ModelContainerTestItem.self, inMemory: true)
        let firstContext = ModelContext(first)
        firstContext.insert(ModelContainerTestItem(name: "widget"))
        try firstContext.save()

        let second = try ModelContainer.make(for: ModelContainerTestItem.self, inMemory: true)
        let secondContext = ModelContext(second)
        let items = try secondContext.fetch(FetchDescriptor<ModelContainerTestItem>())

        #expect(items.isEmpty)
    }
}
