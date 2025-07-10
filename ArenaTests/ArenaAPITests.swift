//
//  ArenaAPITests.swift
//  ArenaTests
//
//  Created by Sam on 2025-07-10.
//

import XCTest
@testable import Arena

final class ArenaAPITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Mock API Tests

        func testMockAPISuccess() async throws {
        let mockAPI = MockArenaAPI()
        
        // Setup mock data
        let mockBlock = [
            "id": 123,
            "title": "Test Block",
            "created_at": "2024-01-01T00:00:00Z"
        ]
        
        mockAPI.mockData["/blocks/123"] = mockBlock
        
        // Test the API call
        struct TestBlock: Decodable, Sendable {
            let id: Int
            let title: String
            let created_at: String
        }
        
        let result: TestBlock = try await mockAPI.get("/blocks/123", queryItems: nil)
        
        XCTAssertEqual(result.id, 123)
        XCTAssertEqual(result.title, "Test Block")
        XCTAssertEqual(result.created_at, "2024-01-01T00:00:00Z")
    }
    
    func testMockAPIFailure() async throws {
        let mockAPI = MockArenaAPI()
        mockAPI.shouldFail = true
        mockAPI.errorToThrow = .unauthorized
        
        struct TestBlock: Decodable, Sendable {
            let id: Int
        }
        
        do {
            let _: TestBlock = try await mockAPI.get("/blocks/123", queryItems: nil)
            XCTFail("Expected error to be thrown")
        } catch ArenaAPIError.unauthorized {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - URL Building Tests

    func testURLBuilding() throws {
        // Test URL components building
        let baseURL = "https://api.are.na/v2"
        let path = "/blocks/123"
        let queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "per", value: "20")
        ]

        let urlString = baseURL + path
        var urlComponents = URLComponents(string: urlString)
        urlComponents?.queryItems = queryItems

        let finalURL = urlComponents?.url

        XCTAssertNotNil(finalURL)
        XCTAssertTrue(finalURL?.absoluteString.contains("page=1") ?? false)
        XCTAssertTrue(finalURL?.absoluteString.contains("per=20") ?? false)
    }

    // MARK: - Error Handling Tests

    func testAPIErrorDescriptions() {
        let errors: [ArenaAPIError] = [
            .invalidURL,
            .noData,
            .unauthorized,
            .serverError(500),
            .decodingError(NSError(domain: "test", code: 0)),
            .networkError(NSError(domain: "test", code: 0))
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - Query Parameter Tests

    func testQueryParameterEncoding() {
        let searchQuery = "test query with spaces"
        let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        XCTAssertNotNil(encoded)
        XCTAssertNotEqual(searchQuery, encoded)
        XCTAssertTrue(encoded?.contains("test%20query%20with%20spaces") ?? false)
    }
}
