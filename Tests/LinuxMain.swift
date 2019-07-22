import XCTest

import DateHandyTests

var tests = [XCTestCaseEntry]()
tests += FixedWidthIntegerExtensionsTests.allTests()
tests += ArrayExtensionsTests.allTests()
XCTMain(tests)
