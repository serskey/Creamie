import XCTest

// MARK: - Self-Contained Test Types
// These mirror the relevant parts of the Chat/Message types from the main module
// to avoid deployment target mismatch issues with @testable import.

/// Lightweight message type for testing badge logic.
struct TestMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromCurrentUser: Bool
    let timestamp: Date
}

/// Lightweight chat type that mirrors the Chat struct's badge-relevant properties.
struct TestChat {
    let id: UUID
    var messages: [TestMessage]?
    var unreadCount: Int

    var safeMessages: [TestMessage] {
        return messages ?? []
    }
}

/// Represents a chat scenario for badge count testing.
struct ChatTestCase {
    let chat: TestChat
}

// MARK: - Badge Logic Helpers

/// Replicates the CURRENT broken badge logic from TabBar.swift:
/// `chats.reduce(0) { count, chat in count + (chat.safeMessages.isEmpty ? 0 : 1) }`
func currentBrokenBadgeCount(chats: [TestChat]) -> Int {
    chats.reduce(0) { count, chat in
        count + (chat.safeMessages.isEmpty ? 0 : 1)
    }
}

/// The EXPECTED correct badge logic: sum of unread counts across all chats.
func expectedCorrectBadgeCount(chats: [TestChat]) -> Int {
    chats.reduce(0) { $0 + $1.unreadCount }
}

// MARK: - Test Helpers

func makeTestChat(messages: [TestMessage]?, unreadCount: Int) -> TestChat {
    TestChat(
        id: UUID(),
        messages: messages,
        unreadCount: unreadCount
    )
}

func makeTestMessages(count: Int) -> [TestMessage] {
    (0..<count).map { i in
        TestMessage(
            text: "Message \(i)",
            isFromCurrentUser: false,
            timestamp: Date()
        )
    }
}

// MARK: - Bug Condition Exploration Tests

/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
///
/// These tests demonstrate that the current broken badge logic produces
/// incorrect results. They are EXPECTED TO FAIL on unfixed code, which
/// confirms the bug exists.
final class ChatBadgeCountTests: XCTestCase {

    // MARK: - Concrete Bug Condition Tests

    /// Requirement 1.1: Chat with messages = nil and unreadCount = 5
    /// Current logic returns 0, expected 5
    func testNilMessages_UnreadCountFive_CurrentLogicReturnsZero() {
        let chat = makeTestChat(messages: nil, unreadCount: 5)

        let brokenResult = currentBrokenBadgeCount(chats: [chat])
        let correctResult = expectedCorrectBadgeCount(chats: [chat])

        // This WILL FAIL: broken logic returns 0, correct is 5
        XCTAssertEqual(
            brokenResult, correctResult,
            "Bug confirmed: nil messages chat — broken logic returns \(brokenResult), expected \(correctResult)"
        )
    }

    /// Requirement 1.2: Chat with 5 loaded messages and unreadCount = 5
    /// Current logic returns 1, expected 5
    func testFiveLoadedMessages_UnreadCountFive_CurrentLogicReturnsOne() {
        let chat = makeTestChat(messages: makeTestMessages(count: 5), unreadCount: 5)

        let brokenResult = currentBrokenBadgeCount(chats: [chat])
        let correctResult = expectedCorrectBadgeCount(chats: [chat])

        // This WILL FAIL: broken logic returns 1, correct is 5
        XCTAssertEqual(
            brokenResult, correctResult,
            "Bug confirmed: 5 loaded messages — broken logic returns \(brokenResult), expected \(correctResult)"
        )
    }

    /// Requirement 1.3: Chat with 3 loaded messages and unreadCount = 0
    /// Current logic returns 1, expected 0
    func testThreeLoadedMessages_UnreadCountZero_CurrentLogicReturnsOne() {
        let chat = makeTestChat(messages: makeTestMessages(count: 3), unreadCount: 0)

        let brokenResult = currentBrokenBadgeCount(chats: [chat])
        let correctResult = expectedCorrectBadgeCount(chats: [chat])

        // This WILL FAIL: broken logic returns 1, correct is 0
        XCTAssertEqual(
            brokenResult, correctResult,
            "Bug confirmed: fully read chat — broken logic returns \(brokenResult), expected \(correctResult)"
        )
    }

    /// Requirement 1.4: Three chats — mixed states
    /// One nil messages (unread 3), one with 4 messages (unread 4), one fully read (unread 0)
    /// Current logic returns 2, expected 7
    func testMixedChats_CurrentLogicReturnsBrokenCount() {
        let chats = [
            makeTestChat(messages: nil, unreadCount: 3),
            makeTestChat(messages: makeTestMessages(count: 4), unreadCount: 4),
            makeTestChat(messages: makeTestMessages(count: 2), unreadCount: 0),
        ]

        let brokenResult = currentBrokenBadgeCount(chats: chats)
        let correctResult = expectedCorrectBadgeCount(chats: chats)

        // This WILL FAIL: broken logic returns 2 (only counts chats with loaded messages),
        // correct is 7 (sum of unread counts)
        XCTAssertEqual(
            brokenResult, correctResult,
            "Bug confirmed: mixed chats — broken logic returns \(brokenResult), expected \(correctResult)"
        )
    }

    // MARK: - Property-Based Test (Loop-Based Random Generation)

    /// Property 1: Bug Condition — Badge Count Mismatch Due to Lazy Loading and Binary Reduce Logic
    ///
    /// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
    ///
    /// Generate random arrays of chat scenarios with random unreadCount (0–20)
    /// and random messages states (nil, empty, or populated).
    /// Assert that the current broken logic equals the correct sum.
    /// This will FAIL, surfacing counterexamples that prove the bug.
    func testProperty_BrokenBadgeLogic_MismatchesCorrectUnreadSum() {
        var counterexamples: [(broken: Int, correct: Int, description: String)] = []
        let iterations = 100

        for iteration in 0..<iterations {
            // Use a seeded random generator for reproducibility
            var rng = SeededRandomNumberGenerator(seed: UInt64(iteration * 42 + 7))

            let chatCount = Int.random(in: 1...5, using: &rng)
            var chats: [TestChat] = []
            var descriptions: [String] = []

            for _ in 0..<chatCount {
                let unreadCount = Int.random(in: 0...20, using: &rng)
                let messageState = Int.random(in: 0...2, using: &rng)

                let messages: [TestMessage]?
                let stateDesc: String
                switch messageState {
                case 0:
                    messages = nil
                    stateDesc = "nil"
                case 1:
                    messages = []
                    stateDesc = "empty"
                default:
                    let msgCount = Int.random(in: 1...10, using: &rng)
                    messages = makeTestMessages(count: msgCount)
                    stateDesc = "\(msgCount) messages"
                }

                chats.append(makeTestChat(messages: messages, unreadCount: unreadCount))
                descriptions.append("(messages: \(stateDesc), unread: \(unreadCount))")
            }

            let brokenResult = currentBrokenBadgeCount(chats: chats)
            let correctResult = expectedCorrectBadgeCount(chats: chats)

            if brokenResult != correctResult {
                counterexamples.append((
                    broken: brokenResult,
                    correct: correctResult,
                    description: "Iteration \(iteration): \(descriptions.joined(separator: ", ")) → broken=\(brokenResult), correct=\(correctResult)"
                ))
            }
        }

        // Document counterexamples found
        if !counterexamples.isEmpty {
            let sample = counterexamples.prefix(5).map { $0.description }.joined(separator: "\n  ")
            XCTFail(
                """
                Bug confirmed: \(counterexamples.count)/\(iterations) iterations produced mismatches.
                Sample counterexamples:
                  \(sample)
                """
            )
        }
    }
}

// MARK: - Seeded Random Number Generator

/// A simple seeded RNG for reproducible property-based tests.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
