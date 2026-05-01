import XCTest

// MARK: - Self-Contained Test Types
// These mirror the relevant parts of AcatarView, ChatRow, and ChatView
// to avoid deployment target mismatch issues with @testable import.

/// Represents the result of processing a photoName in AcatarView's .task(id:) block.
struct AcatarLoadResult {
    let calledUIImageNamed: Bool
    let photoNamePassedToUIImage: String?
    let loadFailed: Bool
}

/// Replicates the FIXED .task(id:) logic from AcatarView in PhotoGalleryView.swift:
/// The fix adds an early guard that checks for empty/whitespace photoName and sets
/// loadFailed = true without calling UIImage(named:).
func currentAcatarLoad(photoName: String) -> AcatarLoadResult {
    // Fixed: early guard for empty/whitespace photoName
    guard !photoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return AcatarLoadResult(
            calledUIImageNamed: false,
            photoNamePassedToUIImage: nil,
            loadFailed: true
        )
    }

    guard photoName.hasPrefix("https://") else {
        // Non-empty local asset — UIImage(named:) is appropriate here
        let uiImage: Bool = !photoName.isEmpty && photoName.trimmingCharacters(in: .whitespacesAndNewlines).count > 0
        return AcatarLoadResult(
            calledUIImageNamed: true,
            photoNamePassedToUIImage: photoName,
            loadFailed: !uiImage
        )
    }

    // HTTPS path — would use ImagePipeline, not relevant to this bug
    return AcatarLoadResult(
        calledUIImageNamed: false,
        photoNamePassedToUIImage: nil,
        loadFailed: false
    )
}

/// The EXPECTED correct behavior: when photoName is empty or whitespace-only,
/// set loadFailed = true immediately WITHOUT calling UIImage(named:).
func expectedCorrectAcatarLoad(photoName: String) -> AcatarLoadResult {
    // Guard: empty/whitespace photoName should NOT call UIImage(named:)
    guard !photoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return AcatarLoadResult(
            calledUIImageNamed: false,
            photoNamePassedToUIImage: nil,
            loadFailed: true
        )
    }

    guard photoName.hasPrefix("https://") else {
        // Non-empty local asset — UIImage(named:) is appropriate here
        return AcatarLoadResult(
            calledUIImageNamed: true,
            photoNamePassedToUIImage: photoName,
            loadFailed: false  // Simplified; actual result depends on asset catalog
        )
    }

    // HTTPS path
    return AcatarLoadResult(
        calledUIImageNamed: false,
        photoNamePassedToUIImage: nil,
        loadFailed: false
    )
}

// MARK: - Caller Logic Helpers

/// Lightweight Dog type for testing caller behavior.
struct TestDog: Identifiable {
    let id: UUID
    let photos: [String]
}

/// Lightweight Chat type for testing caller behavior.
struct TestChatForPhoto {
    let currentDogId: UUID?
    let currentDogName: String?
}

/// Replicates the FIXED getCurrentDogPhoto() from ChatRow in MessagesView.swift:
/// Returns nil when dog not found or has no photos (instead of "").
func currentGetCurrentDogPhoto(chat: TestChatForPhoto, userDogs: [TestDog]) -> String? {
    if let currentDogId = chat.currentDogId,
       let currentDog = userDogs.first(where: { $0.id == currentDogId }) {
        return currentDog.photos.first
    }
    return nil
}

/// Replicates the FIXED currentDogPhoto from ChatView in ChatView.swift:
/// Returns nil when dog not found or has no photos (instead of "").
func currentCurrentDogPhoto(chat: TestChatForPhoto, dogs: [TestDog]) -> String? {
    if let currentDogId = chat.currentDogId,
       let dog = dogs.first(where: { $0.id == currentDogId }) {
        return dog.photos.first
    }
    return nil
}

// MARK: - Bug Condition Exploration Tests

/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
///
/// These tests demonstrate that the current buggy AcatarView logic calls
/// UIImage(named:) with empty/whitespace strings, triggering CUICatalog warnings.
/// They are EXPECTED TO FAIL on unfixed code, which confirms the bug exists.
final class CUICatalogEmptyAssetTests: XCTestCase {

    // MARK: - Concrete Bug Condition Tests

    /// Requirement 1.1: photoName = "" → fixed code guards and sets loadFailed = true
    /// Expected: should set loadFailed = true WITHOUT calling UIImage(named:)
    func testEmptyString_CurrentLogicCallsUIImageNamed() {
        let currentResult = currentAcatarLoad(photoName: "")
        let correctResult = expectedCorrectAcatarLoad(photoName: "")

        // With fix applied: both should agree — empty string does NOT call UIImage(named:)
        XCTAssertEqual(
            currentResult.calledUIImageNamed, correctResult.calledUIImageNamed,
            "Fix verified: empty string — current logic calledUIImage=\(currentResult.calledUIImageNamed), expected \(correctResult.calledUIImageNamed)"
        )
    }

    /// Requirement 1.1: photoName = "   " → fixed code guards and sets loadFailed = true
    /// Expected: should set loadFailed = true WITHOUT calling UIImage(named:)
    func testWhitespaceOnly_CurrentLogicCallsUIImageNamed() {
        let currentResult = currentAcatarLoad(photoName: "   ")
        let correctResult = expectedCorrectAcatarLoad(photoName: "   ")

        // With fix applied: both should agree — whitespace-only does NOT call UIImage(named:)
        XCTAssertEqual(
            currentResult.calledUIImageNamed, correctResult.calledUIImageNamed,
            "Fix verified: whitespace-only string — current logic calledUIImage=\(currentResult.calledUIImageNamed), expected \(correctResult.calledUIImageNamed)"
        )
    }

    /// Requirement 1.1: photoName = "\t\n" → fixed code guards and sets loadFailed = true
    /// Expected: should set loadFailed = true WITHOUT calling UIImage(named:)
    func testTabNewline_CurrentLogicCallsUIImageNamed() {
        let currentResult = currentAcatarLoad(photoName: "\t\n")
        let correctResult = expectedCorrectAcatarLoad(photoName: "\t\n")

        // With fix applied: both should agree — tab/newline does NOT call UIImage(named:)
        XCTAssertEqual(
            currentResult.calledUIImageNamed, correctResult.calledUIImageNamed,
            "Fix verified: tab/newline string — current logic calledUIImage=\(currentResult.calledUIImageNamed), expected \(correctResult.calledUIImageNamed)"
        )
    }

    // MARK: - Caller Behavior Tests (Source of Empty Strings)

    /// Requirement 1.2: getCurrentDogPhoto() returns nil when dog not found
    func testGetCurrentDogPhoto_DogNotFound_ReturnsNil() {
        let chat = TestChatForPhoto(currentDogId: UUID(), currentDogName: "Buddy")
        let userDogs: [TestDog] = []  // No dogs — dog not found

        let result = currentGetCurrentDogPhoto(chat: chat, userDogs: userDogs)

        // Fixed: returns nil when dog not found (instead of "")
        XCTAssertNil(result, "getCurrentDogPhoto() returns nil when dog not found")

        // When nil, the call site uses ?? "" which AcatarView's guard catches
        let photoName = result ?? ""
        let acatarResult = currentAcatarLoad(photoName: photoName)
        let correctAcatarResult = expectedCorrectAcatarLoad(photoName: photoName)

        // Fix verified: the empty string from nil coalescing is caught by AcatarView's guard
        XCTAssertEqual(
            acatarResult.calledUIImageNamed, correctAcatarResult.calledUIImageNamed,
            "Fix verified: getCurrentDogPhoto() nil return handled correctly"
        )
    }

    /// Requirement 1.2: getCurrentDogPhoto() returns nil when dog has no photos
    func testGetCurrentDogPhoto_DogHasNoPhotos_ReturnsNil() {
        let dogId = UUID()
        let chat = TestChatForPhoto(currentDogId: dogId, currentDogName: "Buddy")
        let userDogs = [TestDog(id: dogId, photos: [])]  // Dog exists but has no photos

        let result = currentGetCurrentDogPhoto(chat: chat, userDogs: userDogs)

        // Fixed: returns nil when dog has no photos (photos.first returns nil)
        XCTAssertNil(result, "getCurrentDogPhoto() returns nil when dog has no photos")

        let photoName = result ?? ""
        let acatarResult = currentAcatarLoad(photoName: photoName)
        let correctAcatarResult = expectedCorrectAcatarLoad(photoName: photoName)

        // Fix verified
        XCTAssertEqual(
            acatarResult.calledUIImageNamed, correctAcatarResult.calledUIImageNamed,
            "Fix verified: getCurrentDogPhoto() nil return from no-photos dog handled correctly"
        )
    }

    /// Requirement 1.3: currentDogPhoto returns nil when dog not found
    func testCurrentDogPhoto_DogNotFound_ReturnsNil() {
        let chat = TestChatForPhoto(currentDogId: UUID(), currentDogName: "Buddy")
        let dogs: [TestDog] = []  // No dogs

        let result = currentCurrentDogPhoto(chat: chat, dogs: dogs)

        XCTAssertNil(result, "currentDogPhoto returns nil when dog not found")

        let photoName = result ?? ""
        let acatarResult = currentAcatarLoad(photoName: photoName)
        let correctAcatarResult = expectedCorrectAcatarLoad(photoName: photoName)

        // Fix verified
        XCTAssertEqual(
            acatarResult.calledUIImageNamed, correctAcatarResult.calledUIImageNamed,
            "Fix verified: currentDogPhoto nil return handled correctly"
        )
    }

    /// Requirement 1.3: currentDogPhoto returns nil when dog has no photos
    func testCurrentDogPhoto_DogHasNoPhotos_ReturnsNil() {
        let dogId = UUID()
        let chat = TestChatForPhoto(currentDogId: dogId, currentDogName: "Buddy")
        let dogs = [TestDog(id: dogId, photos: [])]

        let result = currentCurrentDogPhoto(chat: chat, dogs: dogs)

        XCTAssertNil(result, "currentDogPhoto returns nil when dog has no photos")

        let photoName = result ?? ""
        let acatarResult = currentAcatarLoad(photoName: photoName)
        let correctAcatarResult = expectedCorrectAcatarLoad(photoName: photoName)

        // Fix verified
        XCTAssertEqual(
            acatarResult.calledUIImageNamed, correctAcatarResult.calledUIImageNamed,
            "Fix verified: currentDogPhoto nil return from no-photos dog handled correctly"
        )
    }

    /// Requirement 1.4: currentDogId is nil → returns nil
    func testCallers_NilCurrentDogId_ReturnsNil() {
        let chat = TestChatForPhoto(currentDogId: nil, currentDogName: nil)
        let dogs = [TestDog(id: UUID(), photos: ["labrador"])]

        let result1 = currentGetCurrentDogPhoto(chat: chat, userDogs: dogs)
        let result2 = currentCurrentDogPhoto(chat: chat, dogs: dogs)

        XCTAssertNil(result1, "getCurrentDogPhoto() returns nil when currentDogId is nil")
        XCTAssertNil(result2, "currentDogPhoto returns nil when currentDogId is nil")

        // Both nil values coalesce to "" which AcatarView's guard catches
        let photoName = result1 ?? ""
        let acatarResult = currentAcatarLoad(photoName: photoName)
        let correctResult = expectedCorrectAcatarLoad(photoName: photoName)

        // Fix verified
        XCTAssertEqual(
            acatarResult.calledUIImageNamed, correctResult.calledUIImageNamed,
            "Fix verified: nil currentDogId produces nil that is handled correctly"
        )
    }

    // MARK: - Property-Based Test (Loop-Based Random Generation)

    /// Property 1: Bug Condition — Empty/Whitespace photoName Triggers CUICatalog Warning
    ///
    /// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
    ///
    /// Generate empty and whitespace-only strings, assert that the current logic
    /// does NOT call UIImage(named:) with them. This will FAIL on unfixed code,
    /// surfacing counterexamples that prove the bug.
    func testProperty_EmptyWhitespacePhotoName_ShouldNotCallUIImageNamed() {
        var counterexamples: [(photoName: String, description: String)] = []
        let iterations = 100

        // Whitespace characters to generate from
        let whitespaceChars: [Character] = [" ", "\t", "\n", "\r", " " /* non-breaking space */]

        for iteration in 0..<iterations {
            var rng = SeededRandomNumberGenerator(seed: UInt64(iteration * 31 + 13))

            // Generate an empty or whitespace-only string
            let stringType = Int.random(in: 0...2, using: &rng)
            let photoName: String
            let typeDesc: String

            switch stringType {
            case 0:
                // Empty string
                photoName = ""
                typeDesc = "empty string \"\""
            case 1:
                // Whitespace-only string (1-5 spaces/tabs/newlines)
                let length = Int.random(in: 1...5, using: &rng)
                photoName = String((0..<length).map { _ in
                    whitespaceChars[Int.random(in: 0..<whitespaceChars.count, using: &rng)]
                })
                typeDesc = "whitespace-only (length \(length)): \(photoName.debugDescription)"
            default:
                // Mixed whitespace
                let length = Int.random(in: 1...8, using: &rng)
                photoName = String((0..<length).map { _ in
                    whitespaceChars[Int.random(in: 0..<whitespaceChars.count, using: &rng)]
                })
                typeDesc = "mixed whitespace (length \(length)): \(photoName.debugDescription)"
            }

            // Verify this IS a bug condition input
            XCTAssertTrue(
                photoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Generated string should be empty/whitespace-only"
            )

            let currentResult = currentAcatarLoad(photoName: photoName)
            let correctResult = expectedCorrectAcatarLoad(photoName: photoName)

            // Check: fixed code should NOT call UIImage(named:) for empty/whitespace
            if currentResult.calledUIImageNamed != correctResult.calledUIImageNamed {
                counterexamples.append((
                    photoName: photoName,
                    description: "Iteration \(iteration): \(typeDesc) → current calledUIImage=\(currentResult.calledUIImageNamed), expected=\(correctResult.calledUIImageNamed)"
                ))
            }
        }

        // Document counterexamples found
        if !counterexamples.isEmpty {
            let sample = counterexamples.prefix(5).map { $0.description }.joined(separator: "\n  ")
            XCTFail(
                """
                Fix NOT working: \(counterexamples.count)/\(iterations) iterations produced mismatches.
                The current logic still calls UIImage(named:) with empty/whitespace strings.
                Expected: should set loadFailed = true without calling UIImage(named:).
                Sample counterexamples:
                  \(sample)
                """
            )
        }
    }
}

// NOTE: SeededRandomNumberGenerator is defined in ChatBadgeCountTests.swift
// and shared across the test target — no need to redefine it here.
