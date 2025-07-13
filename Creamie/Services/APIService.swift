import Foundation
import Combine

// MARK: - API Configuration
struct APIConfig {
    static let baseURL = "http://127.0.0.1:9000"
    static let timeout: TimeInterval = 30.0
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

// MARK: - Base API Service
class APIService {
    static let shared = APIService()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
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
            
            // Decode response
            do {
                let dogs = try decoder.decode(responseType, from: data)
                return dogs
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError
            }
            
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
        // TODO: Implement your authentication token retrieval logic
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
