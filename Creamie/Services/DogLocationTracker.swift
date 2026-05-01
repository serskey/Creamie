import Foundation
import CoreLocation
import Combine
import UIKit
import Network
import os

/// Status of location tracking for a dog
enum TrackingStatus: Equatable {
    case active
    case paused
    case stopped
    case error(String)
}

/// Queued location update for offline scenarios
struct QueuedLocationUpdate: Codable {
    let dogId: UUID
    let location: CLLocation
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case dogId
        case latitude
        case longitude
        case altitude
        case horizontalAccuracy
        case verticalAccuracy
        case timestamp
    }
    
    init(dogId: UUID, location: CLLocation, timestamp: Date = Date()) {
        self.dogId = dogId
        self.location = location
        self.timestamp = timestamp
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dogId, forKey: .dogId)
        try container.encode(location.coordinate.latitude, forKey: .latitude)
        try container.encode(location.coordinate.longitude, forKey: .longitude)
        try container.encode(location.altitude, forKey: .altitude)
        try container.encode(location.horizontalAccuracy, forKey: .horizontalAccuracy)
        try container.encode(location.verticalAccuracy, forKey: .verticalAccuracy)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dogId = try container.decode(UUID.self, forKey: .dogId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        let altitude = try container.decode(Double.self, forKey: .altitude)
        let horizontalAccuracy = try container.decode(Double.self, forKey: .horizontalAccuracy)
        let verticalAccuracy = try container.decode(Double.self, forKey: .verticalAccuracy)
        
        location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: timestamp
        )
    }
}

/// Coalesce queued location updates to keep only the most recent update per dog ID.
/// This reduces redundant network requests when connectivity is restored after an offline period.
func coalesceQueuedUpdates(_ updates: [QueuedLocationUpdate]) -> [QueuedLocationUpdate] {
    var mostRecentByDog: [UUID: QueuedLocationUpdate] = [:]
    
    for update in updates {
        if let existing = mostRecentByDog[update.dogId] {
            if update.timestamp > existing.timestamp {
                mostRecentByDog[update.dogId] = update
            }
        } else {
            mostRecentByDog[update.dogId] = update
        }
    }
    
    return Array(mostRecentByDog.values)
}

/// Main service for tracking dog locations
@MainActor
class DogLocationTracker: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var trackingStatus: [UUID: TrackingStatus] = [:]
    @Published var lastUpdateTime: [UUID: Date] = [:]
    @Published var updateError: Error?
    
    // Permission state
    @Published var needsAlwaysPermissionExplanation = false
    @Published var permissionDenied = false
    @Published var permissionDeniedMessage = ""
    
    /// Dog ID pending permission approval before tracking starts
    var pendingTrackingDogId: UUID?
    
    /// Notification manager for user-facing tracking event notifications
    let notificationManager = TrackingNotificationManager()
    
    /// Optional mapping of dog IDs to display names (set by the view model)
    var dogNames: [UUID: String] = [:]
    
    // MARK: - Configuration
    struct TrackingConfig {
        let minimumDistance: CLLocationDistance = 10.0 // meters
        let stationaryUpdateInterval: TimeInterval = 60.0 // seconds
        let movingUpdateInterval: TimeInterval = 5.0 // seconds
        let locationAccuracyThreshold: CLLocationAccuracy = 50.0 // meters
        let stationaryThreshold: TimeInterval = 300.0 // 5 minutes
        let maxRetries: Int = 3
        let retryBackoffBase: TimeInterval = 2.0
        let lowBatteryThreshold: Float = 0.20
    }
    
    let config = TrackingConfig()
    
    // MARK: - Logging
    private static let subsystem = "com.creamie.locationtracking"
    private let trackingLogger = Logger(subsystem: subsystem, category: "tracking")
    private let locationLogger = Logger(subsystem: subsystem, category: "location")
    private let networkLogger = Logger(subsystem: subsystem, category: "network")
    private let batteryLogger = Logger(subsystem: subsystem, category: "battery")
    private let permissionLogger = Logger(subsystem: subsystem, category: "permission")
    
    // MARK: - Private Properties
    private var trackedDogs: Set<UUID> = []
    private var lastLocations: [UUID: CLLocation] = [:]
    private var lastKnownGoodLocations: [UUID: CLLocation] = [:]
    private var preferencesStore: TrackingPreferencesStore
    private var locationManager: CLLocationManager
    private var isInBackground = false
    private var stationaryTimer: Timer?
    private var lastMovementTime: Date = Date()
    private var locationUpdateCancellable: AnyCancellable?
    
    // Network connectivity monitoring
    private var networkMonitor: NWPathMonitor?
    private var isNetworkAvailable = true
    
    // Offline queue
    private var offlineQueue: [QueuedLocationUpdate] = []
    private let offlineQueueKey = "dog_location_offline_queue"
    private var isProcessingQueue = false
    
    // MARK: - Initialization
    override init() {
        self.preferencesStore = TrackingPreferencesStore()
        self.locationManager = CLLocationManager()
        super.init()
        setupLocationManager()
        setupAppStateObservers()
        setupBatteryMonitoring()
        setupNetworkMonitoring()
        loadOfflineQueue()
    }
    
    init(preferencesStore: TrackingPreferencesStore = TrackingPreferencesStore()) {
        self.preferencesStore = preferencesStore
        self.locationManager = CLLocationManager()
        super.init()
        setupLocationManager()
        setupAppStateObservers()
        setupBatteryMonitoring()
        setupNetworkMonitoring()
        loadOfflineQueue()
    }
    
    /// Initialize with an external LocationManager (for integration with app-wide location manager)
    init(locationManager: CLLocationManager, preferencesStore: TrackingPreferencesStore = TrackingPreferencesStore()) {
        self.preferencesStore = preferencesStore
        self.locationManager = locationManager
        super.init()
        setupLocationManager()
        setupAppStateObservers()
        setupBatteryMonitoring()
        setupNetworkMonitoring()
        loadOfflineQueue()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.isBatteryMonitoringEnabled = false
        stationaryTimer?.invalidate()
        locationUpdateCancellable?.cancel()
        networkMonitor?.cancel()
    }
    
    // MARK: - Location Manager Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    // MARK: - Public Interface
    
    /// Possible results of a permission check before starting tracking
    enum PermissionCheckResult {
        case authorized
        case needsAlwaysExplanation
        case denied(String)
    }
    
    /// Check if we have sufficient permissions to start tracking.
    /// Returns the result so the caller can show appropriate UI.
    func checkPermissionForTracking() -> PermissionCheckResult {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedAlways:
            return .authorized
            
        case .authorizedWhenInUse:
            // Need to upgrade to "Always" for background tracking
            return .needsAlwaysExplanation
            
        case .notDetermined:
            // Will request when tracking starts — treat as needing explanation
            return .needsAlwaysExplanation
            
        case .denied, .restricted:
            return .denied("Location access is denied. Please enable location permissions in Settings to track your dog's location.")
            
        @unknown default:
            return .denied("Unable to determine location permission status.")
        }
    }
    
    /// Request "Always" authorization. Call this after the user acknowledges the explanation alert.
    func requestAlwaysAuthorization(for dogId: UUID) {
        pendingTrackingDogId = dogId
        
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            // First request — iOS will show WhenInUse prompt, then we can escalate
            locationManager.requestAlwaysAuthorization()
        } else if status == .authorizedWhenInUse {
            // Escalate to Always
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    /// Start tracking location for a specific dog.
    /// Caller should check permissions first via `checkPermissionForTracking()`.
    func startTracking(for dogId: UUID) {
        let wasEmpty = trackedDogs.isEmpty
        
        trackedDogs.insert(dogId)
        trackingStatus[dogId] = .active
        
        // Save preference
        let preference = TrackingPreferences(
            dogId: dogId,
            isEnabled: true,
            lastKnownLocation: lastLocations[dogId]?.coordinate,
            lastUpdateTime: Date()
        )
        preferencesStore.savePreference(preference)
        
        // Start location updates if this is the first dog being tracked
        if wasEmpty {
            notificationManager.requestNotificationPermission()
            startLocationMonitoring()
        }
        
        notificationManager.notifyTrackingStarted(dogName: dogNames[dogId])
        trackingLogger.info("Started tracking for dog \(dogId.uuidString, privacy: .public) at \(Date().timeIntervalSince1970, privacy: .public)")
    }
    
    /// Stop tracking location for a specific dog
    func stopTracking(for dogId: UUID) {
        trackedDogs.remove(dogId)
        trackingStatus[dogId] = .stopped
        lastLocations.removeValue(forKey: dogId)
        lastKnownGoodLocations.removeValue(forKey: dogId)
        lastUpdateTime.removeValue(forKey: dogId)
        
        // Save preference
        let preference = TrackingPreferences(
            dogId: dogId,
            isEnabled: false,
            lastKnownLocation: nil,
            lastUpdateTime: nil
        )
        preferencesStore.savePreference(preference)
        
        // Stop location updates if no dogs are being tracked
        if trackedDogs.isEmpty {
            stopLocationMonitoring()
        }
        
        notificationManager.notifyTrackingStopped(dogName: dogNames[dogId])
        trackingLogger.info("Stopped tracking for dog \(dogId.uuidString, privacy: .public) at \(Date().timeIntervalSince1970, privacy: .public)")
    }
    
    /// Stop tracking for all dogs
    func stopAllTracking() {
        let allDogIds = Array(trackedDogs)
        for dogId in allDogIds {
            stopTracking(for: dogId)
        }
    }
    
    /// Start location monitoring
    private func startLocationMonitoring() {
        // Request appropriate authorization
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse {
            // Request upgrade to always for background tracking
            locationManager.requestAlwaysAuthorization()
        }
        
        // Start location updates
        if isInBackground {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            locationManager.startUpdatingLocation()
            startStationaryDetection()
        }
        
        locationLogger.info("Started location monitoring, background=\(self.isInBackground, privacy: .public), trackedDogs=\(self.trackedDogs.count, privacy: .public)")
    }
    
    /// Stop location monitoring
    private func stopLocationMonitoring() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.allowsBackgroundLocationUpdates = false
        stationaryTimer?.invalidate()
        stationaryTimer = nil
        
        locationLogger.info("Stopped location monitoring")
    }
    
    /// Check if currently tracking a specific dog
    func isTracking(dogId: UUID) -> Bool {
        return trackedDogs.contains(dogId)
    }
    
    /// Get tracking status for a specific dog
    func getTrackingStatus(for dogId: UUID) -> TrackingStatus? {
        return trackingStatus[dogId]
    }
    
    /// Get last known good location for a specific dog
    func getLastKnownGoodLocation(for dogId: UUID) -> CLLocation? {
        return lastKnownGoodLocations[dogId]
    }
    
    /// Subscribe to location updates from an external LocationManager
    /// This allows integration with the app's shared LocationManager
    func subscribeToLocationUpdates(from externalLocationManager: LocationManager) {
        locationUpdateCancellable = externalLocationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                Task { @MainActor [weak self] in
                    self?.handleLocationUpdate(location)
                }
            }
        
        locationLogger.info("Subscribed to external LocationManager updates")
    }
    
    // MARK: - Private Methods
    
    // MARK: - Network Monitoring
    
    /// Setup network connectivity monitoring
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let wasAvailable = self?.isNetworkAvailable ?? true
                self?.isNetworkAvailable = path.status == .satisfied
                
                if !wasAvailable && (self?.isNetworkAvailable ?? false) {
                    self?.networkLogger.info("Network connectivity restored")
                    await self?.processOfflineQueue()
                } else if wasAvailable && !(self?.isNetworkAvailable ?? true) {
                    self?.networkLogger.warning("Network connectivity lost")
                }
            }
        }
        
        networkMonitor?.start(queue: queue)
    }
    
    // MARK: - Offline Queue Management
    
    /// Load offline queue from persistent storage
    private func loadOfflineQueue() {
        guard let data = UserDefaults.standard.data(forKey: offlineQueueKey),
              let queue = try? JSONDecoder().decode([QueuedLocationUpdate].self, from: data) else {
            offlineQueue = []
            return
        }
        
        offlineQueue = queue
        networkLogger.info("Loaded \(self.offlineQueue.count, privacy: .public) queued location updates")
    }
    
    /// Save offline queue to persistent storage
    private func saveOfflineQueue() {
        guard let data = try? JSONEncoder().encode(offlineQueue) else {
            networkLogger.error("Failed to encode offline queue")
            return
        }
        
        UserDefaults.standard.set(data, forKey: offlineQueueKey)
    }
    
    /// Add location update to offline queue
    private func queueLocationUpdate(dogId: UUID, location: CLLocation) {
        let queuedUpdate = QueuedLocationUpdate(dogId: dogId, location: location)
        offlineQueue.append(queuedUpdate)
        saveOfflineQueue()
        networkLogger.info("Queued location update for dog \(dogId.uuidString, privacy: .public), queueSize=\(self.offlineQueue.count, privacy: .public)")
    }
    
    /// Process queued location updates when connectivity is restored
    private func processOfflineQueue() async {
        guard !offlineQueue.isEmpty, !isProcessingQueue else { return }
        
        isProcessingQueue = true
        networkLogger.info("Processing \(self.offlineQueue.count, privacy: .public) queued location updates")
        
        // Coalesce updates: keep only the most recent update per dog ID
        let coalescedUpdates = coalesceQueuedUpdates(offlineQueue)
        networkLogger.info("Coalesced \(self.offlineQueue.count, privacy: .public) updates to \(coalescedUpdates.count, privacy: .public) (one per dog)")
        
        var successfulDogIds: Set<UUID> = []
        
        for queuedUpdate in coalescedUpdates {
            do {
                try await DogLocationService.shared.updateDogLocation(
                    dogId: queuedUpdate.dogId,
                    location: queuedUpdate.location.coordinate
                )
                successfulDogIds.insert(queuedUpdate.dogId)
                networkLogger.info("Sent queued update for dog \(queuedUpdate.dogId.uuidString, privacy: .public)")
            } catch {
                networkLogger.error("Failed to send queued update for dog \(queuedUpdate.dogId.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                // Keep the most recent update for failed dogs in queue for next attempt
            }
        }
        
        // Remove all updates for successfully sent dogs (all older updates are now irrelevant)
        offlineQueue.removeAll { update in
            successfulDogIds.contains(update.dogId)
        }
        
        // For dogs that failed, coalesce remaining queue entries to keep only the most recent
        offlineQueue = coalesceQueuedUpdates(offlineQueue)
        
        saveOfflineQueue()
        isProcessingQueue = false
        
        networkLogger.info("Queue processing complete, remaining=\(self.offlineQueue.count, privacy: .public)")
    }
    
    /// Handle incoming location update (can be called externally or from delegate)
    func handleLocationUpdate(_ location: CLLocation) {
        // Process location update for all tracked dogs
        for dogId in trackedDogs {
            // Check if location has acceptable accuracy
            if location.horizontalAccuracy <= config.locationAccuracyThreshold {
                // Good accuracy - store as last known good location
                lastKnownGoodLocations[dogId] = location
                
                // Check if we should send this update
                if shouldSendUpdate(for: dogId, location: location) {
                    let distance = lastLocations[dogId].map { location.distance(from: $0) } ?? 0
                    let timeSinceLast = lastUpdateTime[dogId].map { Date().timeIntervalSince($0) } ?? 0
                    locationLogger.debug("Update triggered for dog \(dogId.uuidString, privacy: .public): distance=\(distance, privacy: .public)m, timeSinceLast=\(timeSinceLast, privacy: .public)s")
                    
                    lastLocations[dogId] = location
                    lastUpdateTime[dogId] = Date()
                    
                    // Send location update to backend
                    Task {
                        await sendLocationUpdate(dogId: dogId, location: location)
                    }
                }
            } else {
                // Poor accuracy - wait for better reading
                locationLogger.warning("Poor accuracy \(location.horizontalAccuracy, privacy: .public)m for dog \(dogId.uuidString, privacy: .public), waiting for better reading")
                
                // Use last known good location as fallback if available and not too old
                if let lastGoodLocation = lastKnownGoodLocations[dogId] {
                    let timeSinceGoodLocation = Date().timeIntervalSince(lastGoodLocation.timestamp)
                    
                    // If last good location is recent (< 5 minutes), use it
                    if timeSinceGoodLocation < 300 {
                        locationLogger.debug("Using last known good location from \(Int(timeSinceGoodLocation), privacy: .public)s ago for dog \(dogId.uuidString, privacy: .public)")
                        
                        if shouldSendUpdate(for: dogId, location: lastGoodLocation) {
                            lastLocations[dogId] = lastGoodLocation
                            lastUpdateTime[dogId] = Date()
                            
                            Task {
                                await sendLocationUpdate(dogId: dogId, location: lastGoodLocation)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Determine if location update should be sent for a dog
    /// Note: Accuracy filtering is handled in handleLocationUpdate before calling this method
    private func shouldSendUpdate(for dogId: UUID, location: CLLocation) -> Bool {
        // If no previous location, send update
        guard let lastLocation = lastLocations[dogId] else {
            return true
        }
        
        // Calculate distance from last location
        let distance = location.distance(from: lastLocation)
        
        // Check if distance threshold is met
        if distance >= config.minimumDistance {
            return true
        }
        
        // Check if enough time has passed since last update (for stationary devices)
        if let lastUpdate = lastUpdateTime[dogId] {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            // If device is stationary (distance < threshold) and enough time passed, send update
            if timeSinceLastUpdate >= config.stationaryUpdateInterval {
                return true
            }
        }
        
        return false
    }
    
    /// Send location update to backend with retry logic and offline queuing
    private func sendLocationUpdate(dogId: UUID, location: CLLocation) async {
        locationLogger.debug("Sending location update for dog \(dogId.uuidString, privacy: .public): lat=\(location.coordinate.latitude, privacy: .public), lon=\(location.coordinate.longitude, privacy: .public), accuracy=\(location.horizontalAccuracy, privacy: .public)m")
        
        // Check network connectivity
        if !isNetworkAvailable {
            networkLogger.info("No network connectivity - queuing update for dog \(dogId.uuidString, privacy: .public)")
            queueLocationUpdate(dogId: dogId, location: location)
            return
        }
        
        // Retry with exponential backoff
        var attempt = 0
        var lastError: Error?
        
        while attempt < config.maxRetries {
            do {
                // Call DogLocationService to update location
                try await DogLocationService.shared.updateDogLocation(
                    dogId: dogId,
                    location: location.coordinate
                )
                
                locationLogger.debug("Location update sent for dog \(dogId.uuidString, privacy: .public), attempt=\(attempt + 1, privacy: .public)")
                
                // Clear any previous errors
                updateError = nil
                return
                
            } catch {
                lastError = error
                attempt += 1
                
                if attempt < config.maxRetries {
                    // Calculate exponential backoff delay: 2^attempt seconds
                    let delay = pow(config.retryBackoffBase, Double(attempt))
                    networkLogger.warning("Location update failed for dog \(dogId.uuidString, privacy: .public), attempt=\(attempt, privacy: .public)/\(self.config.maxRetries, privacy: .public), retryIn=\(delay, privacy: .public)s, error=\(error.localizedDescription, privacy: .public)")
                    
                    // Wait before retrying
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    networkLogger.error("Location update failed for dog \(dogId.uuidString, privacy: .public) after \(self.config.maxRetries, privacy: .public) attempts: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        
        // If all retries failed, queue the update for later
        if lastError != nil {
            networkLogger.error("All retries exhausted for dog \(dogId.uuidString, privacy: .public), queuing for later retry")
            queueLocationUpdate(dogId: dogId, location: location)
            notificationManager.notifyPersistentError(
                detail: "Failed to send location update after \(config.maxRetries) attempts. Updates will be retried automatically."
            )
        }
        
        // Store the error but don't stop tracking
        updateError = lastError
        
        // Continue tracking despite error - error resilience
    }
    
    // MARK: - App State Management
    
    /// Setup observers for app state changes
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        Task { @MainActor in
            handleBackgroundTransition()
        }
    }
    
    @objc private func appWillEnterForeground() {
        Task { @MainActor in
            handleForegroundTransition()
        }
    }
    
    /// Handle app transitioning to background
    private func handleBackgroundTransition() {
        guard !trackedDogs.isEmpty else { return }
        
        isInBackground = true
        trackingLogger.info("App entering background - switching to significant location changes, trackedDogs=\(self.trackedDogs.count, privacy: .public)")
        
        // Switch to significant location change monitoring for battery efficiency
        locationManager.stopUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Pause stationary timer in background
        stationaryTimer?.invalidate()
        stationaryTimer = nil
    }
    
    /// Handle app transitioning to foreground
    private func handleForegroundTransition() {
        guard !trackedDogs.isEmpty else { return }
        
        isInBackground = false
        trackingLogger.info("App entering foreground - switching to high accuracy, trackedDogs=\(self.trackedDogs.count, privacy: .public)")
        
        // Switch back to continuous high-accuracy updates
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        // Restart stationary detection
        startStationaryDetection()
    }
    
    // MARK: - Battery Management
    
    /// Setup battery level monitoring
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func batteryLevelDidChange() {
        Task { @MainActor in
            adjustForBatteryLevel()
        }
    }
    
    /// Adjust tracking based on battery level
    private func adjustForBatteryLevel() {
        guard !trackedDogs.isEmpty else { return }
        
        let batteryLevel = UIDevice.current.batteryLevel
        
        // Battery level is -1.0 if battery monitoring is not enabled or not available
        guard batteryLevel >= 0 else { return }
        
        batteryLogger.debug("Battery level: \(Int(batteryLevel * 100), privacy: .public)%")
        
        if batteryLevel < config.lowBatteryThreshold {
            batteryLogger.warning("Low battery \(Int(batteryLevel * 100), privacy: .public)% - switching to power saving mode")
            
            // Switch to low-power mode
            locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            locationManager.stopUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            
            // Update tracking status
            for dogId in trackedDogs {
                trackingStatus[dogId] = .paused
            }
        } else {
            // Resume normal tracking if we were in low-power mode
            let wasPaused = trackedDogs.contains { dogId in
                trackingStatus[dogId] == .paused
            }
            
            if wasPaused {
                batteryLogger.info("Battery level restored \(Int(batteryLevel * 100), privacy: .public)% - resuming normal tracking")
                
                if isInBackground {
                    // Use significant location changes in background
                    locationManager.startMonitoringSignificantLocationChanges()
                } else {
                    // Use high accuracy in foreground
                    locationManager.desiredAccuracy = kCLLocationAccuracyBest
                    locationManager.stopMonitoringSignificantLocationChanges()
                    locationManager.startUpdatingLocation()
                }
                
                // Update tracking status
                for dogId in trackedDogs {
                    trackingStatus[dogId] = .active
                }
            }
        }
    }
    
    // MARK: - Stationary Detection
    
    /// Start stationary detection timer
    private func startStationaryDetection() {
        // Only run stationary detection in foreground
        guard !isInBackground else { return }
        
        stationaryTimer?.invalidate()
        stationaryTimer = Timer.scheduledTimer(
            withTimeInterval: config.movingUpdateInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkStationaryStatus()
            }
        }
    }
    
    /// Check if device is stationary and adjust update frequency
    private func checkStationaryStatus() {
        guard isDeviceStationary() else { return }
        
        // Device is stationary - send periodic updates
        for dogId in trackedDogs {
            if let lastUpdate = lastUpdateTime[dogId],
               Date().timeIntervalSince(lastUpdate) >= config.stationaryUpdateInterval,
               let lastLocation = lastLocations[dogId] {
                
                locationLogger.debug("Stationary update for dog \(dogId.uuidString, privacy: .public), timeSinceLastUpdate=\(Date().timeIntervalSince(lastUpdate), privacy: .public)s")
                lastUpdateTime[dogId] = Date()
                
                Task {
                    await sendLocationUpdate(dogId: dogId, location: lastLocation)
                }
            }
        }
    }
    
    /// Check if device is stationary
    private func isDeviceStationary() -> Bool {
        // Check if we have recent location updates
        guard let firstDogId = trackedDogs.first,
              let currentLocation = lastLocations[firstDogId],
              let lastGoodLocation = lastKnownGoodLocations[firstDogId] else {
            return false
        }
        
        // Calculate distance moved since last good location
        let distance = currentLocation.distance(from: lastGoodLocation)
        
        // Check if device has been stationary for threshold duration
        let timeSinceMovement = Date().timeIntervalSince(lastMovementTime)
        
        // Device is stationary if:
        // 1. Distance moved is less than minimum threshold
        // 2. Enough time has passed since last significant movement
        if distance < config.minimumDistance && timeSinceMovement >= config.stationaryThreshold {
            return true
        }
        
        // Update last movement time if device has moved significantly
        if distance >= config.minimumDistance {
            lastMovementTime = Date()
        }
        
        return false
    }
}

// MARK: - CLLocationManagerDelegate

extension DogLocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.permissionLogger.info("Location authorization changed to status=\(status.rawValue, privacy: .public)")
            
            // Handle permission changes
            switch status {
            case .denied, .restricted:
                // Permissions revoked - stop tracking gracefully
                self.permissionLogger.warning("Location permissions revoked - stopping tracking")
                
                // If we had a pending tracking request, notify about denial
                if let pendingDogId = pendingTrackingDogId {
                    pendingTrackingDogId = nil
                    trackingStatus[pendingDogId] = .error("Location permission denied")
                    permissionDenied = true
                    permissionDeniedMessage = "Location permission was denied. To track your dog's location in the background, please enable \"Always\" location access in Settings."
                }
                
                // Update tracking status for all dogs
                for dogId in trackedDogs {
                    trackingStatus[dogId] = .error("Location permission denied")
                }
                
                // Stop location monitoring
                stopLocationMonitoring()
                
                // Notify user about permission issue
                notificationManager.notifyPermissionRevoked()
                
                updateError = NSError(
                    domain: "DogLocationTracker",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Location permissions are required for tracking. Please enable location access in Settings."
                    ]
                )
                
            case .authorizedAlways:
                // "Always" granted — start tracking for pending dog if any
                if let pendingDogId = pendingTrackingDogId {
                    pendingTrackingDogId = nil
                    self.permissionLogger.info("Always authorization granted - starting tracking for pending dog \(pendingDogId.uuidString, privacy: .public)")
                    startTracking(for: pendingDogId)
                }
                
                // Resume tracking for existing dogs if needed
                if !trackedDogs.isEmpty {
                    self.permissionLogger.info("Always authorization granted - resuming tracking")
                    updateError = nil
                    for dogId in trackedDogs {
                        if trackingStatus[dogId] == .error("Location permission denied") {
                            trackingStatus[dogId] = .active
                        }
                    }
                    startLocationMonitoring()
                }
                
            case .authorizedWhenInUse:
                // "When In Use" granted but we need "Always" for background tracking
                // If there's a pending dog, escalate to Always
                if let _ = pendingTrackingDogId {
                    self.permissionLogger.info("Got WhenInUse, requesting Always authorization for background tracking")
                    locationManager.requestAlwaysAuthorization()
                }
                
                // Still allow foreground tracking for existing dogs
                if !trackedDogs.isEmpty {
                    updateError = nil
                    for dogId in trackedDogs {
                        if trackingStatus[dogId] == .error("Location permission denied") {
                            trackingStatus[dogId] = .active
                        }
                    }
                    startLocationMonitoring()
                }
                
            case .notDetermined:
                // Permissions not yet requested
                self.permissionLogger.info("Location permissions not determined")
                
            @unknown default:
                self.permissionLogger.warning("Unknown authorization status: \(status.rawValue, privacy: .public)")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            handleLocationUpdate(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationLogger.error("Location manager error: \(error.localizedDescription, privacy: .public)")
            
            // Check if this is a permission error
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    // Permission denied - handle gracefully
                    for dogId in trackedDogs {
                        trackingStatus[dogId] = .error("Location permission denied")
                    }
                    stopLocationMonitoring()
                    
                    updateError = NSError(
                        domain: "DogLocationTracker",
                        code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Location access denied. Please enable location permissions in Settings."
                        ]
                    )
                    
                default:
                    // Other location errors - log but continue tracking
                    updateError = error
                }
            } else {
                updateError = error
            }
        }
    }
}
