import SwiftUI

enum DogBreed: String, CaseIterable, Codable {
    case afghanHound = "Afghan Hound"
    case airdaleTerrier = "Airedale Terrier"
    case akita = "Akita"
    case alaskanMalamute = "Alaskan Malamute"
    case americanBulldog = "American Bulldog"
    case americanEskimo = "American Eskimo"
    case australianCattleDog = "Australian Cattle Dog"
    case australianShepherd = "Australian Shepherd"
    case basenji = "Basenji"
    case bassetHound = "Basset Hound"
    case beagle = "Beagle"
    case beardedCollie = "Bearded Collie"
    case belgianMalinois = "Belgian Malinois"
    case bernese = "Bernese Mountain Dog"
    case bichonFrise = "Bichon Frise"
    case bloodhound = "Bloodhound"
    case borderCollie = "Border Collie"
    case bostonTerrier = "Boston Terrier"
    case boxer = "Boxer"
    case briard = "Briard"
    case bulldog = "Bulldog"
    case bullTerrier = "Bull Terrier"
    case cairnTerrier = "Cairn Terrier"
    case cavalier = "Cavalier King Charles Spaniel"
    case chesapeake = "Chesapeake Bay Retriever"
    case chihuahua = "Chihuahua"
    case chowChow = "Chow Chow"
    case cocker = "Cocker Spaniel"
    case collie = "Rough Collie"
    case cockapoo = "Cockapoo"
    case corgi = "Welsh Corgi"
    case dachshund = "Dachshund"
    case dalmatian = "Dalmatian"
    case doberman = "Doberman Pinscher"
    case englishBulldog = "English Bulldog"
    case englishSetter = "English Setter"
    case frenchBulldog = "French Bulldog"
    case germanShepherd = "German Shepherd"
    case germanShortHaired = "German Shorthaired Pointer"
    case goldenRetriever = "Golden Retriever"
    case greatDane = "Great Dane"
    case greatPyrenees = "Great Pyrenees"
    case greyhound = "Greyhound"
    case havanese = "Havanese"
    case husky = "Siberian Husky"
    case irishSetter = "Irish Setter"
    case irishWolfhound = "Irish Wolfhound"
    case italianGreyhound = "Italian Greyhound"
    case jackRussell = "Jack Russell Terrier"
    case japaneseSpitz = "Japanese Spitz"
    case keeshond = "Keeshond"
    case kerry = "Kerry Blue Terrier"
    case labrador = "Labrador Retriever"
    case leonberger = "Leonberger"
    case lhasa = "Lhasa Apso"
    case maltese = "Maltese"
    case mastiff = "English Mastiff"
    case miniPinscher = "Miniature Pinscher"
    case newfoundland = "Newfoundland"
    case norwegianElkhound = "Norwegian Elkhound"
    case oldEnglish = "Old English Sheepdog"
    case papillon = "Papillon"
    case pekingese = "Pekingese"
    case pitbull = "American Pit Bull Terrier"
    case pointer = "English Pointer"
    case pomeranian = "Pomeranian"
    case poodle = "Poodle"
    case pug = "Pug"
    case rottweiler = "Rottweiler"
    case saluki = "Saluki"
    case samoyed = "Samoyed"
    case schipperke = "Schipperke"
    case schnauzer = "Schnauzer"
    case scottishTerrier = "Scottish Terrier"
    case shetland = "Shetland Sheepdog"
    case shibaInu = "Shiba Inu"
    case shihTzu = "Shih Tzu"
    case stBernard = "Saint Bernard"
    case staffordshire = "Staffordshire Bull Terrier"
    case vizsla = "Vizsla"
    case weimaraner = "Weimaraner"
    case whippet = "Whippet"
    case yorkie = "Yorkshire Terrier"
    
    var markerColor: Color {
        switch self {
        // Retrievers and similar colored breeds
        case .labrador, .goldenRetriever, .chesapeake:
            return .yellow
        
        // Dark/Brown coated breeds
        case .germanShepherd, .rottweiler, .doberman, .bloodhound, .cockapoo:
            return .brown
        
        // Orange/Red coated breeds
        case .vizsla, .irishSetter:
            return .orange
        
        // Bulldog varieties
        case .frenchBulldog, .bulldog, .englishBulldog, .americanBulldog:
            return .red
        
        // White coated breeds
        case .samoyed, .japaneseSpitz, .americanEskimo, .maltese:
            return .white
        
        // Gray coated breeds
        case .husky, .weimaraner, .norwegianElkhound:
            return .gray
        
        // Black coated breeds
        case .newfoundland, .greatDane, .scottishTerrier:
            return .black
        
        // Small companion dogs
        case .poodle, .bichonFrise, .havanese:
            return .pink
        
        // Herding breeds
        case .borderCollie, .australianShepherd, .belgianMalinois:
            return .blue
        
        // Spitz-type breeds
        case .akita, .shibaInu, .chowChow:
            return .orange
        
        // Default colors based on size
        case .chihuahua, .yorkie, .pomeranian, .miniPinscher:
            return .purple // Small breeds
        case .mastiff, .stBernard, .greatPyrenees:
            return .brown // Giant breeds
        case .beagle, .corgi, .dachshund:
            return .mint // Medium breeds
            
        // Default color for any other breeds
        default:
            return .gray
        }
    }
    
    var iconName: String {
        String(describing: self)
    }
    
    static var popularBreeds: [DogBreed] {
        DogBreed.allCases
    }
    
    static var sortedBreeds: [DogBreed] {
        DogBreed.allCases.sorted { $0.rawValue < $1.rawValue }
    }
    
}
