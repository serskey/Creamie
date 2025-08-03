//
//  DogHealthcareView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/8/1.
//

import SwiftUI

struct DogHealthcareView: View {
    let dogId: UUID
    @ObservedObject var dogHealthViewModel: DogHealthViewModel
    
    var body: some View {
        VStack {
            if dogHealthViewModel.isLoading {
                ProgressView("Loading health data...")
                    .padding()
            } else if let healthInfo = getHealthInfo(for: dogId) {
                VStack(spacing: 12) {
                    Text("Health & Care")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(healthInfo, id: \.title) { info in
                            HStack {
                                Image(systemName: info.icon)
                                    .foregroundColor(.green)
                                    .frame(width: 20)
                                Text(info.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(info.value)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
    
    // Fetch Health Info - now uses actual data from view model
    private func getHealthInfo(for dogId: UUID) -> [HealthInfoItem]? {
        var healthItems: [HealthInfoItem] = []
        
        // Weight from latest weight record
        if let latestWeight = dogHealthViewModel.weightHistory.last {
            healthItems.append(HealthInfoItem(
                icon: "heart.fill",
                title: "Weight",
                value: "\(String(format: "%.1f", latestWeight.weightKg)) kg"
            ))
        }
        
        // Vaccination status
        let upcomingVaccinations = dogHealthViewModel.upcomingVaccinations()
        var vaccinationStatus = ""

        if upcomingVaccinations.isEmpty {
            vaccinationStatus = "Up to date"
        } else {
            let vaccineNames = upcomingVaccinations.map { $0.vaccineName }

            let joinedNames = vaccineNames.joined(separator: ", ")

            if vaccineNames.count > 1 {
                
                if let lastCommaIndex = joinedNames.lastIndex(of: ",") {
                    let prefix = joinedNames[..<lastCommaIndex]
                    let suffix = joinedNames[joinedNames.index(after: lastCommaIndex)...]
                    vaccinationStatus = "\(prefix) and\(suffix) due soon"
                } else {
                    vaccinationStatus = "\(joinedNames) due soon"
                }
            } else {
                vaccinationStatus = "\(joinedNames) due soon"
            }
        }

        healthItems.append(HealthInfoItem(
            icon: "syringe",
            title: "Vaccinations",
            value: vaccinationStatus
        ))
        // Grooming
        let upcomingGroomingAppointments = dogHealthViewModel.upcomingGroomingAppointments()
        let groomingStatus = upcomingGroomingAppointments.isEmpty ? "Up to date" : "\(upcomingGroomingAppointments.count) due soon"
        healthItems.append(HealthInfoItem(
            icon: "scissors",
            title: "Last Grooming",
            value: groomingStatus
        ))
        
        
        // Show some basic info even if no data
        if healthItems.isEmpty {
            healthItems = [
                HealthInfoItem(icon: "heart.fill", title: "Weight", value: "Not recorded"),
                HealthInfoItem(icon: "syringe", title: "Vaccinations", value: "No records"),
                HealthInfoItem(icon: "scissors", title: "Last Grooming", value: "No records"),
            ]
        }
        
        return healthItems
    }
}
