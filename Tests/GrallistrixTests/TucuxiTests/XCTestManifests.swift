import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return
        testCase(FixedWidthIntegerExtensionsTests.allTests) +
        testCase(ArrayExtensionsTests.allTests.allTests)
}
#endif
