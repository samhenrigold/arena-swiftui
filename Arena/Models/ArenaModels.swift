//
//  ArenaModels.swift
//  Arena
//
//  Created by Yihui Hu on 12/10/23.
//

import Foundation
import SwiftUI

// MARK: - ArenaChannels
final class ArenaChannels: Codable, @unchecked Sendable {
    let id: Int // id of user
    let length, totalPages, currentPage: Int
    var channels: ContiguousArray<ArenaChannelPreview>
    
    enum CodingKeys: String, CodingKey {
        case id
        case length
        case totalPages = "total_pages"
        case currentPage = "current_page"
        case channels
    }
    
    init(length: Int, totalPages: Int, currentPage: Int, id: Int, channels: ContiguousArray<ArenaChannelPreview>) {
        self.length = length
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.id = id
        self.channels = channels
    }
}

// MARK: - ArenaChannelPreview
final class ArenaChannelPreview: Codable, @unchecked Sendable {
    let id: Int
    let title, createdAt, updatedAt, addedToAt: String
    let published, channelOpen, collaboration: Bool
    let collaboratorCount: Int
    let slug: String
    let length: Int
    let status: String
    let userId: Int
    let metadata: Metadata?
    var contents: [Block]?
    let followerCount: Int
    let ownerId: Int?
    let ownerSlug: String?
    let nsfw: Bool
    let state: String?
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case addedToAt = "added_to_at"
        case published
        case channelOpen = "open"
        case collaboration
        case collaboratorCount = "collaborator_count"
        case slug, length, status
        case userId = "user_id"
        case metadata, contents
        case followerCount = "follower_count"
        case ownerId = "owner_id"
        case ownerSlug = "owner_slug"
        case nsfw = "nsfw?"
        case state, user, id
    }
    
    init(title: String, createdAt: String, updatedAt: String, addedToAt: String, published: Bool, channelOpen: Bool, collaboration: Bool, collaboratorCount: Int, slug: String, length: Int, status: String, userId: Int, metadata: Metadata?, contents: [Block]?, followerCount: Int, ownerId: Int?, ownerSlug: String?, nsfw: Bool, state: String?, user: User, id: Int) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.addedToAt = addedToAt
        self.published = published
        self.channelOpen = channelOpen
        self.collaboration = collaboration
        self.collaboratorCount = collaboratorCount
        self.slug = slug
        self.length = length
        self.status = status
        self.userId = userId
        self.metadata = metadata
        self.contents = contents
        self.followerCount = followerCount
        self.ownerId = ownerId
        self.ownerSlug = ownerSlug
        self.nsfw = nsfw
        self.state = state
        self.user = user
        self.id = id
    }
}

// MARK: - ArenaChannel
final class ArenaChannel: Codable, Equatable, @unchecked Sendable {
    static func == (lhs: ArenaChannel, rhs: ArenaChannel) -> Bool {
        return lhs.id == rhs.id // Compare using a unique identifier, such as the 'id' property
    }
    
    let id: Int
    let title, createdAt, updatedAt, addedToAt: String
    let published, open, collaboration: Bool
    let collaboratorCount: Int
    let slug: String
    let length: Int
    let kind, status: String
    let userId: Int
    let baseClass: String
    let page, per: Int
    let collaborators: [User]
    let followerCount: Int
    let metadata: Metadata?
    let className: String
    let canIndex, nsfw: Bool
    let user: User
    //    let owner: // TODO: Support ability to handle both Users and Groups lol
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case addedToAt = "added_to_at"
        case published
        case open = "open"
        case collaboration
        case collaboratorCount = "collaborator_count"
        case slug, length, kind, status
        case userId = "user_id"
        case baseClass = "base_class"
        case page, per, collaborators
        case followerCount = "follower_count"
        case metadata
        case className = "class_name"
        case canIndex = "can_index"
        case nsfw = "nsfw?"
        case user
        //        case owner
    }
    
    init(id: Int, title: String, createdAt: String, updatedAt: String, addedToAt: String, published: Bool, open: Bool, collaboration: Bool, collaboratorCount: Int, slug: String, length: Int, kind: String, status: String, userId: Int, contents: [Block]?, baseClass: String, page: Int, per: Int, collaborators: [User], followerCount: Int, metadata: Metadata?, className: String, canIndex: Bool, nsfw: Bool, owner: User, user: User) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.addedToAt = addedToAt
        self.published = published
        self.open = open
        self.collaboration = collaboration
        self.collaboratorCount = collaboratorCount
        self.slug = slug
        self.length = length
        self.kind = kind
        self.status = status
        self.userId = userId
        self.baseClass = baseClass
        self.page = page
        self.per = per
        self.collaborators = collaborators
        self.followerCount = followerCount
        self.metadata = metadata
        self.className = className
        self.canIndex = canIndex
        self.nsfw = nsfw
        //        self.owner = owner
        self.user = user
    }
}

// MARK: - ArenaChannelContents
final class ArenaChannelContents: Codable, @unchecked Sendable {
    let contents: [Block]?
}

// MARK: - ArenaSearchResults
final class ArenaSearchResults: Codable, @unchecked Sendable {
    let currentPage, totalPages: Int
    var channels: [ArenaSearchedChannel]
    var blocks: [Block]
    var users: [User]
    
    enum CodingKeys: String, CodingKey {
        case totalPages = "total_pages"
        case currentPage = "current_page"
        case channels, blocks, users
    }
    
    init(currentPage: Int, totalPages: Int, channels: [ArenaSearchedChannel], blocks: [Block], users: [User]) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.channels = channels
        self.blocks = blocks
        self.users = users
    }
}

// MARK: - ArenaSearchedChannel
final class ArenaSearchedChannel: Codable, Equatable, @unchecked Sendable {
    static func == (lhs: ArenaSearchedChannel, rhs: ArenaSearchedChannel) -> Bool {
        return lhs.id == rhs.id // Compare using a unique identifier, such as the 'id' property
    }
    
    let title, createdAt, updatedAt, addedToAt: String
    let slug: String
    let length: Int
    let status: String
    let userId: Int
    let contents: [Block]?
    let ownerSlug: String
    let state: String
    let user: User
    let id: Int
    
    enum CodingKeys: String, CodingKey {
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case addedToAt = "added_to_at"
        case slug, length, status
        case userId = "user_id"
        case contents
        case ownerSlug = "owner_slug"
        case state, user, id
    }
    
    init(title: String, createdAt: String, updatedAt: String, addedToAt: String, slug: String, length: Int, status: String, userId: Int, contents: [Block]?, ownerSlug: String, state: String, user: User, id: Int) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.addedToAt = addedToAt
        self.slug = slug
        self.length = length
        self.status = status
        self.userId = userId
        self.contents = contents
        self.ownerSlug = ownerSlug
        self.state = state
        self.user = user
        self.id = id
    }
}

// MARK: - Block
final class Block: Hashable, Codable, ObservableObject, Equatable, @unchecked Sendable {
    static func == (lhs: Block, rhs: Block) -> Bool {
        return lhs.id == rhs.id // Compare using a unique identifier, such as the 'id' property
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: Int
    let title: String
    let updatedAt, createdAt: String // describes when block was updated and created
    let commentCount: Int?
    let generatedTitle: String?
    let visibility: String?
    let content: String?
    let description: String?
    let source: ArenaSource?
    let image: ArenaImage?
    let attachment: ArenaAttachment?
    let metadata: Metadata?
    let baseClass: String
    let contentClass: String // describes type of block
    let user: User // original user who added block to Are.na
    let slug: String? // block itself might be a channel, so this is here for that
    let selected: Bool?
    let connectionId: Int?
    let connectedAt: String? // describes when block was added to channel
    let connectedByUserId: Int? // describes who added the block to channel
    let connectedByUsername, connectedByUserSlug: String?
    let connections: [BlockConnection]?
    let collaboratorCount: Int?
    let position: Int?
    let nsfw: Bool?
    let length: Int?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case commentCount = "comment_count"
        case generatedTitle = "generated_title"
        case visibility, content, description, source, image, metadata, id, attachment
        case baseClass = "base_class"
        case contentClass = "class"
        case user, slug, selected
        case connectionId = "connection_id"
        case connectedAt = "connected_at"
        case connectedByUserId = "connected_by_user_id"
        case connectedByUsername = "connected_by_username"
        case connectedByUserSlug = "connected_by_user_slug"
        case connections
        case collaboratorCount = "collaborator_count"
        case position
        case nsfw = "nsfw?"
        case length, status
    }
    
    init(title: String, updatedAt: String, createdAt: String, commentCount: Int?, generatedTitle: String?, visibility: String?, content: String?, description: String?, source: ArenaSource?, image: ArenaImage?, attachment: ArenaAttachment?, metadata: Metadata?, id: Int, baseClass: String, contentClass: String, user: User, slug: String?, selected: Bool?, connectionId: Int?, connectedAt: String?, connectedByUserId: Int?, connectedByUsername: String?, connectedByUserSlug: String?, connections: [BlockConnection]?, collaboratorCount: Int?, position: Int?, nsfw: Bool?, length: Int?, status: String?) {
        self.title = title
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.commentCount = commentCount
        self.generatedTitle = generatedTitle
        self.visibility = visibility
        self.content = content
        self.description = description
        self.source = source
        self.image = image
        self.attachment = attachment
        self.metadata = metadata
        self.id = id
        self.baseClass = baseClass
        self.contentClass = contentClass
        self.user = user
        self.slug = slug
        self.selected = selected
        self.connectionId = connectionId
        self.connectedAt = connectedAt
        self.connectedByUserId = connectedByUserId
        self.connectedByUsername = connectedByUsername
        self.connectedByUserSlug = connectedByUserSlug
        self.connections = connections
        self.collaboratorCount = collaboratorCount
        self.position = position
        self.nsfw = nsfw
        self.length = length
        self.status = status
    }
}

// MARK: - BlockConnections
final class BlockConnections: Codable, @unchecked Sendable {
    let connections: [BlockConnection]
}

// MARK: - BlockConnection
final class BlockConnection: Identifiable, Codable, @unchecked Sendable {
    let id: Int
    let title: String
    let updatedAt, createdAt: String // describes when block was updated and created
    let published, open, collaboration: Bool
    let slug: String
    let length: Int
    let status: String
    let userId: Int
    let metadata: Metadata?
    
    enum CodingKeys: String, CodingKey {
        case id, title, published, open, collaboration, slug, length, status, metadata
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case userId = "user_id"
    }
    
    // TODO: initializer here
}

// MARK: - ArenaAttachment
final class ArenaAttachment: Codable, @unchecked Sendable {
    let filename, fileSizeDisplay, fileExtension, contentType, url: String
    let fileSize: Int
    
    enum CodingKeys: String, CodingKey {
        case filename = "file_name"
        case fileSize = "file_size"
        case fileSizeDisplay = "file_size_display"
        case fileExtension = "extension"
        case contentType = "content_type"
        case url
    }
    
    init(filename: String, fileSize: Int, fileSizeDisplay: String, fileExtension: String, contentType: String, url: String) {
        self.filename = filename
        self.fileSize = fileSize
        self.fileSizeDisplay = fileSizeDisplay
        self.fileExtension = fileExtension
        self.contentType = contentType
        self.url = url
    }
}

// MARK: - Image
final class ArenaImage: Codable, @unchecked Sendable {
    let filename, contentType, updatedAt: String
    let thumb, square, display, large: Display
    let original: OriginalImage
    
    enum CodingKeys: String, CodingKey {
        case filename
        case contentType = "content_type"
        case updatedAt = "updated_at"
        case thumb, square, display, large, original
    }
    
    init(filename: String, contentType: String, updatedAt: String, thumb: Display, square: Display, display: Display, large: Display, original: OriginalImage) {
        self.filename = filename
        self.contentType = contentType
        self.updatedAt = updatedAt
        self.thumb = thumb
        self.square = square
        self.display = display
        self.large = large
        self.original = original
    }
}

// MARK: - Display
struct Display: Codable, Sendable {
    let url: String
}

// MARK: - Original
final class OriginalImage: Codable, @unchecked Sendable {
    let url: String
    let fileSize: Int
    let fileSizeDisplay: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case fileSize = "file_size"
        case fileSizeDisplay = "file_size_display"
    }
    
    init(url: String, fileSize: Int, fileSizeDisplay: String) {
        self.url = url
        self.fileSize = fileSize
        self.fileSizeDisplay = fileSizeDisplay
    }
}

// MARK: - Metadata
final class Metadata: Codable, @unchecked Sendable {
    let description: String?
    
    init(description: String?) {
        self.description = description
    }
}

// MARK: - Source
final class ArenaSource: Codable, @unchecked Sendable {
    let url: String?
    let title: String?
    
    init(url: String?, title: String?) {
        self.url = url
        self.title = title
    }
}

// MARK: - User
final class User: Codable, Equatable, @unchecked Sendable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id // Compare using a unique identifier, such as the 'id' property
    }
    
    let createdAt, slug, username, firstName: String
    let lastName, fullName: String
    let avatarImage: AvatarImage
    let channelCount, followingCount, followerCount: Int
    let profileId: Int?
    let initials: String
    let badge: String?
    let id: Int
    
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case slug, username
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case avatarImage = "avatar_image"
        case channelCount = "channel_count"
        case followingCount = "following_count"
        case profileId = "profile_id"
        case followerCount = "follower_count"
        case initials
        case badge, id
    }
    
    init(createdAt: String, slug: String, username: String, firstName: String, lastName: String, fullName: String, avatarImage: AvatarImage, channelCount: Int, followingCount: Int, profileId: Int?, followerCount: Int, initials: String, badge: String?, id: Int) {
        self.createdAt = createdAt
        self.slug = slug
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.avatarImage = avatarImage
        self.channelCount = channelCount
        self.followingCount = followingCount
        self.profileId = profileId
        self.followerCount = followerCount
        self.initials = initials
        self.badge = badge
        self.id = id
    }
}

// MARK: - AvatarImage
final class AvatarImage: Codable, @unchecked Sendable {
    let thumb, display: String
    
    init(thumb: String, display: String) {
        self.thumb = thumb
        self.display = display
    }
}

// MARK: - Block Comments
final class BlockComments: Codable, @unchecked Sendable {
    let comments: [BlockComment]
    let length: Int
    
    enum CodingKeys: String, CodingKey {
        case comments, length
    }
    
    init(comments: [BlockComment], length: Int) {
        self.comments = comments
        self.length = length
    }
}

// MARK: - Singular Block Comment
final class BlockComment: Codable, @unchecked Sendable {
    let id: Int
    let createdAt, updatedAt: String
    let commentableId: Int
    let commentableType, body: String
    let userId: Int
    let baseClass: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case commentableId = "commentable_id"
        case commentableType = "commentable_type"
        case body
        case userId = "user_id"
        case baseClass = "base_class"
        case user
    }
    
    init(id: Int, createdAt: String, updatedAt: String, commentableId: Int, commentableType: String, body: String, userId: Int, baseClass: String, user: User) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.commentableId = commentableId
        self.commentableType = commentableType
        self.body = body
        self.userId = userId
        self.baseClass = baseClass
        self.user = user
    }
}

//MARK: - Followers data
final class ArenaFollowers: Codable, @unchecked Sendable {
    let length, currentPage, totalPages: Int
    var users: [User]
    
    enum CodingKeys: String, CodingKey {
        case totalPages = "total_pages"
        case currentPage = "current_page"
        case users, length
    }
    
    init(length: Int, currentPage: Int, totalPages: Int, users: [User]) {
        self.length = length
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.users = users
    }
}

//enum FollowingItem: Decodable, Equatable {
//    case userItem(User)
//    case channelItem(ArenaSearchedChannel)
//    
//    enum CodingKeys: CodingKey, CaseIterable {
//        case userItem
//        case channelItem
//    }
//    
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        if let value = try container.decodeIfPresent(User.self, forKey: .userItem) {
//            self = FollowingItem.userItem(value)
//            return
//        }
//        
//        if let value = try container.decodeIfPresent(ArenaSearchedChannel.self, forKey: .channelItem) {
//            self = FollowingItem.channelItem(value)
//            return
//        }
//        
//        throw DecodingError.valueNotFound(Self.self, DecodingError.Context(codingPath: CodingKeys.allCases, debugDescription: "user/channel not found"))
//    }
//}

//MARK: - Following data
final class ArenaFollowing: Decodable, @unchecked Sendable {
    let length, currentPage: Int
    var users: [User]
    
    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case users, length
    }
    
    init(length: Int, currentPage: Int, totalPages: Int, users: [User]) {
        self.length = length
        self.currentPage = currentPage
        self.users = users
    }
}

// MARK: - ArenaExploreResults
final class ArenaExploreResults: Codable, @unchecked Sendable {
    let currentPage, totalPages: Int
    var channels: [ArenaSearchedChannel]
    var blocks: [Block]
    var users: [User]
    
    enum CodingKeys: String, CodingKey {
        case totalPages = "total_pages"
        case currentPage = "current_page"
        case channels, blocks, users
    }
    
    init(currentPage: Int, totalPages: Int, channels: [ArenaSearchedChannel], blocks: [Block], users: [User]) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.channels = channels
        self.blocks = blocks
        self.users = users
    }
}

// MARK: - ChannelConnections
final class ChannelConnections: Codable, @unchecked Sendable {
    let currentPage, totalPages: Int
    var channels: [ArenaSearchedChannel]
    
    enum CodingKeys: String, CodingKey {
        case totalPages = "total_pages"
        case currentPage = "current_page"
        case channels
    }
    
    init(currentPage: Int, totalPages: Int, channels: [ArenaSearchedChannel]) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.channels = channels
    }
}
