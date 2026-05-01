import UIKit
import ImageIO

// MARK: - ImagePipeline Errors

enum ImagePipelineError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case decodingFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .downloadFailed:
            return "Image download failed"
        case .decodingFailed:
            return "Image decoding failed"
        case .cancelled:
            return "Image download was cancelled"
        }
    }
}

// MARK: - AsyncSemaphore

/// A simple async semaphore to limit concurrency within an actor.
private final class AsyncSemaphore: Sendable {
    private let semaphore: DispatchSemaphore

    init(value: Int) {
        self.semaphore = DispatchSemaphore(value: value)
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.semaphore.wait()
                continuation.resume()
            }
        }
    }

    func signal() {
        semaphore.signal()
    }
}

// MARK: - ImagePipeline

/// A centralized image loading pipeline that handles downloading, downsampling,
/// caching, and concurrency limiting for remote images.
///
/// Uses `CGImageSource`-based downsampling to decode images at the target resolution
/// without loading the full bitmap into memory. Cached entries are keyed by URL and
/// target pixel dimensions so thumbnails and full-resolution images are stored separately.
actor ImagePipeline {

    // MARK: - Singleton

    static let shared = ImagePipeline()

    // MARK: - Configuration

    /// Maximum in-memory cache size in bytes (50 MB).
    let maxMemoryCacheSize: Int = 50 * 1024 * 1024

    /// Maximum concurrent download tasks.
    let maxConcurrentDownloads: Int = 4

    // MARK: - Private State

    /// In-memory image cache. Uses NSCache for automatic LRU eviction.
    private let cache = NSCache<NSString, UIImage>()

    /// Tracks in-flight download tasks keyed by cache key, so duplicate requests
    /// for the same URL + size are coalesced.
    private var inFlightDownloads: [String: Task<UIImage, Error>] = [:]

    /// Semaphore to limit concurrent downloads.
    private let downloadSemaphore: AsyncSemaphore

    /// Shared URLSession with disk caching for image downloads.
    private let urlSession: URLSession

    /// Observation token for memory warning notifications.
    private var memoryWarningObserver: (any NSObjectProtocol)?

    // MARK: - Init

    private init() {
        self.downloadSemaphore = AsyncSemaphore(value: 4)

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,   // 20 MB memory
            diskCapacity: 100 * 1024 * 1024,     // 100 MB disk
            diskPath: "image_pipeline_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.urlSession = URLSession(configuration: config)

        // Configure NSCache limits
        cache.totalCostLimit = maxMemoryCacheSize

        // Observe memory warnings to purge cache
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak cache] _ in
            cache?.removeAllObjects()
        }
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Download and optionally downsample an image.
    ///
    /// - Parameters:
    ///   - url: The remote image URL string.
    ///   - targetSize: The display size in points. Pass `nil` for full resolution.
    ///   - scale: The screen scale (default 3.0 for Retina).
    /// - Returns: The decoded `UIImage`, downsampled if `targetSize` is provided.
    func image(for url: String, targetSize: CGSize?, scale: CGFloat = 3.0) async throws -> UIImage {
        let cacheKey = Self.cacheKey(for: url, targetSize: targetSize, scale: scale)

        // 1. Check in-memory cache
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }

        // 2. Coalesce duplicate in-flight requests
        if let existingTask = inFlightDownloads[cacheKey] {
            return try await existingTask.value
        }

        // 3. Create a new download task
        let task = Task<UIImage, Error> {
            // Wait for semaphore slot
            await downloadSemaphore.wait()
            defer { downloadSemaphore.signal() }

            // Check cancellation before downloading
            try Task.checkCancellation()

            let data = try await downloadData(from: url)

            // Check cancellation after downloading
            try Task.checkCancellation()

            // Downsample or decode
            let decodedImage: UIImage
            if let targetSize = targetSize {
                let targetPixelSize = CGSize(
                    width: targetSize.width * scale,
                    height: targetSize.height * scale
                )
                decodedImage = try Self.downsample(data: data, targetPixelSize: targetPixelSize)
            } else {
                guard let fullImage = UIImage(data: data) else {
                    throw ImagePipelineError.decodingFailed
                }
                decodedImage = fullImage
            }

            return decodedImage
        }

        inFlightDownloads[cacheKey] = task

        do {
            let result = try await task.value
            inFlightDownloads.removeValue(forKey: cacheKey)

            // Store in cache with cost = width × height × 4 bytes
            let cost = Self.imageCost(result)
            cache.setObject(result, forKey: cacheKey as NSString, cost: cost)

            return result
        } catch {
            inFlightDownloads.removeValue(forKey: cacheKey)
            throw error
        }
    }

    /// Remove all in-memory cached images.
    /// Called automatically on memory warning, but can also be called manually.
    func purgeMemoryCache() {
        cache.removeAllObjects()
    }

    /// Cancel any in-flight download for the given URL.
    /// Cancels all size variants for that URL.
    func cancelDownload(for url: String) {
        let keysToCancel = inFlightDownloads.keys.filter { $0.hasPrefix(url) }
        for key in keysToCancel {
            inFlightDownloads[key]?.cancel()
            inFlightDownloads.removeValue(forKey: key)
        }
    }

    // MARK: - Cache Key

    /// Generates a cache key that includes both the URL and target pixel dimensions.
    /// This ensures thumbnails and full-resolution images are cached separately.
    static func cacheKey(for url: String, targetSize: CGSize?, scale: CGFloat) -> String {
        if let targetSize = targetSize {
            let targetPixelWidth = Int(targetSize.width * scale)
            let targetPixelHeight = Int(targetSize.height * scale)
            return "\(url)_\(targetPixelWidth)x\(targetPixelHeight)"
        } else {
            return "\(url)_full"
        }
    }

    // MARK: - Downsampling

    /// Downsample image data using CGImageSource to decode at the target pixel size
    /// without loading the full bitmap into memory.
    ///
    /// - Parameters:
    ///   - data: The raw image data.
    ///   - targetPixelSize: The desired output size in pixels.
    /// - Returns: A downsampled `UIImage`.
    static func downsample(data: Data, targetPixelSize: CGSize) throws -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            throw ImagePipelineError.decodingFailed
        }

        // Use the larger dimension as the max pixel size to maintain aspect ratio
        let maxDimension = max(targetPixelSize.width, targetPixelSize.height)

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(
            imageSource,
            0,
            downsampleOptions as CFDictionary
        ) else {
            throw ImagePipelineError.decodingFailed
        }

        return UIImage(cgImage: downsampledImage)
    }

    // MARK: - Cost Calculation

    /// Compute the memory cost of an image as width × height × 4 bytes.
    static func imageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.width * cgImage.height * 4
    }

    // MARK: - Private Helpers

    /// Download raw data from a URL string.
    private func downloadData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw ImagePipelineError.invalidURL
        }

        do {
            let (data, response) = try await urlSession.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw ImagePipelineError.downloadFailed
            }

            return data
        } catch is CancellationError {
            throw ImagePipelineError.cancelled
        } catch let error as ImagePipelineError {
            throw error
        } catch {
            throw ImagePipelineError.downloadFailed
        }
    }
}
