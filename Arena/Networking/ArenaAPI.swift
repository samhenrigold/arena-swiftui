//
//  ArenaAPI.swift
//  Arena
//
//  Created by Sam on 2025-07-10.
//

import Foundation
import Defaults

// MARK: - API Protocol
protocol ArenaAPIProtocol: Sendable {
    func get<T: Decodable & Sendable>(_ path: String, queryItems: [URLQueryItem]?) async throws -> T
    func search<T: Decodable & Sendable>(_ path: String, query: String, page: Int?, per: Int?) async throws -> T
}

// MARK: - API Errors
enum ArenaAPIError: LocalizedError, Sendable {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Error decoding data: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

// MARK: - Arena API Actor
/// A thread-safe actor that handles all Arena API networking
///
/// Usage:
/// ```swift
/// let block: Block = try await ArenaAPI.shared.get("/blocks/123")
/// let searchResults: ArenaSearchResults = try await ArenaAPI.shared.search("/search/blocks", query: "design")
/// let channels: ArenaChannels = try await ArenaAPI.shared.get("/users/456/channels", page: 1, per: 20)
/// ```
actor ArenaAPI: ArenaAPIProtocol {
    static let shared = ArenaAPI()
    
    private let baseURL = "https://api.are.na/v2"
    private let decoder = JSONDecoder()
    private let session = URLSession.shared
    
    private init() {}
    
    func get<T: Decodable & Sendable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        // Build URL
        let urlString = baseURL + path
        guard var urlComponents = URLComponents(string: urlString) else {
            throw ArenaAPIError.invalidURL
        }
        
        // Add query parameters if provided
        if let queryItems = queryItems {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw ArenaAPIError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Defaults[.accessToken])", forHTTPHeaderField: "Authorization")
        
        // Perform request
        do {
            let (data, response) = try await session.data(for: request)
            
            // Handle HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    break // Success
                case 401:
                    throw ArenaAPIError.unauthorized
                case 400...499, 500...599:
                    throw ArenaAPIError.serverError(httpResponse.statusCode)
                default:
                    throw ArenaAPIError.serverError(httpResponse.statusCode)
                }
            }
            
            // Decode response
            do {
                let result = try decoder.decode(T.self, from: data)
                return result
            } catch {
                throw ArenaAPIError.decodingError(error)
            }
            
        } catch {
            // Handle network errors
            if error is ArenaAPIError {
                throw error
            } else {
                throw ArenaAPIError.networkError(error)
            }
        }
    }
    
    func search<T: Decodable & Sendable>(_ path: String, query: String, page: Int? = nil, per: Int? = nil) async throws -> T {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: encodedQuery),
            page.map { URLQueryItem(name: "page", value: "\($0)") },
            per.map { URLQueryItem(name: "per", value: "\($0)") }
        ].compactMap { $0 }
        
        return try await get(path, queryItems: queryItems)
    }
}

// MARK: - Convenience Extensions
extension ArenaAPI {
    

    
    /// Fetch with pagination support (convenience extension)
    func get<T: Decodable & Sendable>(_ path: String, page: Int? = nil, per: Int? = nil, additionalQueryItems: [URLQueryItem]? = nil) async throws -> T {
        var queryItems: [URLQueryItem] = []
        
        if let page = page {
            queryItems.append(URLQueryItem(name: "page", value: "\(page)"))
        }
        
        if let per = per {
            queryItems.append(URLQueryItem(name: "per", value: "\(per)"))
        }
        
        if let additionalQueryItems = additionalQueryItems {
            queryItems.append(contentsOf: additionalQueryItems)
        }
        
        return try await get(path, queryItems: queryItems.isEmpty ? nil : queryItems)
    }
}

// MARK: - Mock Implementation for Testing
#if DEBUG
final class MockArenaAPI: ArenaAPIProtocol, @unchecked Sendable {
    var mockData: [String: Any] = [:]
    var shouldFail = false
    var errorToThrow: ArenaAPIError = .networkError(NSError(domain: "test", code: 0))
    
    func get<T: Decodable & Sendable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        if shouldFail {
            throw errorToThrow
        }
        
        // Return mock data based on path
        if let mockResponse = mockData[path] {
            let data = try JSONSerialization.data(withJSONObject: mockResponse)
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        throw ArenaAPIError.noData
    }
    
    func search<T: Decodable & Sendable>(_ path: String, query: String, page: Int? = nil, per: Int? = nil) async throws -> T {
        if shouldFail {
            throw errorToThrow
        }
        
        // For mock, just return same as get() - simplified for testing
        return try await get(path, queryItems: nil)
    }
}
#endif 
