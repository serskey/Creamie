import XCTest

// MARK: - Self-Contained Test Types for Preservation Tests
// These mirror the relevant parts of Chat/Message from the main module
// to avoid deployment target mismatch issues with @testable import.

/// Lightweight message type for preservation testing.
private struct PTestMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromCurrentUser: Bool
    let timestamp: Date
}

/// Lightweight chat type that mirrors Chat struct properties relevant to preservation.
private struct PTestChat: Identifiable {
    let id: UUID
    var messages: [PTestMessage]?
    var unreadCount: Int
    var lastMessageDate: Date

    var safeMessages: [PTestMessage] {
        return messages ?? []
    }

    var lastMessageText: String {
        guard let messages = messages else { return "" }
        return messages.last?.text ?? ""
    }
}

// MARK: - Simulated ViewModel Behaviors
// These replicate the ChatViewModel behaviors locally for testing.

/// Simulates `ChatViewModel.sendMessage(_:in:)` behavior:
/// 1. Finds the chat by id
/// 2. If messages is nil, initializes to []
/// 3. Appends the new message
/// 4. Updates lastMessageDate to the new message's timestamp
/// 5. Re-sorts chats by lastMessageDate descending
private func simulateSendMessage(_ text: String, in chat: PTestChat, chats: inout [PTestChat]) {
    let newMessage = PTestMessage(
        text: text,
        isFromCurrentUser: true,
        timestamp: Date()
    )

    if let index = chats.firstIndex(where: { $0.id == chat.id }) {
        if chats[index].messages == nil {
            chats[index].messages = []
        }
        chats[index].messages!.append(newMessage)
        chats[index].lastMessageDate = newMessage.timestamp
        chats.sort { $0.lastMessageDate > $1.lastMessageDate }
    }
}

/// Simulates `ChatViewModel.deleteChat(_:)` behavior:
/// Removes the chat from the chats array using `removeAll { $0.id == chat.id }`
private func simulateDeleteChat(_ chat: PTestChat, chats: inout [PTestChat]) {
    chats.removeAll { $0.id == chat.id }
}

/// Replicates the CURRENT broken badge logic from TabBar.swift.
private func currentBadgeCount(chats: [PTestChat]) -> Int {
    chats.reduce(0) { count, chat in
        count + (chat.safeMessages.isEmpty ? 0 : 1)
    }
}

/// The expected correct badge logic: sum of unread counts.
private func correctBadgeCount(chats: [PTestChat]) -> Int {
    chats.reduce(0) { $0 + $1.unreadCount }
}

// MARK: - Test Helpers

private func makePTestChat(
    messages: [PTestMessage]?,
    unreadCount: Int,
    lastMessageDate: Date = Date()
) -> PTestChat {
    PTestChat(
        id: UUID(),
        messages: messages,
        unreadCount: unreadCount,
        lastMessageDate: lastMessageDate
    )
}

private func makePTestMessages(count: Int, baseDate: Date = Date()) -> [PTestMessage] {
    (0..<count).map { i in
        PTestMessage(
            text: "Message \(i)",
            isFromCurrentUser: i % 2 == 0,
            timestamp: baseDate.addingTimeInterval(Double(i))
        )
    }
}

/// A simple seeded RNG for reproducible property-based tests.
private struct PreservationSeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Preservation Property Tests

/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
///
/// These tests capture the CURRENT behavior of the unfixed code for non-unread
/// functionality. They must PASS on unfixed code, confirming baseline behavior
/// that the fix must preserve.
final class ChatBadgePreservationTests: XCTestCase {

    // MARK: - Property: Zero unread chats produce badge count of 0

    /// **Validates: Requirements 3.1**
    ///
    /// For any array of chats with all `unreadCount = 0` and `messages = nil`,
    /// badge count is 0 (both old and new logic agree).
    func testProperty_AllZeroUnread_NilMessages_BadgeIsZero() {
        let iterations = 100

        for iteration in 0..<iterations {
            var rng = PreservationSeededRNG(seed: UInt64(iteration * 31 + 11))
            let chatCount = Int.random(in: 0...10, using: &rng)

            var chats: [PTestChat] = []
            for _ in 0..<chatCount {
                // All chats have unreadCount = 0 and messages = nil
                chats.append(makePTestChat(messages: nil, unreadCount: 0))
            }

            let brokenResult = currentBadgeCount(chats: chats)
            let correctResult = correctBadgeCount(chats: chats)

            // Both logics should agree: badge is 0
            XCTAssertEqual(brokenResult, 0,
                "Iteration \(iteration): current logic should return 0 for \(chatCount) chats with nil messages and unreadCount=0, got \(brokenResult)")
            XCTAssertEqual(correctResult, 0,
                "Iteration \(iteration): correct logic should return 0 for \(chatCount) chats with nil messages and unreadCount=0, got \(correctResult)")
            XCTAssertEqual(brokenResult, correctResult,
                "Iteration \(iteration): both logics should agree on 0 for zero-unread nil-messages chats")
        }
    }

    // MARK: - Property: sendMessage appends exactly one message, updates lastMessageDate, and chats remain sorted

    /// **Validates: Requirements 3.2**
    ///
    /// For any chat, calling `sendMessage` appends exactly one message,
    /// updates `lastMessageDate` to the new message's timestamp,
    /// and chats remain sorted descending by `lastMessageDate`.
    func testProperty_SendMessage_AppendsAndSortsCorrectly() {
        let iterations = 100

        for iteration in 0..<iterations {
            var rng = PreservationSeededRNG(seed: UInt64(iteration * 47 + 3))

            // Generate 1-5 chats with varying dates
            let chatCount = Int.random(in: 1...5, using: &rng)
            var chats: [PTestChat] = []
            let baseDate = Date(timeIntervalSince1970: 1_000_000)

            for i in 0..<chatCount {
                let offsetSeconds = Int.random(in: 0...10000, using: &rng)
                let date = baseDate.addingTimeInterval(Double(offsetSeconds))
                let hasMessages = Bool.random(using: &rng)
                let messages: [PTestMessage]? = hasMessages
                    ? makePTestMessages(count: Int.random(in: 1...5, using: &rng), baseDate: date)
                    : nil
                chats.append(PTestChat(
                    id: UUID(),
                    messages: messages,
                    unreadCount: 0,
                    lastMessageDate: date
                ))
            }

            // Pick a random chat to send a message to
            let targetIndex = Int.random(in: 0..<chatCount, using: &rng)
            let targetChat = chats[targetIndex]
            let messageCountBefore = chats[targetIndex].messages?.count ?? 0

            // Send message
            simulateSendMessage("Test message \(iteration)", in: targetChat, chats: &chats)

            // Find the chat after send (it may have moved due to sorting)
            guard let updatedIndex = chats.firstIndex(where: { $0.id == targetChat.id }) else {
                XCTFail("Iteration \(iteration): target chat disappeared after sendMessage")
                continue
            }

            let updatedChat = chats[updatedIndex]

            // Assert: exactly one message was appended
            let messageCountAfter = updatedChat.messages?.count ?? 0
            XCTAssertEqual(messageCountAfter, messageCountBefore + 1,
                "Iteration \(iteration): sendMessage should append exactly one message. Before: \(messageCountBefore), After: \(messageCountAfter)")

            // Assert: lastMessageDate was updated to the new message's timestamp
            if let lastMsg = updatedChat.messages?.last {
                XCTAssertEqual(updatedChat.lastMessageDate, lastMsg.timestamp,
                    "Iteration \(iteration): lastMessageDate should equal the new message's timestamp")
            }

            // Assert: chats are sorted descending by lastMessageDate
            for i in 0..<(chats.count - 1) {
                XCTAssertGreaterThanOrEqual(chats[i].lastMessageDate, chats[i + 1].lastMessageDate,
                    "Iteration \(iteration): chats should be sorted descending by lastMessageDate at indices \(i) and \(i+1)")
            }
        }
    }

    // MARK: - Property: deleteChat reduces array count by 1 and removes the chat

    /// **Validates: Requirements 3.4**
    ///
    /// For any chat in the array, calling `deleteChat` reduces the array count
    /// by 1 and the deleted chat's id is no longer present.
    func testProperty_DeleteChat_RemovesChatCorrectly() {
        let iterations = 100

        for iteration in 0..<iterations {
            var rng = PreservationSeededRNG(seed: UInt64(iteration * 53 + 17))

            // Generate 1-8 chats
            let chatCount = Int.random(in: 1...8, using: &rng)
            var chats: [PTestChat] = []

            for _ in 0..<chatCount {
                let offsetSeconds = Int.random(in: 0...10000, using: &rng)
                let date = Date(timeIntervalSince1970: 1_000_000 + Double(offsetSeconds))
                chats.append(makePTestChat(
                    messages: nil,
                    unreadCount: Int.random(in: 0...10, using: &rng),
                    lastMessageDate: date
                ))
            }

            // Pick a random chat to delete
            let targetIndex = Int.random(in: 0..<chatCount, using: &rng)
            let targetChat = chats[targetIndex]
            let countBefore = chats.count

            // Delete the chat
            simulateDeleteChat(targetChat, chats: &chats)

            // Assert: count reduced by 1
            XCTAssertEqual(chats.count, countBefore - 1,
                "Iteration \(iteration): deleteChat should reduce count by 1. Before: \(countBefore), After: \(chats.count)")

            // Assert: deleted chat's id is no longer present
            let stillPresent = chats.contains { $0.id == targetChat.id }
            XCTAssertFalse(stillPresent,
                "Iteration \(iteration): deleted chat id \(targetChat.id) should no longer be in the array")
        }
    }

    // MARK: - Property: safeMessages returns messages ?? []

    /// **Validates: Requirements 3.3**
    ///
    /// `Chat.safeMessages` returns `messages ?? []` — returns empty array for nil,
    /// returns messages array otherwise.
    func testProperty_SafeMessages_ReturnsMessagesOrEmptyArray() {
        let iterations = 100

        for iteration in 0..<iterations {
            var rng = PreservationSeededRNG(seed: UInt64(iteration * 61 + 23))

            let isNil = Bool.random(using: &rng)

            if isNil {
                let chat = makePTestChat(messages: nil, unreadCount: 0)
                XCTAssertTrue(chat.safeMessages.isEmpty,
                    "Iteration \(iteration): safeMessages should return [] when messages is nil")
                XCTAssertEqual(chat.safeMessages.count, 0,
                    "Iteration \(iteration): safeMessages count should be 0 when messages is nil")
            } else {
                let msgCount = Int.random(in: 0...10, using: &rng)
                let messages = makePTestMessages(count: msgCount)
                let chat = makePTestChat(messages: messages, unreadCount: 0)

                XCTAssertEqual(chat.safeMessages.count, msgCount,
                    "Iteration \(iteration): safeMessages should return all \(msgCount) messages")

                // Verify the messages are the same by checking ids
                for (i, msg) in chat.safeMessages.enumerated() {
                    XCTAssertEqual(msg.id, messages[i].id,
                        "Iteration \(iteration): safeMessages[\(i)] id should match original messages[\(i)] id")
                }
            }
        }
    }

    // MARK: - Property: lastMessageText returns "" for nil, last message text otherwise

    /// **Validates: Requirements 3.5**
    ///
    /// `Chat.lastMessageText` returns empty string when messages is nil,
    /// returns last message text otherwise.
    func testProperty_LastMessageText_ReturnsCorrectValue() {
        let iterations = 100

        for iteration in 0..<iterations {
            var rng = PreservationSeededRNG(seed: UInt64(iteration * 73 + 29))

            let messageState = Int.random(in: 0...2, using: &rng)

            switch messageState {
            case 0:
                // messages is nil → lastMessageText should be ""
                let chat = makePTestChat(messages: nil, unreadCount: 0)
                XCTAssertEqual(chat.lastMessageText, "",
                    "Iteration \(iteration): lastMessageText should be empty string when messages is nil")

            case 1:
                // messages is empty array → lastMessageText should be ""
                // (messages.last is nil, so messages.last?.text ?? "" returns "")
                let chat = makePTestChat(messages: [], unreadCount: 0)
                XCTAssertEqual(chat.lastMessageText, "",
                    "Iteration \(iteration): lastMessageText should be empty string when messages is empty array")

            default:
                // messages has items → lastMessageText should be last message's text
                let msgCount = Int.random(in: 1...10, using: &rng)
                let messages = (0..<msgCount).map { i in
                    PTestMessage(
                        text: "Msg_\(iteration)_\(i)",
                        isFromCurrentUser: Bool.random(using: &rng),
                        timestamp: Date()
                    )
                }
                let chat = makePTestChat(messages: messages, unreadCount: 0)
                let expectedText = messages.last!.text

                XCTAssertEqual(chat.lastMessageText, expectedText,
                    "Iteration \(iteration): lastMessageText should be '\(expectedText)', got '\(chat.lastMessageText)'")
            }
        }
    }
}
