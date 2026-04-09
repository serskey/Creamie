# Implementation Plan: Real-time Dog Location Tracking

## Overview

This implementation plan breaks down the real-time dog location tracking feature into discrete, incremental coding tasks. Each task builds on previous work, with testing integrated throughout to validate correctness early. The implementation follows a bottom-up approach: core tracking logic first, then integration with existing services, and finally UI enhancements.

## Tasks

- [x] 1. Set up tracking infrastructure and data models
  - Create `DogLocationTracker.swift` with basic structure and configuration
  - Create `TrackingPreferences.swift` model for persistence
  - Create `TrackingPreferencesStore.swift` for UserDefaults storage
  - Add `isLocationTrackingEnabled` and `lastLocationUpdate` properties to Dog model
  - _Requirements: 2.5, 6.1_

- [ ]* 1.1 Write property test for tracking preferences persistence
  - **Property 8: Tracking preferences persist across restarts**
  - **Validates: Requirements 2.5, 7.5**

- [x] 2. Implement core location tracking logic
  - [x] 2.1 Implement `DogLocationTracker` initialization and state management
    - Add published properties for tracking status and errors
    - Implement `startTracking(for:)` and `stopTracking(for:)` methods
    - Add tracking status dictionary to manage multiple dogs
    - _Requirements: 1.1, 2.2, 2.3_

  - [ ]* 2.2 Write property test for tracking activation
    - **Property 1: Tracking activation starts monitoring**
    - **Validates: Requirements 1.1, 2.2**

  - [x] 2.3 Implement location update filtering and threshold logic
    - Add `shouldSendUpdate(for:location:)` method with 10-meter threshold
    - Implement distance calculation between locations
    - Add last update time tracking per dog
    - _Requirements: 1.2, 4.3_

  - [ ]* 2.4 Write property test for distance threshold
    - **Property 2: Distance threshold triggers updates**
    - **Validates: Requirements 1.2, 4.3**

  - [x] 2.5 Implement location accuracy filtering
    - Add accuracy threshold check (50 meters)
    - Implement logic to wait for better accuracy
    - Add last known good location fallback
    - _Requirements: 5.1, 5.2, 5.3_

  - [ ]* 2.6 Write property test for accuracy filtering
    - **Property 15: Accuracy filtering**
    - **Validates: Requirements 5.1, 5.2**

  - [ ]* 2.7 Write property test for last known location fallback
    - **Property 16: Last known location fallback**
    - **Validates: Requirements 5.3**

- [x] 3. Checkpoint - Ensure core tracking tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement background and battery optimization
  - [x] 4.1 Add background/foreground mode switching
    - Implement `handleBackgroundTransition()` method
    - Implement `handleForegroundTransition()` method
    - Add observers for app state changes
    - Configure significant location change monitoring for background
    - _Requirements: 1.4, 1.5, 4.1_

  - [ ]* 4.2 Write property test for background mode
    - **Property 4: Background mode uses reduced frequency**
    - **Validates: Requirements 1.4, 4.1**

  - [ ]* 4.3 Write property test for foreground mode
    - **Property 5: Foreground mode uses high accuracy**
    - **Validates: Requirements 1.5**

  - [x] 4.4 Implement stationary detection and adaptive frequency
    - Add `isDeviceStationary()` method
    - Implement reduced update frequency for stationary devices
    - Add timer-based updates for stationary mode
    - _Requirements: 4.2_

  - [ ]* 4.5 Write property test for stationary detection
    - **Property 13: Stationary detection reduces frequency**
    - **Validates: Requirements 4.2**

  - [x] 4.6 Implement battery-aware optimization
    - Add `adjustForBatteryLevel()` method
    - Monitor battery level changes
    - Switch to low-power mode when battery < 20%
    - _Requirements: 4.4_

  - [ ]* 4.7 Write property test for low battery mode
    - **Property 14: Low battery triggers power saving**
    - **Validates: Requirements 4.4**

- [x] 5. Integrate with LocationManager
  - [x] 5.1 Enhance LocationManager for background support
    - Add `requestAlwaysAuthorization()` method
    - Add `startSignificantLocationChangeMonitoring()` method
    - Add `stopSignificantLocationChangeMonitoring()` method
    - Add `allowsBackgroundLocationUpdates` property
    - Update Info.plist with background location usage description
    - _Requirements: 1.4, 4.1_

  - [x] 5.2 Connect DogLocationTracker to LocationManager
    - Implement `handleLocationUpdate(_:)` in DogLocationTracker
    - Subscribe to LocationManager location updates
    - Filter and process location updates for all tracked dogs
    - _Requirements: 1.1, 1.2_

  - [ ]* 5.3 Write unit tests for LocationManager integration
    - Test location update flow from LocationManager to DogLocationTracker
    - Test background/foreground mode switching
    - _Requirements: 1.4, 1.5_

- [x] 6. Checkpoint - Ensure location integration tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement backend communication and error handling
  - [x] 7.1 Implement location update sending
    - Add `sendLocationUpdate(dogId:location:)` async method
    - Create `LocationUpdateRequest` with all required fields
    - Call `DogLocationService.updateDogLocation()`
    - _Requirements: 1.3_

  - [ ]* 7.2 Write property test for location update structure
    - **Property 3: Location updates contain required fields**
    - **Validates: Requirements 1.3**

  - [x] 7.3 Implement retry logic with exponential backoff
    - Add retry counter and backoff calculation
    - Implement retry loop with max 3 attempts
    - Use exponential backoff (2^n seconds)
    - _Requirements: 7.1_

  - [ ]* 7.4 Write property test for retry behavior
    - **Property 19: Retry with exponential backoff**
    - **Validates: Requirements 7.1**

  - [x] 7.5 Implement offline queuing
    - Create queue for pending location updates
    - Detect network connectivity changes
    - Send queued updates when connectivity restored
    - _Requirements: 7.2_

  - [ ]* 7.6 Write property test for offline queuing
    - **Property 20: Offline queuing and replay**
    - **Validates: Requirements 7.2**

  - [x] 7.7 Implement error resilience
    - Handle backend errors without stopping tracking
    - Log errors appropriately
    - Continue tracking on non-fatal errors
    - _Requirements: 7.3_

  - [ ]* 7.8 Write property test for error resilience
    - **Property 21: Error resilience**
    - **Validates: Requirements 7.3**

  - [x] 7.9 Implement permission revocation handling
    - Detect location permission changes
    - Stop tracking gracefully when permissions revoked
    - Notify user of permission issues
    - _Requirements: 7.4_

  - [ ]* 7.10 Write property test for permission handling
    - **Property 22: Permission revocation handling**
    - **Validates: Requirements 7.4**

- [x] 8. Implement multi-dog support
  - [x] 8.1 Add independent tracking control per dog
    - Ensure tracking state is per-dog, not global
    - Implement logic to track multiple dogs simultaneously
    - Handle starting/stopping individual dogs
    - _Requirements: 6.1, 6.3_

  - [ ]* 8.2 Write property test for independent tracking
    - **Property 17: Independent tracking per dog**
    - **Validates: Requirements 6.1, 6.3**

  - [x] 8.3 Implement simultaneous updates for multiple dogs
    - Send location updates for all tracked dogs on location change
    - Ensure updates are independent and non-blocking
    - _Requirements: 6.2_

  - [ ]* 8.4 Write property test for multi-dog updates
    - **Property 18: Multi-dog simultaneous updates**
    - **Validates: Requirements 6.2**

  - [ ]* 8.5 Write property test for independent updates
    - **Property 12: Independent dog location updates**
    - **Validates: Requirements 3.4**

- [x] 9. Checkpoint - Ensure backend integration tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Integrate with DogProfileViewModel
  - [x] 10.1 Add DogLocationTracker to DogProfileViewModel
    - Initialize DogLocationTracker instance
    - Add `toggleLocationTracking(for:enabled:)` method
    - Add `getLocationTrackingStatus(for:)` method
    - Add `isLocationTrackingEnabled(for:)` method
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 10.2 Implement tracking toggle logic
    - Call DogLocationTracker start/stop methods
    - Update backend online status
    - Persist tracking preferences
    - _Requirements: 2.2, 2.3, 2.4_

  - [ ]* 10.3 Write property test for tracking deactivation
    - **Property 7: Tracking deactivation stops monitoring and marks offline**
    - **Validates: Requirements 2.3, 2.4**

  - [x] 10.4 Load tracking preferences on app start
    - Load saved preferences from TrackingPreferencesStore
    - Resume tracking for dogs that were previously enabled
    - _Requirements: 2.5, 7.5_

  - [ ]* 10.5 Write unit tests for ViewModel integration
    - Test toggle tracking on/off
    - Test loading preferences on startup
    - Test multi-dog tracking state management
    - _Requirements: 2.1, 2.2, 2.3, 6.4_

- [x] 11. Update UI views for tracking control
  - [x] 11.1 Add tracking toggle to DogProfilesView
    - Add toggle switch for each dog card
    - Bind toggle to tracking enabled state
    - Show tracking status indicator
    - _Requirements: 2.1, 6.1_

  - [x] 11.2 Add tracking toggle to EditDogView
    - Add toggle control in edit view
    - Update tracking state when toggled
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 11.3 Add tracking status indicator to DogCard
    - Show visual indicator when tracking is active
    - Display last update time
    - Show error state if tracking fails
    - _Requirements: 2.1_

  - [ ]* 11.4 Write property test for profile status display
    - **Property 6: Profile displays tracking status**
    - **Validates: Requirements 2.1, 6.4**

- [x] 12. Enhance MapViewModel for real-time updates
  - [x] 12.1 Subscribe to real-time location updates
    - Connect MapViewModel to DogLocationService WebSocket
    - Handle incoming location update messages
    - Update dog positions in nearbyDogs array
    - _Requirements: 3.1_

  - [ ]* 12.2 Write property test for map updates
    - **Property 9: Map updates reflect location changes**
    - **Validates: Requirements 3.1**

  - [x] 12.3 Implement online/offline status handling
    - Remove or dim markers for offline dogs
    - Add markers for dogs coming online
    - Update marker appearance based on status
    - _Requirements: 3.2, 3.3_

  - [ ]* 12.4 Write property test for offline dog removal
    - **Property 10: Offline dogs are removed from map**
    - **Validates: Requirements 3.2**

  - [ ]* 12.5 Write property test for online dog display
    - **Property 11: Online dogs appear on map**
    - **Validates: Requirements 3.3**

- [x] 13. Final integration and polish
  - [x] 13.1 Add permission request flow
    - Request "Always" authorization when tracking enabled
    - Show alert explaining why "Always" is needed
    - Handle permission denial gracefully
    - _Requirements: 1.4, 7.4_

  - [x] 13.2 Add user notifications for tracking events
    - Notify when tracking starts/stops
    - Notify on permission issues
    - Notify on persistent errors
    - _Requirements: 7.4_

  - [x] 13.3 Add analytics and logging
    - Log tracking start/stop events
    - Log location update frequency
    - Log errors and retry attempts
    - Track battery impact metrics
    - _Requirements: 7.3_

  - [ ]* 13.4 Write integration tests for full flow
    - Test complete flow: enable → location change → backend → map
    - Test app lifecycle scenarios
    - Test multi-dog scenarios
    - _Requirements: All_

- [x] 14. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties across all inputs
- Unit tests validate specific examples, edge cases, and integration points
- The implementation follows a bottom-up approach: core logic → services → UI
- Background location requires "Always" authorization and Info.plist configuration
- WebSocket integration leverages existing DogLocationService infrastructure
