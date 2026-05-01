import Foundation

// MARK: - Exponential Backoff Calculator

/// Computes exponential backoff delays for retry logic.
/// Used by ChatViewModel reconnection and DogProfileViewModel upload retry.
enum BackoffCalculator {

    /// Maximum backoff delay in seconds.
    static let maxDelay: TimeInterval = 30.0

    /// Returns the backoff delay for a given attempt number.
    ///
    /// The delay follows an exponential curve: 1s, 2s, 4s, 8s, 16s, 30s, 30s, ...
    ///
    /// - Parameter attempt: The zero-based attempt number (0 = first retry).
    /// - Returns: The delay in seconds, capped at 30 seconds.
    static func backoffDelay(attempt: Int) -> TimeInterval {
        return min(pow(2.0, Double(attempt)), maxDelay)
    }
}
