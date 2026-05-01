import XCTest
import SwiftCheck

/// Verifies that SwiftCheck is properly linked to the CreamieTests target.
final class SwiftCheckImportTest: XCTestCase {
    func testSwiftCheckIsAvailable() {
        // A minimal property test to confirm SwiftCheck resolves and runs.
        property("trivial truth") <- forAll { (n: Int) in
            return n == n
        }
    }
}
