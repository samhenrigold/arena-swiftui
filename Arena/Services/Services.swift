//
//  Services.swift
//  Arena
//
//  Created by Sam on 2025-07-10.
//

import Foundation
import SwiftUI

@Observable
final class AppServices: Sendable {
    let api: ArenaAPIProtocol
    
    init(api: ArenaAPIProtocol) {
        self.api = api
    }
    
    static let live = AppServices(api: ArenaAPI.shared)
    
    #if DEBUG
    static let previewMock = AppServices(api: MockArenaAPI())
    #endif
}

// MARK: - Environment Key
private struct ServicesKey: EnvironmentKey {
    static let defaultValue: AppServices = {
        #if DEBUG
        return .previewMock
        #else
        return .live
        #endif
    }()
}

extension EnvironmentValues {
    var services: AppServices {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
} 
