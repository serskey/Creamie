import SwiftUI

struct FilterView: View {
    @Binding var selectedBreeds: Set<DogBreed>
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Select All button
                    Button(action: {
                        if selectedBreeds.count == DogBreed.allCases.count {
                            selectedBreeds.removeAll()
                        } else {
                            selectedBreeds = Set(DogBreed.allCases)
                        }
                    }) {
                        HStack {
                            Image(systemName: selectedBreeds.count == DogBreed.allCases.count ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedBreeds.count == DogBreed.allCases.count ? Color.pink : Color.purple)
                            Text(selectedBreeds.count == DogBreed.allCases.count ? "Deselect All" : "Select All")
                                .font(.headline)
                                .foregroundColor(Color.pink)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    ForEach(DogBreed.sortedBreeds, id: \.self) { breed in
                        HStack {
                            Image(systemName: selectedBreeds.contains(breed) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedBreeds.contains(breed) ? Color.pink : Color.purple)
                            Text(breed.rawValue)
                                .font(.body)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedBreeds.contains(breed) {
                                selectedBreeds.remove(breed)
                            } else {
                                selectedBreeds.insert(breed)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Filter Breeds")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
} 
