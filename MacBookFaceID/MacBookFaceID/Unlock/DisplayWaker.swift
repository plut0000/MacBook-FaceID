import Foundation
import IOKit
import IOKit.pwr_mgt

enum DisplayWaker {
    /// Declares local user activity so a sleeping display can wake before
    /// the lock-screen password field accepts key events.
    @discardableResult
    static func wake() -> IOPMAssertionID {
        var assertionID: IOPMAssertionID = 0
        let status = IOPMAssertionDeclareUserActivity(
            "MacBook Face Unlock" as CFString,
            kIOPMUserActiveLocal,
            &assertionID
        )
        if status != kIOReturnSuccess {
            assertionID = 0
        }
        return assertionID
    }
}
