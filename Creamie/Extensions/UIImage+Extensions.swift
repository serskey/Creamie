import UIKit
import SwiftUI

extension UIImage {
    static func loadImageFromDocuments(named name: String) -> UIImage? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("\(name).jpg")
        
        if let imageData = try? Data(contentsOf: fileURL) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    // Resize image to a reasonable size to prevent memory issues
    func resized(toWidth width: CGFloat) -> UIImage {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}

extension Image {
    static func fromDocumentsOrAsset(named name: String) -> Image {
        if let uiImage = UIImage.loadImageFromDocuments(named: name) {
            // Resize large images to prevent performance issues
            let resizedImage = uiImage.resized(toWidth: 1000)
            return Image(uiImage: resizedImage)
        } else {
            return Image(name)
        }
    }
} 