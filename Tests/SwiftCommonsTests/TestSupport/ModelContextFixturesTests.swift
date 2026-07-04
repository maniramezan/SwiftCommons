import Foundation
import SwiftData
import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

@Model
private final class ModelContextFixtureItem {
    init(name: String) {
        self.name = name
    }

    var name: String
}

@Suite("makeInMemoryModelContext")
struct ModelContextFixturesTests {
    @Test
    func insertsAndFetchesWithinTheReturnedContext() throws {
        let context = try makeInMemoryModelContext(for: ModelContextFixtureItem.self)
        context.insert(ModelContextFixtureItem(name: "widget"))
        try context.save()

        let items = try context.fetch(FetchDescriptor<ModelContextFixtureItem>())
        #expect(items.map(\.name) == ["widget"])
    }

    @Test
    func separateCallsDoNotShareState() throws {
        let first = try makeInMemoryModelContext(for: ModelContextFixtureItem.self)
        first.insert(ModelContextFixtureItem(name: "widget"))
        try first.save()

        let second = try makeInMemoryModelContext(for: ModelContextFixtureItem.self)
        let items = try second.fetch(FetchDescriptor<ModelContextFixtureItem>())

        #expect(items.isEmpty)
    }
}
