//
//  ChannelView.swift
//  Arena
//
//  Created by Yihui Hu on 14/10/23.
//

import SwiftUI
import WrappingHStack
import Defaults
import UniformTypeIdentifiers

enum SortOption: String, CaseIterable, Sendable {
    case position = "Position"
    case newest = "Newest First"
    case oldest = "Oldest First"
}

enum DisplayOption: String, CaseIterable, Sendable {
    case grid = "Grid"
    case largeGrid = "Large Grid"
    case feed = "Feed"
    case table = "Table"
}

enum ContentOption: String, CaseIterable, Sendable {
    case all = "All"
    //    case blocks = "Blocks"
    //    case channels = "Channels"
    case connections = "Connections"
}

struct ChannelView: View {
    let channelSlug: String
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    
    @State private var selection = SortOption.position
    @State private var display = DisplayOption.grid
    @State private var content = ContentOption.all
    @State private var channelPinned = false
    @State private var clickedPin = false
    @State private var showingConnections = false
    @State private var channelState: ChannelState = .loading
    @State private var connectionsState: ConnectionsState = .idle
    
    let sortOptions = SortOption.allCases
    let displayOptions = DisplayOption.allCases
    let contentOptions = ContentOption.allCases
    
    enum ChannelState {
        case loading
        case loaded(channel: ArenaChannel, contents: [Block], currentPage: Int, totalPages: Int, isLoadingMore: Bool)
        case error(String)
    }
    
    enum ConnectionsState {
        case idle
        case loading
        case loaded([ArenaSearchedChannel], currentPage: Int, totalPages: Int, isLoadingMore: Bool)
        case error(String)
    }
    
    var displayLabel: some View {
        switch display {
        case .grid:
            return Image(systemName: "square.grid.2x2")
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .frame(width: 18, height: 18)
        case .largeGrid:
            return Image(systemName: "square.grid.3x3")
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .frame(width: 18, height: 18)
        case .table:
            return Image(systemName: "rectangle.grid.1x2")
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .frame(width: 18, height: 18)
        case .feed:
            return Image(systemName: "square")
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .frame(width: 18, height: 18)
        }
    }
    
    @ViewBuilder
    private func destinationView(for block: Block) -> some View {
        if block.baseClass == "Block" {
            // For now, we'll need to handle this differently since BlockView still expects ChannelData
            // This will be fixed in a later migration step
            SingleBlockView(block: block)
        } else {
            ChannelView(channelSlug: block.slug ?? "")
        }
    }
    
    @ViewBuilder
    private func ChannelViewContents(contents: [Block], gridItemSize: CGFloat) -> some View {
        ForEach(contents, id: \.id) { block in
            NavigationLink(destination: destinationView(for: block)) {
                ChannelContentPreview(
                    block: block,
                    channelData: ChannelData(channelSlug: channelSlug, selection: .newest),
                    channelSlug: channelSlug,
                    gridItemSize: gridItemSize,
                    display: display.rawValue
                )
            }
            .onAppear {
                loadMoreChannelData(block: block)
            }
            .simultaneousGesture(TapGesture().onEnded{
                let id = UUID()
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm, d MMM y"
                let timestamp = formatter.string(from: Date.now)
                if block.baseClass == "Block" {
                    AddBlockToRabbitHole(block: block)
                } else {
                    Defaults[.rabbitHole].insert(RabbitHoleItem(id: id.uuidString, type: "channel", subtype: block.status ?? "", itemId: block.slug ?? "", timestamp: timestamp, mainText: block.title, subText: String(block.length ?? 0), imageUrl: String(block.id)), at: 0)
                }
            })
        }
    }
    
    var body: some View {
        // Setting up grid
        let gridGap: CGFloat = 8
        let gridSpacing = display.rawValue != "Large Grid" ? gridGap + 8 : gridGap
        let gridColumns: [GridItem] =
        Array(repeating:
                .init(.flexible(), spacing: gridGap),
              count:
                display.rawValue == "Grid" ? 2 :
                display.rawValue == "Large Grid" ? 3 :
                1)
        let displayWidth = UIScreen.main.bounds.width
        let gridItemSize =
        display.rawValue == "Grid" ? (displayWidth - (gridGap * 3)) / 2 :
        display.rawValue == "Large Grid" ? (displayWidth - (gridGap * 4)) / 3 :
        (displayWidth - (gridGap * 2))
        
        return ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack {}.id(0) // Hacky implementation of scroll to top when switching sorting option
                    
                    // Channel header based on state
                    if case .loaded(let channel, _, _, _, _) = channelState {
                        ChannelViewHeader(channel: channel, content: $content, showingConnections: $showingConnections, contentOptions: contentOptions)
                    }
                    
                    if showingConnections {
                        // Show connections
                        switch connectionsState {
                        case .idle:
                            EmptyView()
                        case .loading:
                            CircleLoadingSpinner()
                                .padding(.top, 24)
                                .padding(.bottom, 72)
                        case .loaded(let connections, _, let totalPages, let isLoadingMore):
                            if connections.isEmpty {
                                EmptyChannelConnections()
                            } else {
                                ForEach(connections, id: \.id) { channel in
                                    NavigationLink(destination: ChannelView(channelSlug: channel.slug)) {
                                        SearchChannelPreview(channel: channel)
                                    }
                                    .onBecomingVisible {
                                        if connections.last?.id ?? -1 == channel.id {
                                            Task {
                                                await loadMoreConnections()
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
                                
                                if isLoadingMore {
                                    CircleLoadingSpinner()
                                        .padding(.top, 24)
                                        .padding(.bottom, 72)
                                }
                                
                                if case .loaded(_, let currentPage, let totalPages, _) = connectionsState,
                                   currentPage > totalPages {
                                    EndOfChannelConnections()
                                        .padding(.bottom, 72)
                                }
                            }
                        case .error(let message):
                            VStack {
                                Text("Error loading connections")
                                    .font(.headline)
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    } else {
                        // Show channel contents
                        switch channelState {
                        case .loading:
                            CircleLoadingSpinner()
                                .padding(.top, 24)
                                .padding(.bottom, 72)
                        case .loaded(_, let contents, let currentPage, let totalPages, let isLoadingMore):
                            if contents.isEmpty {
                                EmptyChannel()
                            } else {
                                if display.rawValue == "Table" {
                                    LazyVStack(spacing: 8) {
                                        ChannelViewContents(contents: contents, gridItemSize: gridItemSize)
                                    }
                                } else {
                                    LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                                        ChannelViewContents(contents: contents, gridItemSize: gridItemSize)
                                    }
                                }
                                
                                if isLoadingMore {
                                    CircleLoadingSpinner()
                                        .padding(.top, 24)
                                        .padding(.bottom, 72)
                                }
                                
                                if currentPage > totalPages {
                                    EndOfChannel()
                                        .padding(.bottom, 72)
                                }
                            }
                        case .error(let message):
                            VStack {
                                Text("Error loading channel")
                                    .font(.headline)
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Try Again") {
                                    Task {
                                        await refreshChannel()
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
                .padding(.bottom, 4)
                .background(Color("background"))
                .contentMargins(gridGap)
                .contentMargins(.leading, 0, for: .scrollIndicators)
                .refreshable {
                    do { try await Task.sleep(nanoseconds: 500_000_000) } catch {}
                    if showingConnections {
                        await loadConnections()
                    } else {
                        await refreshChannel()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            BackButton()
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        if !showingConnections {
                            HStack(spacing: 8) {
                                Menu {
                                    Picker("Select a display mode", selection: $display) {
                                        ForEach(displayOptions, id: \.self) {
                                            Text($0.rawValue)
                                        }
                                    }
                                } label: {
                                    displayLabel
                                }
                                
                                Menu {
                                    Picker("Select a sort order", selection: $selection) {
                                        ForEach(sortOptions, id: \.self) {
                                            Text($0.rawValue)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .resizable()
                                        .scaledToFit()
                                        .fontWeight(.semibold)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .foregroundStyle(Color("surface-text-secondary"))
                        }
                    }
                }
                .toolbarBackground(Color("background"), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .onChange(of: selection, initial: false) { oldSelection, newSelection in
                    if oldSelection != newSelection {
                        proxy.scrollTo(0) // TODO: Decide if want withAnimation { proxy.scrollTo(0) }
                        Task {
                            await refreshChannel()
                        }
                    }
                }
                .onChange(of: display, initial: false) { oldDisplay, newDisplay in
                    if oldDisplay != newDisplay {
                        proxy.scrollTo(0)
                    }
                }
                .onChange(of: showingConnections) { _, isShowing in
                    if isShowing {
                        Task {
                            await loadConnections()
                        }
                    }
                }
                .task {
                    await loadChannel()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if case .loaded(let channel, _, _, _, _) = channelState {
                HStack(spacing: 9) {
                    Menu {
                        Button(action: {
                            UIPasteboard.general.setValue(channelSlug as String,
                                                          forPasteboardType: UTType.plainText.identifier)
                            displayToast("Copied!")

                        }) {
                            Label("Copy channel slug", systemImage: "clipboard")
                        }
                        
                        ShareLink(item: URL(string: "https://are.na/\(channel.user.slug ?? "")/\(channelSlug)")!) {
                            Label("Share channel", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .fontWeight(.bold)
                            .imageScale(.small)
                            .foregroundStyle(Color("text-primary"))
                            .padding(.bottom, 4)
                            .frame(width: 40, height: 40)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                    
                    //                    ShareLink(item: URL(string: "https://are.na/\(channelCreator)/\(channelSlug)")!) {
                    //                        Image(systemName: "square.and.arrow.up")
                    //                            .fontWeight(.bold)
                    //                            .imageScale(.small)
                    //                            .foregroundStyle(Color("text-primary"))
                    //                            .padding(.bottom, 4)
                    //                            .frame(width: 40, height: 40)
                    //                            .background(.thinMaterial)
                    //                            .clipShape(Circle())
                    //                    }
                    
                    Button(action: {
                        Defaults[.connectSheetOpen] = true
                        Defaults[.connectItemId] = channel.id
                        Defaults[.connectItemType] = "Channel"
                    }) {
                        Text("Connect")
                            .foregroundStyle(Color("text-primary"))
                            .font(.system(size: 16))
                            .fontDesign(.rounded)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
                    .cornerRadius(16)
                    
                    Button(action: {
                        togglePin(channel.id)
                    }) {
                        Image(systemName: clickedPin ? channelPinned ? "bookmark.fill" : "bookmark" : Defaults[.pinnedChannels].contains(channel.id) ? "bookmark.fill" : "bookmark")
                            .fontWeight(.bold)
                            .imageScale(.small)
                            .foregroundStyle(Color("text-primary"))
                            .frame(width: 40, height: 40)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
    
    private func togglePin(_ channelId: Int) {
        clickedPin = true
        channelPinned = !(Defaults[.pinnedChannels].contains(channelId))
        
        if Defaults[.pinnedChannels].contains(channelId) {
            Defaults[.pinnedChannels].removeAll { $0 == channelId }
            displayToast("Bookmark removed!")
        } else {
            Defaults[.pinnedChannels].append(channelId)
            displayToast("Bookmarked!")
        }
        Defaults[.pinnedChannelsChanged] = true
    }
    
    @MainActor
    private func loadChannel() async {
        channelState = .loading
        
        do {
            // Load channel metadata and initial contents in parallel
            async let channelResult = services.api.fetchChannel(slug: channelSlug)
            async let contentsResult = services.api.fetchChannelContents(
                slug: channelSlug,
                page: 1,
                sort: sortParam(for: selection),
                direction: sortDirection(for: selection)
            )
            
            let channel = try await channelResult
            let contents = try await contentsResult
            let totalPages = Int(ceil(Double(channel.length) / Double(20)))
            
            channelState = .loaded(
                channel: channel,
                contents: contents.contents ?? [],
                currentPage: 2, // Next page to load
                totalPages: totalPages,
                isLoadingMore: false
            )
        } catch {
            channelState = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    private func loadMoreContent() async {
        guard case .loaded(let channel, let currentContents, let currentPage, let totalPages, let isLoadingMore) = channelState,
              currentPage <= totalPages,
              !isLoadingMore else { return }
        
        // Update state to show loading more
        channelState = .loaded(
            channel: channel,
            contents: currentContents,
            currentPage: currentPage,
            totalPages: totalPages,
            isLoadingMore: true
        )
        
        do {
            let newContents = try await services.api.fetchChannelContents(
                slug: channelSlug,
                page: currentPage,
                sort: sortParam(for: selection),
                direction: sortDirection(for: selection)
            )
            
            channelState = .loaded(
                channel: channel,
                contents: Array(currentContents + (newContents.contents ?? [])),
                currentPage: currentPage + 1,
                totalPages: totalPages,
                isLoadingMore: false
            )
        } catch {
            // Revert loading state on error
            channelState = .loaded(
                channel: channel,
                contents: currentContents,
                currentPage: currentPage,
                totalPages: totalPages,
                isLoadingMore: false
            )
        }
    }
    
    @MainActor
    private func refreshChannel() async {
        channelState = .loading
        await loadChannel()
    }
    
    @MainActor
    private func loadConnections() async {
        connectionsState = .loading
        
        do {
            let result = try await services.api.fetchChannelConnections(slug: channelSlug, page: 1)
            connectionsState = .loaded(
                result.channels,
                currentPage: 2,
                totalPages: result.totalPages,
                isLoadingMore: false
            )
        } catch {
            connectionsState = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    private func loadMoreConnections() async {
        guard case .loaded(let currentConnections, let currentPage, let totalPages, let isLoadingMore) = connectionsState,
              currentPage <= totalPages,
              !isLoadingMore else { return }
        
        connectionsState = .loaded(currentConnections, currentPage: currentPage, totalPages: totalPages, isLoadingMore: true)
        
        do {
            let result = try await services.api.fetchChannelConnections(slug: channelSlug, page: currentPage)
            connectionsState = .loaded(
                Array(currentConnections + result.channels),
                currentPage: currentPage + 1,
                totalPages: totalPages,
                isLoadingMore: false
            )
        } catch {
            connectionsState = .loaded(currentConnections, currentPage: currentPage, totalPages: totalPages, isLoadingMore: false)
        }
    }
    
    private func sortParam(for option: SortOption) -> String {
        switch option {
        case .position: return "position"
        case .newest: return "created_at"
        case .oldest: return "created_at"
        }
    }
    
    private func sortDirection(for option: SortOption) -> String {
        switch option {
        case .position: return "desc"
        case .newest: return "desc"
        case .oldest: return "asc"
        }
    }
    
    private func loadMoreChannelData(block: Block) {
        guard case .loaded(_, let contents, _, _, let isLoadingMore) = channelState,
              contents.count >= 8,
              contents[contents.count - 8].id == block.id,
              !isLoadingMore else { return }
        
        Task {
            await loadMoreContent()
        }
    }
}

struct ChannelViewHeader: View {
    let channel: ArenaChannel
    @Binding var content: ContentOption
    @Binding var showingConnections: Bool
    @State var descriptionExpanded = false
    var contentOptions: [ContentOption]
    
    var body: some View {
        let channelTitle = channel.title
        let channelCreatedAt = channel.createdAt
        let channelCreated = dateFromString(string: channelCreatedAt)
        let channelUpdatedAt = channel.updatedAt
        let channelUpdated = relativeTime(channelUpdatedAt)
        let channelStatus = channel.status
        let channelDescription = channel.metadata?.description ?? ""
        let channelOwner = channel.user.fullName
        let channelOwnerId = channel.user.id
        let channelCollaborators = channel.collaborators
        
        VStack(spacing: 16) {
            // MARK: Channel Title / Dates
            HStack {
                if !channelTitle.isEmpty {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            if channelStatus != "closed" {
                                Image(systemName: "circle.fill")
                                    .scaleEffect(0.5)
                                    .foregroundColor(channelStatus == "public" ? Color.green : Color.red)
                            }
                            Text("\(channelTitle)")
                                .foregroundColor(Color("text-primary"))
                                .font(.system(size: 18))
                                .fontWeight(.semibold)
                        }
                        
                        Text("started ")
                            .foregroundColor(Color("text-secondary"))
                            .font(.system(size: 14)) +
                        Text(channelCreated, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                            .foregroundStyle(Color("text-secondary"))
                            .font(.system(size: 14)) +
                        Text(" • updated \(channelUpdated)")
                            .foregroundColor(Color("text-secondary"))
                            .font(.system(size: 14))
                    }
                } else {
                    VStack(spacing: 4) {
                        Text("loading...")
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                        Text("")
                    }
                }
            }
            .fontDesign(.rounded)
            .foregroundColor(Color("text-primary"))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                // MARK: Channel Description
                if !channelDescription.isEmpty {
                    Text(.init(channelDescription))
                        .tint(Color.primary)
                        .font(.system(size: 15))
                        .fontWeight(.regular)
                        .fontDesign(.default)
                        .foregroundColor(Color("text-secondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(descriptionExpanded ? nil : 2)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                descriptionExpanded.toggle()
                            }
                        }
                        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.4), trigger: descriptionExpanded)
                }
                
                // MARK: Channel Attribution
                if !channelOwner.isEmpty {
                    let ownerLink = NavigationLink(destination: UserView(userId: channelOwnerId)) {
                        Text("\(channelOwner)")
                            .foregroundColor(Color("text-primary"))
                    }
                        .simultaneousGesture(TapGesture().onEnded{
                            AddUserToRabbitHole(user: channel.user)
                        })
                    
                    let collaboratorLinks = channelCollaborators.map { collaborator in
                        NavigationLink(destination: UserView(userId: collaborator.id)) {
                            Text("\(collaborator.fullName)")
                                .fontDesign(.rounded)
                                .fontWeight(.medium)
                                .foregroundColor(Color("text-primary"))
                        }
                        .simultaneousGesture(TapGesture().onEnded{
                            AddUserToRabbitHole(user: collaborator)
                        })
                    }
                    
                    WrappingHStack(alignment: .leading, horizontalSpacing: 4) {
                        Text("by")
                            .foregroundColor(Color("text-secondary"))
                        
                        ownerLink
                        
                        if !collaboratorLinks.isEmpty {
                            Text("with")
                                .foregroundColor(Color("text-secondary"))
                            ForEach(collaboratorLinks.indices, id: \.self) { index in
                                if index > 0 {
                                    Text("&")
                                        .foregroundColor(Color("text-secondary"))
                                }
                                collaboratorLinks[index]
                            }
                        }
                    }
                    .font(.system(size: 15))
                    .fontDesign(.rounded)
                    .fontWeight(.medium)
                } else {
                    Text("by ...")
                        .font(.system(size: 15))
                        .fontDesign(.default)
                        .fontWeight(.regular)
                        .foregroundColor(Color("text-secondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
        }
        .padding(12)
        
        // MARK: Channel Content Options
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(contentOptions, id: \.self) { option in
                    Button(action: {
                        content = option
                        if option.rawValue == "Connections" {
                            showingConnections = true
                        } else {
                            showingConnections = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("\(option.rawValue)")
                                .foregroundStyle(Color(content == option ? "background" : "surface-text-secondary"))
                            
                            if option.rawValue == "All" {
                                Text("\(channel.length)")
                                    .foregroundStyle(Color(content == option ? "surface-text-secondary" : "surface-tertiary"))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(content == option ? "text-primary" : "surface"))
                    .cornerRadius(16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fontDesign(.rounded)
            .fontWeight(.semibold)
            .font(.system(size: 15))
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 4)
    }
}

#Preview {
    NavigationView {
        // ChannelView(channelSlug: "hi-christina-will-you-go-out-with-me")
        ChannelView(channelSlug: "posterikas")
        // ChannelView(channelSlug: "competitive-design-website-repo")
        // ChannelView(channelSlug: "christina-bgfz4hkltss")
        // ChannelView(channelSlug: "arena-swift-models-test")
    }
}

