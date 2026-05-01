//
//  OfflineQueueCoalescingTests.swift
//  CreamieTests
//
//  Unit tests for coalesceQueuedUpdates
//

import XCTest
import CoreLocation
@testable import Creamie

final class OfflineQueueCoalescingTests: XCTestCase {

    // MARK: - Helpers

    private func makeUpdate(dogId: UUID, lat: Double = 0.0, lon: Double = 0.0, timestamp: Date) -> QueuedLocationUpdate {
        let location = CLLocation(latitude: lat, longitude: lon)
        return QueuedLocationUpdate(dogId: dogId, location: location, timestamp: timestamp)
    }

    // MARK: - Tests

    func testEmptyQueueReturnsEmpty() {
        let result = coalesceQueuedUpdates([])
        XCTAssertTrue(result.isEmpty)
    }

    func testSingleUpdateReturnsSameUpdate() {
        let dogId = UUID()
        let now = Date()
        let update = makeUpdate(dogId: dogId, timestamp: now)

        let result = coalesceQueuedUpdates([update])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.dogId, dogId)
        XCTAssertEqual(result.first?.timestamp, now)
    }

    func testMultipleUpdatesForSameDogKeepsMostRecent() {
        let dogId = UUID()
        let old = Date(timeIntervalSince1970: 1000)
        let mid = Date(timeIntervalSince1970: 2000)
        let recent = Date(timeIntervalSince1970: 3000)

        let updates = [
            makeUpdate(dogId: dogId, lat: 1.0, lon: 1.0, timestamp: old),
            makeUpdate(dogId: dogId, lat: 2.0, lon: 2.0, timestamp: recent),
            makeUpdate(dogId: dogId, lat: 1.5, lon: 1.5, timestamp: mid),
        ]

        let result = coalesceQueuedUpdates(updates)

        XCTAssertEqual(result.count, 1)
        let entry = try! XCTUnwrap(result.first)
        XCTAssertEqual(entry.dogId, dogId)
        XCTAssertEqual(entry.timestamp, recent)
        XCTAssertEqual(entry.location.coordinate.latitude, 2.0, accuracy: 0.001)
    }

    func testMultipleDogsEachKeepMostRecent() {
        let dog1 = UUID()
        let dog2 = UUID()
        let dog3 = UUID()

        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)

        let updates = [
            makeUpdate(dogId: dog1, lat: 10.0, lon: 10.0, timestamp: early),
            makeUpdate(dogId: dog2, lat: 20.0, lon: 20.0, timestamp: late),
            makeUpdate(dogId: dog1, lat: 11.0, lon: 11.0, timestamp: late),
            makeUpdate(dogId: dog3, lat: 30.0, lon: 30.0, timestamp: early),
            makeUpdate(dogId: dog2, lat: 21.0, lon: 21.0, timestamp: early),
        ]

        let result = coalesceQueuedUpdates(updates)

        XCTAssertEqual(result.count, 3)

        let resultByDog = Dictionary(uniqueKeysWithValues: result.map { ($0.dogId, $0) })

        // Dog1: should keep the late update (lat 11.0)
        let dog1Entry = try! XCTUnwrap(resultByDog[dog1])
        XCTAssertEqual(dog1Entry.timestamp, late)
        XCTAssertEqual(dog1Entry.location.coordinate.latitude, 11.0, accuracy: 0.001)

        // Dog2: should keep the late update (lat 20.0)
        let dog2Entry = try! XCTUnwrap(resultByDog[dog2])
        XCTAssertEqual(dog2Entry.timestamp, late)
        XCTAssertEqual(dog2Entry.location.coordinate.latitude, 20.0, accuracy: 0.001)

        // Dog3: only one update
        let dog3Entry = try! XCTUnwrap(resultByDog[dog3])
        XCTAssertEqual(dog3Entry.timestamp, early)
        XCTAssertEqual(dog3Entry.location.coordinate.latitude, 30.0, accuracy: 0.001)
    }

    func testUpdatesWithSameTimestampKeepsFirst() {
        let dogId = UUID()
        let sameTime = Date(timeIntervalSince1970: 5000)

        let updates = [
            makeUpdate(dogId: dogId, lat: 1.0, lon: 1.0, timestamp: sameTime),
            makeUpdate(dogId: dogId, lat: 2.0, lon: 2.0, timestamp: sameTime),
        ]

        let result = coalesceQueuedUpdates(updates)

        XCTAssertEqual(result.count, 1)
        let entry = try! XCTUnwrap(result.first)
        XCTAssertEqual(entry.dogId, dogId)
        // With equal timestamps, the first one is kept (> is strict)
        XCTAssertEqual(entry.location.coordinate.latitude, 1.0, accuracy: 0.001)
    }
}
