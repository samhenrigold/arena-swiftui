//
//  SearchChannels.swift
//  Arena
//
//  Created by Yihui Hu on 19/10/23.
//

import SwiftUI
import SmoothGradient
import NukeUI
import Defaults
import DebouncedOnChange

struct SearchView: View {
    enum ViewState {
        case loading
        case searchResults(ArenaSearchResults)
        case exploreResults(ArenaExploreResults)
        case error(String)
        case empty
    }
    
    @Environment(\.services) private var services
    @State private var viewState: ViewState = .empty
    @FocusState private var searchInputIsFocused: Bool
    @State private var searchTerm: String = ""
    @State private var selection: String = "Blocks"
    @State private var isButtonFaded = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showGradient = false
    @State private var isLoadingMore = false
    @State private var searchCurrentPage = 1
    @State private var searchTotalPages = 1
    @State private var exploreCurrentPage = 1
    @State private var exploreTotalPages = 1
    
    @Default(.pinnedChannels) var pinnedChannels
    @Default(.widgetTapped) var widgetTapped
    @Default(.widgetBlockId) var widgetBlockId
    
    var body: some View {
        let options = ["Blocks", "Channels", "Users"]
        let gridGap: CGFloat = 8
        let gridSpacing = gridGap + 8
        let gridColumns: [GridItem] = Array(repeating: .init(.flexible(), spacing: gridGap), count: 2)
        let displayWidth = UIScreen.main.bounds.width
        let gridItemSize = (displayWidth - (gridGap * 3) - 16) / 2
        
        NavigationStack {
            VStack {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        TextField("Search...", text: $searchTerm)
                            .onChange(of: searchTerm, debounceTime: .seconds(0.5)) { newValue in
                                Task {
                                    await handleSearchChange(newValue)
                                }
                            }
                            .textFieldStyle(SearchBarStyle())
                            .autocorrectionDisabled()
                            .onAppear {
                                UITextField.appearance().clearButtonMode = .always
                            }
                            .focused($searchInputIsFocused)
                            .onSubmit {
                                Task {
                                    await handleSearchChange(searchTerm)
                                }
                            }
                            .submitLabel(.search)
                        
                        if searchInputIsFocused {
                            Button(action: {
                                searchInputIsFocused = false
                            }) {
                                Text("Cancel")
                                    .fontWeight(.medium)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(Color("text-secondary"))
                            }
                        }
                    }
                    .animation(.bouncy(duration: 0.3), value: UUID())
                    
                    HStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                selection = option
                            }) {
                                Text("\(option)")
                                    .foregroundStyle(Color(selection == option ? "background" : "surface-text-secondary"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(selection == option ? "text-primary" : "surface"))
                            .cornerRadius(16)
                        }
                        .opacity(isButtonFaded ? 1 : 0)
                        .onAppear {
                            withAnimation(.easeIn(duration: 0.1)) {
                                isButtonFaded = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .font(.system(size: 15))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                switch viewState {
                case .empty, .loading:
                    if searchTerm.isEmpty {
                        // Show explore results when no search term
                        if case .exploreResults(let exploreResults) = viewState {
                            exploreResultsView(exploreResults: exploreResults, gridColumns: gridColumns, gridSpacing: gridSpacing, gridItemSize: gridItemSize)
                        } else {
                            CircleLoadingSpinner()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .task {
                                    await loadExploreResults()
                                }
                        }
                    } else {
                        CircleLoadingSpinner()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    
                case .error(let message):
                    VStack(spacing: 16) {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(message)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                if searchTerm.isEmpty {
                                    await loadExploreResults()
                                } else {
                                    await handleSearchChange(searchTerm)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
                    
                case .searchResults(let searchResults):
                    searchResultsView(searchResults: searchResults, gridColumns: gridColumns, gridSpacing: gridSpacing, gridItemSize: gridItemSize)
                    
                case .exploreResults(let exploreResults):
                    if searchTerm.isEmpty {
                        exploreResultsView(exploreResults: exploreResults, gridColumns: gridColumns, gridSpacing: gridSpacing, gridItemSize: gridItemSize)
                    } else {
                        CircleLoadingSpinner()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
            }
            .padding(.bottom, 4)
            .onChange(of: selection) { oldSelection, newSelection in
                Task {
                    if searchTerm.isEmpty {
                        await loadExploreResults()
                    } else {
                        await handleSearchChange(searchTerm)
                    }
                }
            }
            .task {
                await loadExploreResults()
            }
            .navigationDestination(isPresented: $widgetTapped) {
                HistorySingleBlockView(blockId: widgetBlockId)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color("background"))
        .contentMargins(.leading, 0, for: .scrollIndicators)
        .contentMargins(.horizontal, 16)
        .contentMargins(.bottom, 16)
    }
    
    // MARK: - Private Methods
    
    private func handleSearchChange(_ term: String) async {
        if term.isEmpty {
            await loadExploreResults()
        } else {
            await searchResults(term: term)
        }
    }
    
    private func searchResults(term: String) async {
        searchCurrentPage = 1
        searchTotalPages = 1
        await fetchSearchResults(term: term, isRefresh: true)
    }
    
    private func loadExploreResults() async {
        exploreCurrentPage = 1
        exploreTotalPages = 1
        await fetchExploreResults(isRefresh: true)
    }
    
    private func loadMoreSearch() async {
        guard searchCurrentPage <= searchTotalPages, !isLoadingMore else { return }
        isLoadingMore = true
        await fetchSearchResults(term: searchTerm, isRefresh: false)
        isLoadingMore = false
    }
    
    private func loadMoreExplore() async {
        guard exploreCurrentPage <= exploreTotalPages, !isLoadingMore else { return }
        isLoadingMore = true
        await fetchExploreResults(isRefresh: false)
        isLoadingMore = false
    }
    
    private func fetchSearchResults(term: String, isRefresh: Bool) async {
        guard searchCurrentPage <= searchTotalPages else { return }
        
        if isRefresh {
            viewState = .loading
        }
        
        let searchPath: String = switch selection {
        case "Channels": "/search/channels"
        case "Blocks": "/search/blocks"
        case "Users": "/search/users"
        default: "/search/blocks"
        }
        
        do {
            let results: ArenaSearchResults = try await services.api.search(searchPath, query: term, page: searchCurrentPage, per: 20)
            
            if isRefresh {
                viewState = .searchResults(results)
            } else {
                // Append to existing results for pagination
                if case .searchResults(let existingResults) = viewState {
                    let updatedResults = ArenaSearchResults(
                        currentPage: results.currentPage,
                        totalPages: results.totalPages,
                        channels: existingResults.channels + results.channels,
                        blocks: existingResults.blocks + results.blocks,
                        users: existingResults.users + results.users
                    )
                    viewState = .searchResults(updatedResults)
                } else {
                    viewState = .searchResults(results)
                }
            }
            
            searchTotalPages = results.totalPages
            searchCurrentPage += 1
            
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    private func fetchExploreResults(isRefresh: Bool) async {
        guard exploreCurrentPage <= exploreTotalPages else { return }
        
        if isRefresh {
            viewState = .loading
        }
        
        let option: String = switch selection {
        case "Channels": "channels"
        case "Blocks": "blocks"
        case "Users": "users"
        default: "blocks"
        }
        
        do {
            let queryItems = [
                URLQueryItem(name: "sort", value: "random"),
                URLQueryItem(name: "filter", value: option),
                URLQueryItem(name: "per", value: "20"),
                URLQueryItem(name: "page", value: "\(exploreCurrentPage)")
            ]
            
            let results: ArenaExploreResults = try await services.api.get("/search/explore", queryItems: queryItems)
            
            if isRefresh {
                viewState = .exploreResults(results)
            } else {
                // Append to existing results for pagination
                if case .exploreResults(let existingResults) = viewState {
                    let updatedResults = ArenaExploreResults(
                        currentPage: results.currentPage,
                        totalPages: results.totalPages,
                        channels: existingResults.channels + results.channels,
                        blocks: existingResults.blocks + results.blocks,
                        users: existingResults.users + results.users
                    )
                    viewState = .exploreResults(updatedResults)
                } else {
                    viewState = .exploreResults(results)
                }
            }
            
            exploreTotalPages = results.totalPages
            exploreCurrentPage += 1
            
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    @ViewBuilder
    private func searchResultsView(searchResults: ArenaSearchResults, gridColumns: [GridItem], gridSpacing: CGFloat, gridItemSize: CGFloat) -> some View {
                    ZStack {
                        ScrollView {
                            ScrollViewReader { proxy in
                                if selection == "Blocks" {
                                    LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                                        ForEach(Array(zip(searchResults.blocks.indices, searchResults.blocks)), id: \.0) { _, block in
                                            NavigationLink(destination: SingleBlockView(block: block)) {
                                                VStack(spacing: 8) {
                                                    ChannelViewBlockPreview(blockData: block, fontSize: 12, display: "Grid", isContextMenuPreview: false)
                                                        .frame(width: gridItemSize, height: gridItemSize)
                                                        .background(Color("background"))
                                                        .contextMenu {
                                                            Button {
                                                                Defaults[.connectSheetOpen] = true
                                                                Defaults[.connectItemId] = block.id
                                                                Defaults[.connectItemType] = "Block"
                                                            } label: {
                                                                Label("Connect", systemImage: "arrow.right")
                                                            }
                                                            
                                                            NavigationLink(destination: SingleBlockView(block: block)) {
                                                                Label("View", systemImage: "eye")
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
                                                    if searchResults.blocks.count >= 8 {
                                                        if searchResults.blocks[searchResults.blocks.count - 8].id == block.id {
                                                            Task {
                                                                await loadMoreSearch()
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
                                        if selection == "Channels" {
                                            ForEach(searchResults.channels, id: \.id) { channel in
                                                NavigationLink(destination: ChannelView(channelSlug: channel.slug)) {
                                                    SearchChannelPreview(channel: channel)
                                                }
                                                .onAppear {
                                                    if searchResults.channels.last?.id ?? -1 == channel.id {
                                                        if !isLoadingMore {
                                                            Task {
                                                                await loadMoreSearch()
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
                                        } else if selection == "Users" {
                                            ForEach(searchResults.users, id: \.id) { user in
                                                NavigationLink(destination: UserView(userId: user.id)) {
                                                    UserPreview(user: user)
                                                }
                                                .onAppear {
                                                    if searchResults.users.last?.id ?? -1 == user.id {
                                                        if !isLoadingMore {
                                                            Task {
                                                                await loadMoreSearch()
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
                            }
                            
                            if isLoadingMore, searchTerm != "" {
                                CircleLoadingSpinner()
                                    .padding(.vertical, 12)
                            }
                            
                            if selection == "Channels", searchResults.channels.isEmpty, !isLoadingMore {
                                EmptySearch(items: "channels", searchTerm: searchTerm)
                            } else if selection == "Blocks", searchResults.blocks.isEmpty, !isLoadingMore {
                                EmptySearch(items: "blocks", searchTerm: searchTerm)
                            } else if selection == "Users", searchResults.users.isEmpty, !isLoadingMore {
                                EmptySearch(items: "users", searchTerm: searchTerm)
                            } else if searchCurrentPage > searchTotalPages, searchTerm != "" {
                                EndOfSearch()
                            }
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .coordinateSpace(name: "scroll")
                    }
    }
    
    @ViewBuilder
    private func exploreResultsView(exploreResults: ArenaExploreResults, gridColumns: [GridItem], gridSpacing: CGFloat, gridItemSize: CGFloat) -> some View {
                        ScrollView {
                            ScrollViewReader { proxy in
                                if selection == "Blocks" {
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
                                                                await loadMoreExplore()
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
                                        if selection == "Channels" {
                                            ForEach(exploreResults.channels, id: \.id) { channel in
                                                NavigationLink(destination: ChannelView(channelSlug: channel.slug)) {
                                                    SearchChannelPreview(channel: channel)
                                                }
                                                .onAppear {
                                                    if exploreResults.channels.count >= 8 {
                                                        if exploreResults.channels[exploreResults.channels.count - 8].id == channel.id {
                                                            Task {
                                                                await loadMoreExplore()
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
                                        } else if selection == "Users" {
                                            ForEach(exploreResults.users, id: \.id) { user in
                                                NavigationLink(destination: UserView(userId: user.id)) {
                                                    UserPreview(user: user)
                                                }
                                                .onAppear {
                                                    if exploreResults.users.count >= 8 {
                                                        if exploreResults.users[exploreResults.users.count - 8].id == user.id {
                                                            Task {
                                                                await loadMoreExplore()
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
                        }
                        .refreshable {
                            await loadExploreResults()
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .coordinateSpace(name: "explore-scroll")
    }
}

struct SearchChannelPreview: View {
    let channel: ArenaSearchedChannel
    @Default(.pinnedChannels) var pinnedChannels
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    if channel.status != "closed" {
                        Image(systemName: "circle.fill")
                            .scaleEffect(0.5)
                            .foregroundColor(channel.status == "public" ? Color.green : Color.red)
                    }
                    
                    Text("\(channel.title)")
                        .foregroundStyle(Color("text-primary"))
                        .font(.system(size: 16))
                        .lineLimit(1)
                        .fontDesign(.rounded)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                if (pinnedChannels.contains(channel.id)) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(Color("surface-text-secondary"))
                        .imageScale(.small)
                }
            }
            
            Text("\(channel.user.username) • \(channel.length) items")
                .font(.system(size: 14))
                .lineLimit(1)
                .foregroundStyle(Color("surface-text-secondary"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color("surface"))
        .cornerRadius(16)
        .contentShape(ContentShapeKinds.contextMenuPreview, RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button {
                Defaults[.connectSheetOpen] = true
                Defaults[.connectItemId] = channel.id
                Defaults[.connectItemType] = "Channel"
            } label: {
                Label("Connect", systemImage: "arrow.right")
            }
            
            Button {
                togglePin(channel.id)
            } label: {
                Label(pinnedChannels.contains(channel.id) ? "Remove bookmark" : "Bookmark", systemImage: pinnedChannels.contains(channel.id) ? "bookmark.fill" : "bookmark")
            }
        }
    }
    
    private func togglePin(_ channelId: Int) {
        if Defaults[.pinnedChannels].contains(channelId) {
            Defaults[.pinnedChannels].removeAll { $0 == channelId }
            displayToast("Bookmark removed!")
        } else {
            Defaults[.pinnedChannels].append(channelId)
            displayToast("Bookmarked!")
        }
        Defaults[.pinnedChannelsChanged] = true
    }
}

#Preview {
    SearchView()
        .environment(\.services, AppServices.previewMock)
}
