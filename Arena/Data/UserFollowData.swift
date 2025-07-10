//
//  UserFollowersData.swift
//  Arena
//
//  Created by Yihui Hu on 3/12/23.
//

import Foundation
import Defaults

final class UserFollowData: ObservableObject {
    @Published var users: [User]?
    @Published var count: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    var currentPage: Int = 1
    var totalPages: Int = 1
    
    // MARK: - Followers init
    init(userId: Int, type: String) {
        fetchFollows(userId: userId, type: type)
    }
    
    // MARK: - Fetch more followers
    final func loadMore(userId: Int, type: String) {
        print("Fetching more followers: page \(self.currentPage) of \(self.totalPages)")
        fetchFollows(userId: userId, type: type)
    }
    
    // MARK: - Refresh followers data
    final func refresh(userId: Int, type: String) {
        reset()
        fetchFollows(userId: userId, type: type)
    }
    
    final func reset() {
        users = nil
        currentPage = 1
        totalPages = 1
    }
    
    // MARK: - Fetch followers
    final func fetchFollows(userId: Int, type: String) {
        guard currentPage <= totalPages else {
            return
        }
        
        guard !isLoading else {
            return
        }
        
        self.isLoading = true
        errorMessage = nil
        
        var endpoint = type
        if type == "following" {
            endpoint = "following_users"
        }
        
        guard let url = URL(string: "https://api.are.na/v2/users/\(userId)/\(endpoint)?page=\(currentPage)") else {
            self.isLoading = false
            errorMessage = "Invalid URL"
            return
        }
        
        // Create a URLRequest and set the "Authorization" header with your bearer token
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Defaults[.accessToken])", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if error != nil {
                DispatchQueue.main.async {
                    self.errorMessage = "Error retrieving data."
                    self.isLoading = false
                }
                return
            }
            
            if let data = data {
                let decoder = JSONDecoder()
                do {
                    if type == "following" {
                        let followResults = try decoder.decode(ArenaFollowing.self, from: data)
                        DispatchQueue.main.async {
                            if self.users != nil {
                                self.users?.append(contentsOf: followResults.users)
                            } else {
                                self.users = followResults.users
                            }
                            self.count = followResults.length
                            self.totalPages = Int(ceil(Double(followResults.length) / Double(20)))
                            self.currentPage += 1
                            self.isLoading = false
                        }
                    } else {
                        let followResults = try decoder.decode(ArenaFollowers.self, from: data)
                        DispatchQueue.main.async {
                            if self.users != nil {
                                self.users?.append(contentsOf: followResults.users)
                            } else {
                                self.users = followResults.users
                            }
                            self.count = followResults.length
                            self.totalPages = followResults.totalPages
                            self.currentPage += 1
                            self.isLoading = false
                        }
                    }
                } catch let decodingError {
                    // Print the decoding error for debugging
                    print("Decoding Error: \(decodingError)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Error decoding data: \(decodingError.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
        
        task.resume()
    }
}
