import Foundation
import Combine

// MARK: - API Configuration
struct APIConfig {

    static let baseURL = "https://creamiebackend-production.up.railway.app"
    static let timeout: TimeInterval = 30.0
}

// MARK: - Base API Service
class APIService {
    static let shared = APIService()
    let baseURL = APIConfig.baseURL
    
    private let session: URLSession
    let decoder: JSONDecoder
    
    /// In-flight GET requests keyed by "GET_<endpoint>" for request coalescing.
    /// When a duplicate GET request arrives, the existing task's result is awaited
    /// instead of issuing a new network call.
    private var inFlightRequests: [String: Task<Data, Error>] = [:]
    
    /// Serial queue to synchronize access to `inFlightRequests`.
    private let inFlightLock = NSLock()
    
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout
        
        // Configure URL cache: 20 MB memory, 100 MB disk
        let urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
        config.urlCache = urlCache
        config.requestCachePolicy = .useProtocolCachePolicy
        
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - Cacheable Endpoint Detection
    
    /// Returns `true` if the endpoint matches `/dogs/*` or `/user/*/dogs` patterns
    /// and should include Cache-Control headers.
    private func isCacheableEndpoint(_ endpoint: String) -> Bool {
        // Match /dogs or /dogs/*
        if endpoint == "/dogs" || endpoint.hasPrefix("/dogs/") {
            return true
        }
        // Match /user/*/dogs (e.g. /user/123/dogs)
        if let range = endpoint.range(of: "/user/"),
           range.lowerBound == endpoint.startIndex {
            let afterUser = endpoint[range.upperBound...]
            if afterUser.contains("/dogs") {
                return true
            }
        }
        return false
    }
    
    // MARK: - Generic Request Methods
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Codable? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // For GET requests, use returnCacheDataElseLoad policy
        if method == .GET {
            request.cachePolicy = .returnCacheDataElseLoad
        }
        
        // Add Cache-Control header for cacheable GET endpoints
        if method == .GET && isCacheableEndpoint(endpoint) {
            request.setValue("max-age=30", forHTTPHeaderField: "Cache-Control")
        }
        
        // Add authentication header if needed
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body if provided
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.networkError(error)
            }
        }
        
        // For GET requests, use request deduplication
        let data: Data
        if method == .GET {
            data = try await deduplicatedGETData(for: request, endpoint: endpoint)
        } else {
            data = try await performRequest(request)
        }
        
        // Decode response
        do {
            let result = try decoder.decode(responseType, from: data)
            return result
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingError
        }
    }
    
    // MARK: - Request Deduplication
    
    /// Performs a GET request with deduplication. If an identical GET request is already
    /// in flight, the existing task's result is awaited instead of issuing a new network call.
    private func deduplicatedGETData(for request: URLRequest, endpoint: String) async throws -> Data {
        let key = "GET_\(endpoint)"
        
        inFlightLock.lock()
        if let existingTask = inFlightRequests[key] {
            inFlightLock.unlock()
            return try await existingTask.value
        }
        
        let task = Task<Data, Error> {
            defer {
                inFlightLock.lock()
                inFlightRequests.removeValue(forKey: key)
                inFlightLock.unlock()
            }
            return try await performRequest(request)
        }
        
        inFlightRequests[key] = task
        inFlightLock.unlock()
        
        return try await task.value
    }
    
    /// Performs the actual network request and validates the HTTP response.
    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            // Handle HTTP response codes
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    break
                case 401:
                    throw APIError.unauthorized
                default:
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            return data
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // MARK: - WebSocket Support for Real-time Updates
    func createWebSocketConnection(endpoint: String) -> URLSessionWebSocketTask? {
        guard let url = URL(string: APIConfig.baseURL.replacingOccurrences(of: "https://", with: "wss://") + endpoint) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.webSocketTask(with: request)
    }
    
    // MARK: - Helper Methods
    
    private func getAuthToken() -> String? {
        // Pending Implement your authentication token retrieval logic
        // For now, return nil - you can implement this based on your auth system
        return nil
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - API Error Types
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case serverError(Int)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}
