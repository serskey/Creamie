import Foundation
import SwiftUI

struct VaccinationRecord: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
    let expirationDate: Date
    let veterinarian: String
}

struct VetAppointment: Identifiable {
    let id = UUID()
    let purpose: String
    let date: Date
    let veterinarianName: String
    let clinicName: String
    let notes: String?
    var isCompleted: Bool = false
}

struct WeightRecord: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double // in kg
    let notes: String?
}

struct Medication: Identifiable {
    let id = UUID()
    let name: String
    let dosage: String
    let frequency: String
    let startDate: Date
    let endDate: Date?
    let notes: String?
}

struct GroomingAppointment: Identifiable {
    let id = UUID()
    let date: Date
    let groomingService: String
    let location: String
    let notes: String?
    var isCompleted: Bool = false
}

@MainActor
class DogHealthViewModel: ObservableObject {
    @Published var vaccinations: [VaccinationRecord] = []
    @Published var vetAppointments: [VetAppointment] = []
    @Published var weightHistory: [WeightRecord] = []
    @Published var medications: [Medication] = []
    @Published var groomingAppointments: [GroomingAppointment] = []
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private let dogId: UUID
    
    init(dogId: UUID) {
        self.dogId = dogId
        loadSampleData()
    }
    
    func loadHealthData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // In a real app, you would fetch this data from a database or API
            // For now, we'll just simulate a network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            loadSampleData()
        } catch {
            self.error = error
        }
    }
    
    private func loadSampleData() {
        // Sample vaccination records
        vaccinations = [
            VaccinationRecord(
                name: "Rabies",
                date: Date().addingTimeInterval(-180 * 24 * 3600),
                expirationDate: Date().addingTimeInterval(185 * 24 * 3600),
                veterinarian: "Dr. Smith"
            ),
            VaccinationRecord(
                name: "DHPP",
                date: Date().addingTimeInterval(-90 * 24 * 3600),
                expirationDate: Date().addingTimeInterval(275 * 24 * 3600),
                veterinarian: "Dr. Johnson"
            )
        ]
        
        // Sample vet appointments
        vetAppointments = [
            VetAppointment(
                purpose: "Annual Checkup",
                date: Date().addingTimeInterval(14 * 24 * 3600),
                veterinarianName: "Dr. Smith",
                clinicName: "Happy Paws Clinic",
                notes: "Bring vaccination records"
            ),
            VetAppointment(
                purpose: "Dental Cleaning",
                date: Date().addingTimeInterval(30 * 24 * 3600),
                veterinarianName: "Dr. Johnson",
                clinicName: "Pet Dental Care",
                notes: "No food after midnight"
            )
        ]
        
        // Sample weight history
        let today = Date()
        weightHistory = [
            WeightRecord(
                date: today.addingTimeInterval(-180 * 24 * 3600),
                weight: 12.5,
                notes: "After diet change"
            ),
            WeightRecord(
                date: today.addingTimeInterval(-120 * 24 * 3600),
                weight: 13.2,
                notes: nil
            ),
            WeightRecord(
                date: today.addingTimeInterval(-60 * 24 * 3600),
                weight: 13.8,
                notes: "Gaining weight steadily"
            ),
            WeightRecord(
                date: today,
                weight: 14.1,
                notes: "Healthy weight"
            )
        ]
        
        // Sample medications
        medications = [
            Medication(
                name: "Heartworm Prevention",
                dosage: "1 tablet",
                frequency: "Monthly",
                startDate: today.addingTimeInterval(-90 * 24 * 3600),
                endDate: nil,
                notes: "Give with food"
            ),
            Medication(
                name: "Joint Supplement",
                dosage: "1 chew",
                frequency: "Daily",
                startDate: today.addingTimeInterval(-30 * 24 * 3600),
                endDate: today.addingTimeInterval(60 * 24 * 3600),
                notes: nil
            )
        ]
        
        // Sample grooming appointments
        groomingAppointments = [
            GroomingAppointment(
                date: today.addingTimeInterval(7 * 24 * 3600),
                groomingService: "Full Grooming",
                location: "Fluffy Paws Grooming",
                notes: "Short summer cut"
            ),
            GroomingAppointment(
                date: today.addingTimeInterval(-21 * 24 * 3600),
                groomingService: "Bath & Nail Trim",
                location: "Fluffy Paws Grooming",
                notes: nil,
                isCompleted: true
            )
        ]
    }
    
    // MARK: - Data Management Methods
    
    func addVaccination(_ vaccination: VaccinationRecord) {
        vaccinations.append(vaccination)
        // In a real app, you would save this to a database or API
    }
    
    func addVetAppointment(_ appointment: VetAppointment) {
        vetAppointments.append(appointment)
        // In a real app, you would save this to a database or API
    }
    
    func addWeightRecord(_ record: WeightRecord) {
        weightHistory.append(record)
        weightHistory.sort { $0.date < $1.date }
        // In a real app, you would save this to a database or API
    }
    
    func addMedication(_ medication: Medication) {
        medications.append(medication)
        // In a real app, you would save this to a database or API
    }
    
    func addGroomingAppointment(_ appointment: GroomingAppointment) {
        groomingAppointments.append(appointment)
        // In a real app, you would save this to a database or API
    }
    
    // MARK: - Helper Methods
    
    func upcomingVaccinations() -> [VaccinationRecord] {
        let threeMonthsFromNow = Date().addingTimeInterval(90 * 24 * 3600)
        return vaccinations.filter { $0.expirationDate < threeMonthsFromNow }
    }
    
    func upcomingAppointments() -> [VetAppointment] {
        return vetAppointments.filter { !$0.isCompleted && $0.date > Date() }
            .sorted { $0.date < $1.date }
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
        return groomingAppointments.filter { !$0.isCompleted && $0.date > Date() }
            .sorted { $0.date < $1.date }
    }
} 