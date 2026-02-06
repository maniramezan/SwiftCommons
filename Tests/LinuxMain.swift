import DateHandyTests
import XCTest

var tests = [XCTestCaseEntry]()
tests += FixedWidthIntegerExtensionsTests.allTests()
tests += ArrayExtensionsTests.allTests()
XCTMain(tests)
