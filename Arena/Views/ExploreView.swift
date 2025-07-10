//
//  ExploreView.swift
//  Arena
//
//  Created by Yihui Hu on 23/10/23.
//

import SwiftUI
import SmoothGradient
import NukeUI
import Defaults
import UniformTypeIdentifiers

enum Selection: String, CaseIterable, Sendable {
    case blocks = "Blocks"
    case channels = "Channels"
    case users = "Users"
}

struct ExploreView: View {
    enum ViewState {
        case loading
        case loaded(ArenaExploreResults)
        case error(String)
    }
    
    @Environment(\.services) private var services
    @State private var viewState: ViewState = .loading
    @State private var selection = Selection.blocks
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoadingMore = false
    let selectionOptions = Selection.allCases
    
    @Default(.pinnedChannels) var pinnedChannels
    
    var selectionLabel: some View {
        switch selection {
        case .blocks:
            return Image(systemName: "square.grid.2x2")
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .frame(width: 18, height: 18)
        case .channels:
            return Image(systemName: "water.waves")
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .frame(width: 18, height: 18)
        case .users:
            return Image(systemName: "person")
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .frame(width: 18, height: 18)
        }
    }
    
    var body: some View {
        let gridGap: CGFloat = 8
        let gridSpacing = gridGap + 8
        let gridColumns: [GridItem] = Array(repeating: .init(.flexible(), spacing: gridGap), count: 2)
        let displayWidth = UIScreen.main.bounds.width
        let gridItemSize = (displayWidth - (gridGap * 3) - 16) / 2
        
        NavigationStack {
            VStack {
                switch viewState {
                case .loading:
                    CircleLoadingSpinner()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .task {
                            await load()
                        }
                        
                case .error(let message):
                    VStack(spacing: 16) {
                        Text("Error loading explore results")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(message)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await load()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
                    
                case .loaded(let exploreResults):
                    ScrollView {
                        if selection.rawValue == "Blocks" {
                            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                                ForEach(Array(zip(exploreResults.blocks.indices, exploreResults.blocks)), id: \.0) { _, block in
                                    NavigationLink(destination: SingleBlockView(block: block)) {
                                        VStack(spacing: 8) {
                                            ChannelViewBlockPreview(blockData: block, fontSize: 12, display: "Grid", isContextMenuPreview: false)
                                                .frame(width: gridItemSize, height: gridItemSize)
                                                .background(Color("background"))
                                                .contextMenu {
                                                    BlockContextMenu(block: block, showViewOption: false, channelData: nil, channelSlug: "")
                                                    
                                                    NavigationLink(destination: SingleBlockView(block: block)) {
                                                        Label("View Block", systemImage: "eye")
                                                    }
                                                    .simultaneousGesture(TapGesture().onEnded{
                                                        AddBlockToRabbitHole(block: block)
                                                    })
                                                } preview: {
                                                    BlockContextMenuPreview(block: block)
                                                }
                                            
                                            ContentPreviewMetadata(block: block, display: "Grid")
                                                .padding(.horizontal, 12)
                                        }
                                        .onAppear {
                                            if exploreResults.blocks.count >= 8 {
                                                if exploreResults.blocks[exploreResults.blocks.count - 8].id == block.id {
                                                    Task {
                                                        await loadMore()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .simultaneousGesture(TapGesture().onEnded{
                                        AddBlockToRabbitHole(block: block)
                                    })
                                }
                            }
                        } else {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                if selection.rawValue == "Channels" {
                                    ForEach(exploreResults.channels, id: \.id) { channel in
                                        NavigationLink(destination: ChannelView(channelSlug: channel.slug)) {
                                            SearchChannelPreview(channel: channel)
                                        }
                                        .onAppear {
                                            if exploreResults.channels.count >= 8 {
                                                if exploreResults.channels[exploreResults.channels.count - 8].id == channel.id {
                                                    Task {
                                                        await loadMore()
                                                    }
                                                }
                                            }
                                        }
                                        .simultaneousGesture(TapGesture().onEnded{
                                            let id = UUID()
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "HH:mm, d MMM y"
                                            let timestamp = formatter.string(from: Date.now)
                                            Defaults[.rabbitHole].insert(RabbitHoleItem(id: id.uuidString, type: "channel", subtype: channel.status, itemId: channel.slug, timestamp: timestamp, mainText: channel.title, subText: String(channel.length), imageUrl: String(channel.id)), at: 0)
                                        })
                                    }
                                } else if selection.rawValue == "Users" {
                                    ForEach(exploreResults.users, id: \.id) { user in
                                        NavigationLink(destination: UserView(userId: user.id)) {
                                            UserPreview(user: user)
                                        }
                                        .onAppear {
                                            if exploreResults.users.count >= 8 {
                                                if exploreResults.users[exploreResults.users.count - 8].id == user.id {
                                                    Task {
                                                        await loadMore()
                                                    }
                                                }
                                            }
                                        }
                                        .simultaneousGesture(TapGesture().onEnded{
                                            AddUserToRabbitHole(user: user)
                                        })
                                    }
                                }
                            }
                        }
                        
                        if isLoadingMore {
                            CircleLoadingSpinner()
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .coordinateSpace(name: "scroll")
                }
            }
            .refreshable {
                await refresh()
            }
            .onChange(of: selection) { oldSelection, newSelection in
                if oldSelection != newSelection {
                    Task {
                        await refresh()
                    }
                }
            }
            .padding(.bottom, 4)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Explore")
                        .foregroundStyle(Color("text-primary"))
                        .font(.system(size: 20))
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Select a display mode", selection: $selection) {
                            ForEach(selectionOptions, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                    } label: {
                        selectionLabel
                    }
                    .foregroundStyle(Color("surface-text-secondary"))
                }
            }
            .toolbarBackground(Color("background"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color("background"))
        .contentMargins(.leading, 0, for: .scrollIndicators)
        .contentMargins(selection.rawValue == "Blocks" ? 8 : 16)
    }
    
    // MARK: - Private Methods
    
    private func load() async {
        viewState = .loading
        await fetchExploreResults(isRefresh: true)
    }
    
    private func refresh() async {
        currentPage = 1
        totalPages = 1
        await fetchExploreResults(isRefresh: true)
    }
    
    private func loadMore() async {
        guard currentPage <= totalPages, !isLoadingMore else { return }
        isLoadingMore = true
        await fetchExploreResults(isRefresh: false)
        isLoadingMore = false
    }
    
    private func fetchExploreResults(isRefresh: Bool) async {
        guard currentPage <= totalPages else { return }
        
        let option: String = switch selection {
        case .channels: "channels"
        case .blocks: "blocks"
        case .users: "users"
        }
        
        do {
            let queryItems = [
                URLQueryItem(name: "sort", value: "random"),
                URLQueryItem(name: "filter", value: option),
                URLQueryItem(name: "per", value: "20"),
                URLQueryItem(name: "page", value: "\(currentPage)")
            ]
            
            let results: ArenaExploreResults = try await services.api.get("/search/explore", queryItems: queryItems)
            
            if isRefresh {
                viewState = .loaded(results)
            } else {
                // Append to existing results for pagination
                if case .loaded(let existingResults) = viewState {
                    let updatedResults = ArenaExploreResults(
                        currentPage: results.currentPage,
                        totalPages: results.totalPages,
                        channels: existingResults.channels + results.channels,
                        blocks: existingResults.blocks + results.blocks,
                        users: existingResults.users + results.users
                    )
                    viewState = .loaded(updatedResults)
                } else {
                    viewState = .loaded(results)
                }
            }
            
            totalPages = results.totalPages
            currentPage += 1
            
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
}

#Preview {
    ExploreView()
        .environment(\.services, AppServices.previewMock)
}
