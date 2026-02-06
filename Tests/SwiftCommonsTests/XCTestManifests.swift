import XCTest

#if !canImport(ObjectiveC)
/// Returns the list of test cases for Linux.
public func allTests() -> [XCTestCaseEntry] {
    return
        testCase(FixedWidthIntegerExtensionsTests.allTests) +
        testCase(ArrayExtensionsTests.allTests.allTests)
}
#endif
