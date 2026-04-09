import Foundation

/// Store for persisting and retrieving tracking preferences using UserDefaults
class TrackingPreferencesStore {
    private let key = "dog_location_tracking_preferences"
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// Save tracking preference for a specific dog
    func savePreference(_ preference: TrackingPreferences) {
        var allPreferences = loadAllPreferences()
        
        // Remove existing preference for this dog if any
        allPreferences.removeAll { $0.dogId == preference.dogId }
        
        // Add the new preference
        allPreferences.append(preference)
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(allPreferences) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    /// Load tracking preference for a specific dog
    func loadPreference(for dogId: UUID) -> TrackingPreferences? {
        let allPreferences = loadAllPreferences()
        return allPreferences.first { $0.dogId == dogId }
    }
    
    /// Load all tracking preferences
    func loadAllPreferences() -> [TrackingPreferences] {
        guard let data = userDefaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode([TrackingPreferences].self, from: data) else {
            return []
        }
        return preferences
    }
    
    /// Delete tracking preference for a specific dog
    func deletePreference(for dogId: UUID) {
        var allPreferences = loadAllPreferences()
        allPreferences.removeAll { $0.dogId == dogId }
        
        if let encoded = try? JSONEncoder().encode(allPreferences) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    /// Clear all tracking preferences
    func clearAllPreferences() {
        userDefaults.removeObject(forKey: key)
    }
}
