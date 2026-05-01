import SwiftUI
import Combine
import Supabase
import UIKit
import AudioToolbox

struct Chat: Identifiable, Hashable {
    let id: UUID
    let currentUserId: UUID
    let otherDogId: UUID
    let otherDogName: String
    let otherDogAvatar: String
    let currentDogId: UUID?
    let currentDogName: String?
    var createdAt: Date?
    var messages: [Message]?
    var lastMessageDate: Date = Date()
    var unreadCount: Int = 0
    var lastMessagePreview: String = ""
    
    var safeMessages: [Message] {
        return messages ?? []
    }
    
    var lastMessageText: String {
        if !lastMessagePreview.isEmpty { return lastMessagePreview }
        return messages?.last?.text ?? ""
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id &&
        lhs.unreadCount == rhs.unreadCount &&
        lhs.lastMessageDate == rhs.lastMessageDate &&
        lhs.lastMessagePreview == rhs.lastMessagePreview
    }
}

extension Chat {
    static var empty: Chat {
        Chat(id: UUID(),
             currentUserId: UUID(),
             otherDogId: UUID(),
             otherDogName: "",
             otherDogAvatar: "",
             currentDogId: nil,
             currentDogName: nil,
             createdAt: Date(),
             messages: [],
             unreadCount: 0
        )
    }
}

struct SupabaseChat: Decodable {
    let id: UUID
    let current_user_id: UUID
    let other_dog_id: UUID
    let other_dog_name: String
    let other_dog_avatar: String
    let current_dog_id: UUID?
    let current_dog_name: String?
    let inserted_at: Date
}

// Represents an individual message in a chat
struct Message: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isFromCurrentUser: Bool
    let timestamp: Date
}

struct SupabaseMessagePayload: Decodable {
    let id: UUID
    let chat_id: UUID
    let sender_id: UUID
    let text: String
    let created_at: String
}

/// Cached date formatters for parsing Supabase timestamps.
/// Creating formatters is expensive — reuse them across calls.
private enum SupabaseDateParsing {
    static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()
    
    static let fallbackFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ssZZZZZ",
        ]
        return formats.map { format in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(identifier: "UTC")
            df.dateFormat = format
            return df
        }
    }()
}

/// Parses Supabase timestamp strings which may come in various formats:
/// - `2025-04-30T14:32:05.123456+00:00` (ISO8601 with fractional seconds and timezone)
/// - `2025-04-30T14:32:05+00:00` (ISO8601 without fractional seconds)
/// - `2025-04-30T14:32:05.123456` (no timezone)
/// - `2025-04-30 14:32:05.123456+00` (space separator, short timezone)
private func parseSupabaseDate(_ dateStr: String) -> Date? {
    if let date = SupabaseDateParsing.isoFractional.date(from: dateStr) { return date }
    if let date = SupabaseDateParsing.isoBasic.date(from: dateStr) { return date }
    
    for formatter in SupabaseDateParsing.fallbackFormatters {
        if let date = formatter.date(from: dateStr) { return date }
    }
    
    return nil
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var currentlyViewedChatId: UUID?
    
    /// Total unread message count across all chats — used by the tab bar badge.
    var totalUnreadCount: Int {
        chats.reduce(0) { $0 + $1.unreadCount }
    }

    private let authService = AuthenticationService.shared
    private let messagesTableName = "messages"
    private var activeSubscriptions: [UUID: RealtimeChannelV2] = [:]
    private let chatsTableName = "chats"
    
    /// Tracks when chats were last fetched to avoid redundant network requests.
    /// If a fetch was performed within the last 30 seconds, subsequent calls
    /// return the already-loaded chats without hitting the network.
    private(set) var lastFetchTime: Date?
    
    /// The minimum interval (in seconds) between network fetches.
    private let staleFetchInterval: TimeInterval = 30
    
    /// Pre-configured decoder for Supabase chat responses.
    /// The SupabaseChat struct uses snake_case property names that match the
    /// JSON keys directly, so we use a plain decoder with a custom date format
    /// rather than APIService.shared.decoder (which applies convertFromSnakeCase).
    private let chatDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
    
    /// Resets the stale-data guard so the next call to
    /// `fetchChatsByCurrentUserId` will perform a network request.
    func invalidateCache() {
        lastFetchTime = nil
    }
    
    /// Sorts chats by lastMessageDate descending — chats with the most recent
    /// activity (including new unread messages) naturally appear at the top.
    private func sortChats() {
        chats.sort { $0.lastMessageDate > $1.lastMessageDate }
    }
    

    init() {
        Task {
            await observeSocketStatus()
        }
    }

    /// Tracks the current reconnection attempt for exponential backoff.
    private var reconnectionAttempt = 0
    
    /// Whether a reconnection attempt is currently in progress.
    private var isReconnecting = false
    
    private func observeSocketStatus() async {
        for await status in supabase.realtimeV2.statusChange {
            #if DEBUG
            print("RealtimeV2 Socket status: \(status)")
            #endif
            
            switch status {
            case .disconnected:
                // Connection dropped — attempt reconnection with exponential backoff.
                // Re-subscribes to all previously active chats on success.
                if !isReconnecting {
                    await reconnectWithBackoff()
                }
            case .connected:
                // Reset backoff state on successful connection.
                reconnectionAttempt = 0
                isReconnecting = false
            default:
                break
            }
        }
    }
    
    /// Attempts to reconnect the Supabase real-time socket using exponential
    /// backoff (1s, 2s, 4s, 8s, 16s, 30s cap) via `BackoffCalculator`.
    ///
    /// On successful reconnection, re-subscribes to all chats that were
    /// previously in `activeSubscriptions`.
    private func reconnectWithBackoff() async {
        isReconnecting = true
        
        // Capture the chat IDs that need re-subscription before clearing.
        let chatIdsToResubscribe = Array(activeSubscriptions.keys)
        
        while isReconnecting {
            let delay = BackoffCalculator.backoffDelay(attempt: reconnectionAttempt)
            #if DEBUG
            print("🔄 Reconnection attempt \(reconnectionAttempt), waiting \(delay)s")
            #endif
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Check if we've already reconnected (status may have changed while sleeping)
            // The `observeSocketStatus` loop sets `isReconnecting = false` on `.connected`.
            guard isReconnecting else { return }
            
            do {
                await supabase.realtimeV2.connect()
                
                // Re-subscribe to all previously active chats.
                // Clear old subscriptions first since the channels are stale.
                activeSubscriptions.removeAll()
                for chatId in chatIdsToResubscribe {
                    await subscribeToMessages(for: chatId)
                }
                
                #if DEBUG
                print("✅ Reconnected and re-subscribed to \(chatIdsToResubscribe.count) chats")
                #endif
                
                isReconnecting = false
                reconnectionAttempt = 0
                return
            } catch {
                #if DEBUG
                print("❌ Reconnection attempt \(reconnectionAttempt) failed: \(error)")
                #endif
                reconnectionAttempt += 1
            }
        }
    }

    func findOrCreateChatBetweenDogs(fromDog: Dog, toDog: Dog) async -> Chat {
        let currentUserId = authService.currentUser!.id
        
        // Fetch all conversations for current user's dogs
        await fetchChatsByCurrentUserId(currentUserId: currentUserId)
        
        // Check if conversation already exists between these two specific dogs
        if let existing = self.chats.first(where: {
            ($0.currentDogId == fromDog.id && $0.otherDogId == toDog.id) ||
            ($0.currentDogId == toDog.id && $0.otherDogId == fromDog.id)
        }) {
            #if DEBUG
            print("Found existing conversation \(existing.id) between \(fromDog.name) and \(toDog.name)")
            #endif
            return existing
        }

        // Create new conversation between dogs
        #if DEBUG
        print("no existing conversation")
        #endif
        let chatId = UUID()
        let newChat = Chat(
            id: chatId,
            currentUserId: currentUserId,
            otherDogId: toDog.id,
            otherDogName: toDog.name,
            otherDogAvatar: toDog.photos.first ?? "",
            currentDogId: fromDog.id,
            currentDogName: fromDog.name,
            createdAt: Date(),
            messages: [],
            lastMessageDate: Date()
        )
            
        // Insert new chat on Supabase
        do {
            #if DEBUG
            print("Start insert new chat on Supabase")
            #endif
            try await supabase
                .from(chatsTableName)
                .insert([
                    "id": newChat.id.uuidString,
                    "current_user_id": newChat.currentUserId.uuidString,
                    "other_dog_id": newChat.otherDogId.uuidString,
                    "other_dog_name": newChat.otherDogName,
                    "other_dog_avatar": newChat.otherDogAvatar,
                    "current_dog_id": fromDog.id.uuidString,
                    "current_dog_name": fromDog.name,
                    "current_dog_avatar": fromDog.photos.first ?? ""
                ])
                .execute()
            
            chats.append(newChat)
            #if DEBUG
            print("Created new conversation \(chatId) between \(fromDog.name) and \(toDog.name)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to create chat \(newChat.id) on Supabase:", error)
            #endif
        }

        return newChat
    }
    
    func fetchChatsByCurrentUserId(currentUserId: UUID? = nil) async {
        // Stale-data guard: skip re-fetch if data was loaded within the last 30 seconds.
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < staleFetchInterval {
            return
        }
        
        let currentUserId = currentUserId ?? authService.currentUser!.id
        
        do {
            // First, get all dogs owned by the current user
            let dogsResponse = try await supabase
                .from("dogs")
                .select("id")
                .eq("owner_id", value: currentUserId)
                .execute()
            
            let dogsData = dogsResponse.data
            let userDogIds = try APIService.shared.decoder.decode([DogId].self, from: dogsData).map { $0.id }
            
            // Now fetch chats where:
            // 1. Current user started the chat (current_user_id), OR
            // 2. Someone wants to chat with any of current user's dogs (other_dog_id)
            var orConditions = ["current_user_id.eq.\(currentUserId)"]
            for dogId in userDogIds {
                orConditions.append("other_dog_id.eq.\(dogId)")
            }
            
            let response = try await supabase
                .from("chats")
                .select("*")
                .or(orConditions.joined(separator: ","))
                .execute()
            
            let data = response.data
            
            // Reuse the shared, pre-configured decoder from APIService
            // instead of allocating a new JSONDecoder per call.
            let decoded = try chatDecoder.decode([SupabaseChat].self, from: data)

            let loadedChats = decoded.map { supaChat -> Chat in
                let isCurrentUserTheSender = supaChat.current_user_id == currentUserId
                
                if isCurrentUserTheSender {
                    // Current user started the chat, use the stored info
                    return Chat(
                        id: supaChat.id,
                        currentUserId: currentUserId,
                        otherDogId: supaChat.other_dog_id,
                        otherDogName: supaChat.other_dog_name,
                        otherDogAvatar: supaChat.other_dog_avatar,
                        currentDogId: supaChat.current_dog_id,
                        currentDogName: supaChat.current_dog_name,
                        createdAt: supaChat.inserted_at,
                        messages: [],
                        lastMessageDate: supaChat.inserted_at
                    )
                } else {
                    // Someone else started a chat with current user's dog
                    // The "other" dog is actually the sender's dog, "current" dog is yours
                    return Chat(
                        id: supaChat.id,
                        currentUserId: currentUserId,
                        otherDogId: supaChat.current_dog_id ?? supaChat.current_user_id,
                        otherDogName: supaChat.current_dog_name ?? "Other Dog",
                        otherDogAvatar: "", // Pending Fetch sender's dog avatar
                        currentDogId: supaChat.other_dog_id,
                        currentDogName: supaChat.other_dog_name,
                        createdAt: supaChat.inserted_at,
                        messages: [],
                        lastMessageDate: supaChat.inserted_at
                    )
                }
            }

            self.chats = loadedChats
            
            // Fetch unread counts AND last message previews concurrently for all chats.
            // Each chat issues a SINGLE batched query that returns both the last message
            // preview and enough data to compute the unread count, halving the number of
            // network round-trips compared to the previous two-query-per-chat approach.
            // On failure, falls back to individual queries per the design error handling.
            let chatSnapshots = self.chats.enumerated().map { (index: $0.offset, id: $0.element.id) }
            
            typealias ChatMetadata = (index: Int, unreadCount: Int, lastMessagePreview: String, lastMessageDate: Date?)
            
            let results: [ChatMetadata] = await withTaskGroup(of: ChatMetadata?.self) { group in
                for snapshot in chatSnapshots {
                    let chatId = snapshot.id
                    let chatIndex = snapshot.index
                    let userIdStr = currentUserId.uuidString
                    
                    group.addTask {
                        // Try the combined single-query approach first.
                        // Fetches recent messages (text, created_at, sender_id) for this chat
                        // and derives both unread count and last message preview client-side.
                        do {
                            let lastReadKey = "last_read_at_\(chatId.uuidString)"
                            let lastReadTimestamp = UserDefaults.standard.object(forKey: lastReadKey) as? Date
                            
                            var query = supabase
                                .from("messages")
                                .select("sender_id,text,created_at")
                                .eq("chat_id", value: chatId.uuidString)
                            
                            // If we have a last-read timestamp, fetch messages since then
                            // plus one extra (the latest message for preview, which may be
                            // older than last_read_at if the user sent the most recent one).
                            // Without a last-read timestamp, fetch all messages from the
                            // other user (no upper bound).
                            if let lastReadTimestamp {
                                let lastReadStr = SupabaseDateParsing.isoFractional.string(from: lastReadTimestamp)
                                // Fetch messages newer than last_read_at. This gives us
                                // unread messages from the other user AND the latest message
                                // (regardless of sender) for the preview.
                                // Filter must come before .order() since order returns a
                                // PostgrestTransformBuilder that doesn't support filters.
                                query = query.gt("created_at", value: lastReadStr)
                            }
                            
                            let response = try await query
                                .order("created_at", ascending: false)
                                .execute()
                            
                            if let messages = try? JSONDecoder().decode([[String: String]].self, from: response.data) {
                                // Last message preview: the first row (most recent by created_at desc)
                                let preview = messages.first?["text"] ?? ""
                                var msgDate: Date? = nil
                                if let dateStr = messages.first?["created_at"] {
                                    msgDate = parseSupabaseDate(dateStr)
                                }
                                
                                // Unread count: messages NOT from the current user
                                let unreadCount = messages.filter { $0["sender_id"] != userIdStr }.count
                                
                                // If we have a last_read_at but got zero results, the last
                                // message may be older. Fetch just the latest message for preview.
                                if messages.isEmpty && lastReadTimestamp != nil {
                                    let previewResponse = try await supabase
                                        .from("messages")
                                        .select("text,created_at")
                                        .eq("chat_id", value: chatId.uuidString)
                                        .order("created_at", ascending: false)
                                        .limit(1)
                                        .execute()
                                    
                                    if let previewMessages = try? JSONDecoder().decode([[String: String]].self, from: previewResponse.data),
                                       let first = previewMessages.first {
                                        let fallbackPreview = first["text"] ?? ""
                                        var fallbackDate: Date? = nil
                                        if let dateStr = first["created_at"] {
                                            fallbackDate = parseSupabaseDate(dateStr)
                                        }
                                        return (index: chatIndex, unreadCount: 0, lastMessagePreview: fallbackPreview, lastMessageDate: fallbackDate)
                                    }
                                }
                                
                                return (index: chatIndex, unreadCount: unreadCount, lastMessagePreview: preview, lastMessageDate: msgDate)
                            }
                            
                            // Decoding failed — fall through to fallback
                            throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode batched metadata response"])
                        } catch {
                            #if DEBUG
                            print("⚠️ Batched metadata query failed for chat \(chatId), falling back to individual queries: \(error)")
                            #endif
                            
                            // ── Fallback: two individual queries (original approach) ──
                            var unreadCount = 0
                            var preview = ""
                            var msgDate: Date? = nil
                            
                            // Fallback: fetch unread count
                            do {
                                let lastReadKey = "last_read_at_\(chatId.uuidString)"
                                if let lastReadTimestamp = UserDefaults.standard.object(forKey: lastReadKey) as? Date {
                                    let lastReadStr = SupabaseDateParsing.isoFractional.string(from: lastReadTimestamp)
                                    
                                    let countResponse = try await supabase
                                        .from("messages")
                                        .select("id", head: false)
                                        .eq("chat_id", value: chatId.uuidString)
                                        .neq("sender_id", value: userIdStr)
                                        .gt("created_at", value: lastReadStr)
                                        .execute()
                                    
                                    if let decoded = try? JSONDecoder().decode([[String: String]].self, from: countResponse.data) {
                                        unreadCount = decoded.count
                                    }
                                } else {
                                    let countResponse = try await supabase
                                        .from("messages")
                                        .select("id", head: false)
                                        .eq("chat_id", value: chatId.uuidString)
                                        .neq("sender_id", value: userIdStr)
                                        .execute()
                                    
                                    if let decoded = try? JSONDecoder().decode([[String: String]].self, from: countResponse.data) {
                                        unreadCount = decoded.count
                                    }
                                }
                            } catch {
                                #if DEBUG
                                print("❌ Fallback: Failed to fetch unread count for chat \(chatId): \(error)")
                                #endif
                            }
                            
                            // Fallback: fetch last message preview
                            do {
                                let lastMsgResponse = try await supabase
                                    .from("messages")
                                    .select("text,created_at")
                                    .eq("chat_id", value: chatId.uuidString)
                                    .order("created_at", ascending: false)
                                    .limit(1)
                                    .execute()
                                
                                if let decoded = try? JSONDecoder().decode([[String: String]].self, from: lastMsgResponse.data),
                                   let first = decoded.first {
                                    preview = first["text"] ?? ""
                                    if let dateStr = first["created_at"] {
                                        msgDate = parseSupabaseDate(dateStr)
                                    }
                                }
                            } catch {
                                #if DEBUG
                                print("❌ Fallback: Failed to fetch last message for chat \(chatId): \(error)")
                                #endif
                            }
                            
                            return (index: chatIndex, unreadCount: unreadCount, lastMessagePreview: preview, lastMessageDate: msgDate)
                        }
                    }
                }
                
                var collected: [ChatMetadata] = []
                for await result in group {
                    if let r = result { collected.append(r) }
                }
                return collected
            }
            
            // Apply results back to chats array
            for result in results {
                guard result.index < self.chats.count else { continue }
                self.chats[result.index].unreadCount = result.unreadCount
                self.chats[result.index].lastMessagePreview = result.lastMessagePreview
                if let date = result.lastMessageDate {
                    self.chats[result.index].lastMessageDate = date
                }
            }
            
            self.sortChats()
            
            // Record the fetch time so subsequent calls within 30s are skipped.
            self.lastFetchTime = Date()
            
            // Subscribe to realtime messages for all chats so incoming messages
            // update the badge count and trigger notifications even before the
            // user opens a specific chat.
            for chat in self.chats {
                await subscribeToMessages(for: chat.id)
            }
            
            #if DEBUG
            print("📥 Loaded \(self.chats.count) conversations for user \(currentUserId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to load chats: \(error)")
            #endif
        }
    }
    
    /// Maximum number of messages to load per page.
    private let messagePageSize = 50
    
    /// Fetches messages for a chat with pagination support.
    ///
    /// - Parameters:
    ///   - chatId: The chat to fetch messages for.
    ///   - before: When `nil` (initial load), fetches the most recent `messagePageSize`
    ///     messages. When provided, fetches the next `messagePageSize` messages older
    ///     than this date (scroll-to-top pagination).
    ///
    /// Messages are stored in ascending order (oldest first) for display, regardless
    /// of the descending fetch order used for pagination.
    func fetchMessagesByChatId(for chatId: UUID, before: Date? = nil) async {
        let currentUserId = authService.currentUser!.id
        
        do {
            var query = supabase
                .from(messagesTableName)
                .select("*")
                .eq("chat_id", value: chatId.uuidString)
            
            // When paginating, only fetch messages older than the cursor date
            if let before = before {
                let beforeStr = SupabaseDateParsing.isoFractional.string(from: before)
                query = query.lt("created_at", value: beforeStr)
            }
            
            // Fetch in descending order so `.limit()` gives us the most recent page,
            // then reverse client-side for ascending display order.
            let response = try await query
                .order("created_at", ascending: false)
                .limit(messagePageSize)
                .execute()
            
            let data = response.data
            let decoder = JSONDecoder()
            
            let decoded = try decoder.decode([SupabaseMessagePayload].self, from: data)
            
            // Map to Message models and reverse to ascending (oldest-first) order.
            // Use the server-provided `supaMessage.id` as the stable identifier
            // so that SwiftUI's LazyVStack can diff efficiently without full re-renders.
            let messages = decoded.map { supaMessage -> Message in
                return Message(
                    id: supaMessage.id,
                    text: supaMessage.text,
                    isFromCurrentUser: supaMessage.sender_id == currentUserId,
                    timestamp: parseSupabaseDate(supaMessage.created_at) ?? Date()
                )
            }.reversed() as [Message]
            
            // Update the specific chat with loaded messages
            if let index = self.chats.firstIndex(where: { $0.id == chatId }) {
                if before != nil {
                    // Paginating: prepend older messages to the existing array
                    let existing = self.chats[index].messages ?? []
                    self.chats[index].messages = messages + existing
                } else {
                    // Initial load: replace the messages array
                    self.chats[index].messages = messages
                    self.chats[index].unreadCount = 0
                    
                    // Save last_read_at timestamp to UserDefaults
                    let lastReadKey = "last_read_at_\(chatId.uuidString)"
                    UserDefaults.standard.set(Date(), forKey: lastReadKey)
                }
            }
            
            #if DEBUG
            print("📥 Loaded \(messages.count) messages for chat \(chatId)\(before != nil ? " (older page)" : "")")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to load messages for chat \(chatId): \(error)")
            #endif
        }
    }
    
    /// Loads the next page of older messages for a chat.
    ///
    /// Finds the oldest message timestamp in the current messages array and
    /// fetches the next batch of messages older than that date. The older
    /// messages are prepended to the existing array so the display order
    /// (oldest first) is preserved.
    ///
    /// - Parameter chatId: The chat to load older messages for.
    func loadOlderMessages(for chatId: UUID) async {
        guard let chatIndex = self.chats.firstIndex(where: { $0.id == chatId }),
              let messages = self.chats[chatIndex].messages,
              let oldestMessage = messages.first else {
            return
        }
        
        await fetchMessagesByChatId(for: chatId, before: oldestMessage.timestamp)
    }

    func sendMessage(_ text: String, in chat: Chat) {
        let currentUserId = authService.currentUser!.id
        let messageId = UUID()
        let newMessage = Message(id: messageId,
                                 text: text,
                                 isFromCurrentUser: true,
                                 timestamp: Date())

        // load in frontend
        if let index = self.chats.firstIndex(where: { $0.id == chat.id }) {
            if self.chats[index].messages == nil {
                self.chats[index].messages = []
            }
            
            self.chats[index].messages!.append(newMessage)
            self.chats[index].lastMessageDate = newMessage.timestamp
            self.chats[index].lastMessagePreview = newMessage.text
            self.sortChats()
        }
        
        // save to backend
        let chatId = chat.id
        let senderId = currentUserId

        Task {
            do {
                _ = try await supabase
                    .from(messagesTableName)
                    .insert([
                        "chat_id": chatId.uuidString,
                        "sender_id": senderId.uuidString,
                        "text": text
                    ])
                    .execute()
                #if DEBUG
                print("📤 Message \(messageId) sent for chat \(chatId)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to send message to chat \(chatId):", error)
                #endif
            }
        }
    }

    func subscribeToMessages(for chatID: UUID) async {
        #if DEBUG
        print("🔄 Starting subscription for chat: \(chatID)")
        #endif
        let currentUserId = authService.currentUser!.id
        
        // Check if already subscribed to this chat
        if activeSubscriptions[chatID] != nil {
            return
        }
        
        // Create unique channel for this chat
        let channelName = "chat-\(chatID.uuidString)"
        let channel = await supabase.realtimeV2.channel(channelName)
        
        // Set up postgres changes listener for ALL messages (no filter)
        let insertions = await channel.postgresChange(
            InsertAction.self,
            table: "messages"
        )
        
        // Store the channel reference before subscribing
        activeSubscriptions[chatID] = channel
        
        // Subscribe to the channel
        await channel.subscribe()
        #if DEBUG
        print("✅ Subscribed to messages for chat \(chatID)")
        #endif
        
        // Listen for postgres changes
        Task {
            for await insertion in insertions {
                do {
                    let decoder = JSONDecoder()
                    let newRecord = try insertion.decodeRecord(
                        as: SupabaseMessagePayload.self,
                        decoder: decoder
                    )
                    
                    // Filter messages: only process if it's for this chat and not from current user
                    guard newRecord.chat_id == chatID else { continue }
                    guard newRecord.sender_id != currentUserId else { continue }
                    
                    await handleIncomingMessage(newRecord)
                    
                } catch {
                    #if DEBUG
                    print("❌ POSTGRES: Failed to decode message record: \(error)")
                    #endif
                }
            }
        }
        

    }
    
    /// Unsubscribes from all active real-time message channels.
    ///
    /// Iterates every entry in `activeSubscriptions`, unsubscribes each
    /// channel, and clears the dictionary. Called during sign-out to release
    /// all real-time resources.
    func unsubscribeAll() async {
        for (chatId, channel) in activeSubscriptions {
            await channel.unsubscribe()
            #if DEBUG
            print("🔕 Unsubscribed from messages for chat \(chatId) (sign-out cleanup)")
            #endif
        }
        activeSubscriptions.removeAll()
    }
    
    private func handleIncomingMessage(_ messagePayload: SupabaseMessagePayload) async {
//        print("🔄 Processing incoming message: \(messagePayload.text)")
        
        let newMessage = Message(
            id: messagePayload.id,
            text: messagePayload.text,
            isFromCurrentUser: false,
            timestamp: parseSupabaseDate(messagePayload.created_at) ?? Date()
        )
        
        // Find the chat and add the message
        if let index = self.chats.firstIndex(where: { $0.id == messagePayload.chat_id }) {
            // Initialize messages array if nil
            if self.chats[index].messages == nil {
                self.chats[index].messages = []
            }
            
            // Check for duplicates based on message ID
            let messageExists = self.chats[index].messages?.contains { $0.id == newMessage.id } ?? false
            
            if !messageExists {
                self.chats[index].messages!.append(newMessage)
                self.chats[index].lastMessageDate = newMessage.timestamp
                self.chats[index].lastMessagePreview = newMessage.text
                
                // Increment unread count only if the chat is NOT currently being viewed
                if messagePayload.chat_id != currentlyViewedChatId {
                    self.chats[index].unreadCount += 1
                    
                    // Haptic feedback and default notification sound
                    AudioServicesPlaySystemSound(1007)  // Default "Tink" message sound
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
                
                // Re-sort chats by last message date
                self.sortChats()
            }
        } else {
            #if DEBUG
            print("❌ Chat not found for message: \(messagePayload.chat_id)")
            #endif
        }
    }
    
    func deleteChat(_ chat: Chat) {
        // Remove from local state first
        chats.removeAll { $0.id == chat.id }
        
        // Delete from backend
        Task {
            do {
                _ = try await supabase
                    .from(chatsTableName)
                    .delete()
                    .eq("id", value: chat.id.uuidString)
                    .execute()
                
                #if DEBUG
                print("🗑️ Successfully deleted chat \(chat.id) and its messages")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to delete chat \(chat.id) from backend: \(error)")
                #endif
                // Re-add to local state if backend deletion failed
                await MainActor.run {
                    if !self.chats.contains(where: { $0.id == chat.id }) {
                        self.chats.append(chat)
                        self.sortChats()
                    }
                }
            }
        }
    }
    
    private struct DogId: Decodable {
        let id: UUID
    }
}
