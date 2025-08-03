import Foundation
import SwiftUI

// MARK: - Request/Response Models
struct GetDogHealthRequest: Codable {
    let dogId: UUID
}

struct GetDogHealthResponse: Codable {
    let dogId: UUID
    let status: String
    let error: String?
    
    let vaccinationRecords: [VaccinationRecord]?
    let vetAppointments: [VetAppointment]?
    let weightHistory: [WeightRecord]?
    let medications: [Medication]?
    let groomingAppointments: [GroomingAppointment]?
}

struct SaveDogHealthRequest: Codable {
    let dogId: UUID
    let vaccinationRecords: [VaccinationRecord]?
    let vetAppointments: [VetAppointment]?
    let weightHistory: [WeightRecord]?
    let medications: [Medication]?
    let groomingAppointments: [GroomingAppointment]?
}

struct SaveDogHealthResponse: Codable {
    let dogId: UUID
    let status: String
    let error: String?
    let message: String?
}

// MARK: - Health Record Models (Updated to match backend)
struct VaccinationRecord: Identifiable, Codable {
    let id: UUID
    let vaccineName: String
    let vaccinationDate: Date
    let expirationDate: Date
    let veterinarianName: String?
    let clinicName: String?
    let notes: String?
    
    init(vaccineName: String, vaccinationDate: Date, expirationDate: Date, veterinarianName: String? = nil, clinicName: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.vaccineName = vaccineName
        self.vaccinationDate = vaccinationDate
        self.expirationDate = expirationDate
        self.veterinarianName = veterinarianName
        self.clinicName = clinicName
        self.notes = notes
    }
}

struct VetAppointment: Identifiable, Codable {
    let id: UUID
    let purpose: String
    let appointmentDate: Date
    let veterinarianName: String?
    let clinicName: String?
    let notes: String?
    var isCompleted: Bool? = false
    
    init(purpose: String, appointmentDate: Date, veterinarianName: String? = nil, clinicName: String? = nil, notes: String? = nil, isCompleted: Bool? = false) {
        self.id = UUID()
        self.purpose = purpose
        self.appointmentDate = appointmentDate
        self.veterinarianName = veterinarianName
        self.clinicName = clinicName
        self.notes = notes
        self.isCompleted = isCompleted
    }
}

struct WeightRecord: Identifiable, Codable {
    let id: UUID
    let measurementDate: Date
    let weightKg: Double
    let notes: String?
    
    init(measurementDate: Date, weightKg: Double, notes: String? = nil) {
        self.id = UUID()
        self.measurementDate = measurementDate
        self.weightKg = weightKg
        self.notes = notes
    }
}

struct Medication: Identifiable, Codable {
    let id: UUID
    let medicationName: String
    let dosage: String
    let frequency: String
    let startDate: Date?
    let endDate: Date?
    let notes: String?
    
    init(medicationName: String, dosage: String, frequency: String, startDate: Date? = nil, endDate: Date? = nil, notes: String? = nil) {
        self.id = UUID()
        self.medicationName = medicationName
        self.dosage = dosage
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }
}

struct GroomingAppointment: Identifiable, Codable {
    let id: UUID
    let appointmentDate: Date
    let groomingService: String?
    let location: String?
    let notes: String?
    var isCompleted: Bool? = false
    
    init(appointmentDate: Date, groomingService: String? = nil, location: String? = nil, notes: String? = nil, isCompleted: Bool? = false) {
        self.id = UUID()
        self.appointmentDate = appointmentDate
        self.groomingService = groomingService
        self.location = location
        self.notes = notes
        self.isCompleted = isCompleted
    }
}

// MARK: - Updated DogHealthViewModel
@MainActor
class DogHealthViewModel: ObservableObject {
    @Published var vaccinations: [VaccinationRecord] = []
    @Published var vetAppointments: [VetAppointment] = []
    @Published var weightHistory: [WeightRecord] = []
    @Published var medications: [Medication] = []
    @Published var groomingAppointments: [GroomingAppointment] = []
    
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: Error?
    
    @Published var getDogHealthError: String?
    @Published var saveHealthError: String?
    
    private var currentDogId: UUID?
    
    // MARK: - Load Health Data
    func loadHealthData(for dogId: UUID) async {
        isLoading = true
        currentDogId = dogId
        defer { isLoading = false }
        
        do {
            await fetchDogHealthData(for: dogId)
        } catch {
            self.error = error
        }
    }
    
    func fetchDogHealthData(for dogId: UUID) async {
        do {
            let getDogHealthRequest = GetDogHealthRequest(dogId: dogId)
            let response = try await DogHealthcareService.shared.fetchHealthData(request: getDogHealthRequest)
            
            print("fetchDogHealthData response: \(response)")
            
            // Update published properties with response data
            self.vaccinations = response.vaccinationRecords ?? []
            self.vetAppointments = response.vetAppointments ?? []
            self.weightHistory = response.weightHistory ?? []
            self.medications = response.medications ?? []
            self.groomingAppointments = response.groomingAppointments ?? []
            
            // Clear any previous errors
            self.getDogHealthError = nil
            
        } catch {
            print("❌ Failed to fetch health info for dog \(dogId): \(error)")
            self.getDogHealthError = "Unable to fetch health info. Please check your internet connection and try again."
        }
    }
    
    // MARK: - Save All Health Data
    func saveAllHealthData() async {
        guard let dogId = currentDogId else {
            saveHealthError = "No dog selected"
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let saveRequest = SaveDogHealthRequest(
                dogId: dogId,
                vaccinationRecords: vaccinations.isEmpty ? nil : vaccinations,
                vetAppointments: vetAppointments.isEmpty ? nil : vetAppointments,
                weightHistory: weightHistory.isEmpty ? nil : weightHistory,
                medications: medications.isEmpty ? nil : medications,
                groomingAppointments: groomingAppointments.isEmpty ? nil : groomingAppointments
            )
            
            let response = try await DogHealthcareService.shared.saveHealthData(request: saveRequest)
            
            if response.status == "success" {
                saveHealthError = nil
                print("✅ Successfully saved health data for dog \(dogId)")
            } else {
                saveHealthError = response.error ?? "Failed to save health data"
            }
            
        } catch {
            print("❌ Failed to save health data: \(error)")
            saveHealthError = "Unable to save health data. Please try again."
        }
    }
    
    // MARK: - Individual Data Management Methods
    func addVaccination(_ vaccination: VaccinationRecord) {
        vaccinations.append(vaccination)
        Task {
            await saveAllHealthData()
        }
    }
    
    func addVetAppointment(_ appointment: VetAppointment) {
        vetAppointments.append(appointment)
        Task {
            await saveAllHealthData()
        }
    }
    
    func addWeightRecord(_ record: WeightRecord) {
        weightHistory.append(record)
        weightHistory.sort { $0.measurementDate < $1.measurementDate }
        Task {
            await saveAllHealthData()
        }
    }
    
    func addMedication(_ medication: Medication) {
        medications.append(medication)
        Task {
            await saveAllHealthData()
        }
    }
    
    func addGroomingAppointment(_ appointment: GroomingAppointment) {
        groomingAppointments.append(appointment)
        Task {
            await saveAllHealthData()
        }
    }
    
    // MARK: - Bulk Add Methods (for form submissions)
    func addHealthDataFromForm(
        weight: Double?,
        weightNotes: String?,
        vaccination: VaccinationRecord?,
        grooming: GroomingAppointment?,
        medication: Medication?,
        vetAppointment: VetAppointment?
    ) async {
        var hasChanges = false
        
        // Add weight record if provided
        if let weight = weight, weight > 0 {
            let weightRecord = WeightRecord(
                measurementDate: Date(),
                weightKg: weight,
                notes: weightNotes
            )
            weightHistory.append(weightRecord)
            weightHistory.sort { $0.measurementDate < $1.measurementDate }
            hasChanges = true
        }
        
        // Add vaccination if provided
        if let vaccination = vaccination {
            vaccinations.append(vaccination)
            hasChanges = true
        }
        
        // Add grooming if provided
        if let grooming = grooming {
            groomingAppointments.append(grooming)
            hasChanges = true
        }
        
        // Add medication if provided
        if let medication = medication {
            medications.append(medication)
            hasChanges = true
        }
        
        // Add vet appointment if provided
        if let vetAppointment = vetAppointment {
            vetAppointments.append(vetAppointment)
            hasChanges = true
        }
        
        // Save all changes in one API call
        if hasChanges {
            await saveAllHealthData()
        }
    }
    
    // MARK: - Helper Methods
    func upcomingVaccinations() -> [VaccinationRecord] {
        let threeMonthsFromNow = Date().addingTimeInterval(90 * 24 * 3600)
        return vaccinations.filter { $0.expirationDate < threeMonthsFromNow }
    }
    
    func upcomingAppointments() -> [VetAppointment] {
        return vetAppointments.filter { !($0.isCompleted ?? false) && $0.appointmentDate > Date() }
            .sorted { $0.appointmentDate < $1.appointmentDate }
    }
    
    func currentMedications() -> [Medication] {
        let today = Date()
        return medications.filter { medication in
            if let endDate = medication.endDate {
                return today <= endDate
            }
            return true
        }
    }
    
    func upcomingGroomingAppointments() -> [GroomingAppointment] {
        return groomingAppointments.filter { !($0.isCompleted ?? false) && $0.appointmentDate > Date() }
            .sorted { $0.appointmentDate < $1.appointmentDate }
    }
    
    // MARK: - Clear Data
    func clearAllData() {
        vaccinations.removeAll()
        vetAppointments.removeAll()
        weightHistory.removeAll()
        medications.removeAll()
        groomingAppointments.removeAll()
        currentDogId = nil
        getDogHealthError = nil
        saveHealthError = nil
    }
}
