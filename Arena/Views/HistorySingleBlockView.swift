//
//  HistorySingleBlockView.swift
//  Arena
//
//  Created by Yihui Hu on 3/1/24.
//

import SwiftUI
import Defaults

struct HistorySingleBlockView: View {
    let blockId: Int
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    let bottomPaddingExtra: CGFloat = Defaults[.hasNotch] ? 12.0 : 24.0
    
    @State private var showInfoModal: Bool = false
    @State private var titleExpanded: Bool = false
    @State private var descriptionExpanded: Bool = false
    @State private var isConnectionsView = true
    @State private var blockState: BlockState = .loading
    @State private var connectionsState: ConnectionsState = .idle
    
    enum BlockState {
        case loading
        case loaded(Block)
        case error(String)
    }
    
    enum ConnectionsState {
        case idle
        case loading
        case loaded(connections: [BlockConnection], comments: [BlockComment])
        case error(String)
    }
    
    var body: some View {
        let screenHeight = UIScreen.main.bounds.size.height
        let screenWidth = UIScreen.main.bounds.size.width
        let bottomPadding: CGFloat = screenHeight * 0.4 + bottomPaddingExtra
        
        NavigationView {
            switch blockState {
            case .loading:
                CircleLoadingSpinner()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let block):
                BlockPreview(blockData: block, fontSize: 16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, showInfoModal ? bottomPadding : 0)
                    .padding(.top, showInfoModal ? 16 : 0)
                    .frame(maxHeight: showInfoModal ? .infinity : screenHeight * 0.6)
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Error loading block")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        Task {
                            await loadBlock()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color("background"))
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    BackButton()
                }
            }
        }
        .toolbarBackground(Color("background"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if case .loaded(let block) = blockState {
                overlayContent(block: block, screenHeight: screenHeight, screenWidth: screenWidth)
            }
        }
        .contentMargins(.top, 16)
        .task {
            await loadBlock()
        }
    }
    
    @ViewBuilder
    private func overlayContent(block: Block, screenHeight: CGFloat, screenWidth: CGFloat) -> some View {
        ZStack {
            // Share button
            ShareLink(item: URL(string: "https://are.na/block/\(block.id)")!) {
                Image(systemName: "square.and.arrow.up")
                    .fontWeight(.bold)
                    .imageScale(.small)
                    .foregroundStyle(Color("text-primary"))
                    .padding(.bottom, 4)
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .offset(x: -80)
            
            // Connect button
            Button(action: {
                Defaults[.connectSheetOpen] = true
                Defaults[.connectItemId] = block.id
                Defaults[.connectItemType] = "Block"
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
            
            // Info modal
            infoModal(block: block, screenHeight: screenHeight, screenWidth: screenWidth)
        }
        .padding(.top, showInfoModal ? screenHeight * 0.4 : 0)
        .padding(.bottom, showInfoModal ? 4 : 16)
    }
    
    @ViewBuilder
    private func infoModal(block: Block, screenHeight: CGFloat, screenWidth: CGFloat) -> some View {
        ZStack {
            if showInfoModal {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        blockInfoContent(block: block, screenWidth: screenWidth)
                        connectionsAndComments()
                    }
                    .opacity(showInfoModal ? 1 : 0)
                }
            }
            
            modalToggleButtons()
        }
        .frame(maxWidth: showInfoModal ? 360 : 40, maxHeight: showInfoModal ? screenHeight * 0.4 : 40, alignment: .top)
        .background(.thinMaterial)
        .clipShape(showInfoModal ? RoundedRectangle(cornerRadius: 24) : RoundedRectangle(cornerRadius: 100))
        .offset(x: showInfoModal ? 0 : 80, y: showInfoModal ? -8 : 0)
        .padding(.horizontal, 16)
        .zIndex(9)
        .onChange(of: showInfoModal) { _, _ in
            if showInfoModal {
                fetchConnectionsAndComments()
            }
        }
    }
    
    @ViewBuilder
    private func modalToggleButtons() -> some View {
        ZStack {
            Button(action: {
                withAnimation(.bouncy(duration: 0.3, extraBounce: -0.1)) {
                    showInfoModal.toggle()
                }
            }) {
                Image(systemName: "chevron.up")
                    .foregroundStyle(Color("text-primary"))
                    .fontWeight(.bold)
                    .frame(width: 40, height: 40)
                    .imageScale(.small)
            }
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.4), trigger: showInfoModal)
            .offset(x: showInfoModal ? 120 : 0, y: showInfoModal ? -40 : 0)
            .opacity(showInfoModal ? 0 : 1)
            .scaleEffect(showInfoModal ? 0 : 1)
            
            Button(action: {
                withAnimation(.bouncy(duration: 0.3, extraBounce: -0.1)) {
                    showInfoModal.toggle()
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .fontWeight(.bold)
                    .foregroundStyle(Color("surface-text-secondary"))
            }
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.4), trigger: showInfoModal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: showInfoModal ? -40 : 24, y: showInfoModal ? 40 : -24)
            .opacity(showInfoModal ? 1 : 0)
            .scaleEffect(showInfoModal ? 1.2 : 0)
        }
    }
    
    @ViewBuilder
    private func blockInfoContent(block: Block, screenWidth: CGFloat) -> some View {
        let blockURL = "https://are.na/block/\(block.id)"
        let title = block.title 
        let description = block.description ?? ""
        let createdAt = block.createdAt 
        let updatedAt = block.updatedAt
        let by = block.user.username
        let byId = block.user.id
        let image = block.image?.filename ?? ""
        let imageURL = block.image?.original.url ?? blockURL
        let source = block.source?.title ?? block.source?.url ?? ""
        let sourceURL = block.source?.url ?? blockURL
        let attachment = block.attachment?.filename ?? ""
        let attachmentURL = block.attachment?.url ?? blockURL
        
        VStack(spacing: 20) {
            // Title and Description
            VStack(alignment: .leading, spacing: 4) {
                Text("\(title != "" ? title : "No title")")
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .font(.system(size: 18))
                    .lineLimit(titleExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: screenWidth * 0.72, alignment: .topLeading)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            titleExpanded.toggle()
                        }
                    }
                
                Text("\(description != "" ? description : "No description")")
                    .font(.system(size: 16))
                    .lineLimit(descriptionExpanded ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color("surface-text-secondary"))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            descriptionExpanded.toggle()
                        }
                    }
            }
            
            // Metadata
            VStack(spacing: 4) {
                metadataRow(title: "Created", value: createdAt != "" ? relativeTime(createdAt) : "unknown")
                metadataRow(title: "Updated", value: updatedAt != "" ? relativeTime(updatedAt) : "unknown")
                
                HStack(spacing: 20) {
                    Text("By")
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                    Spacer()
                    NavigationLink(destination: UserView(userId: byId)) {
                        Text("\(by != "" ? by : "unknown")")
                            .foregroundStyle(Color("text-primary"))
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    .simultaneousGesture(TapGesture().onEnded{
                        AddUserToRabbitHole(user: block.user)
                    })
                }
                Divider().frame(height: 0.5)
                
                // Block source
                if !(source.isEmpty) {
                    BlockSource(source: source, sourceURL: sourceURL)
                } else if !(attachment.isEmpty) {
                    BlockSource(source: attachment, sourceURL: attachmentURL)
                } else if !(image.isEmpty) {
                    BlockSource(source: image, sourceURL: imageURL)
                } else {
                    BlockSource(source: blockURL, sourceURL: blockURL)
                }
            }
            .font(.system(size: 15))
            
            // Action buttons
            actionButtons(block: block, blockURL: blockURL, imageURL: imageURL)
        }
    }
    
    @ViewBuilder
    private func metadataRow(title: String, value: String) -> some View {
        HStack(spacing: 20) {
            Text(title)
                .fontDesign(.rounded)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundStyle(Color("surface-text-secondary"))
        }
        Divider().frame(height: 0.5)
    }
    
    @ViewBuilder
    private func actionButtons(block: Block, blockURL: String, imageURL: String) -> some View {
        HStack {
            Button(action: {
                Defaults[.connectSheetOpen] = true
                Defaults[.connectItemId] = block.id
                Defaults[.connectItemType] = "Block"
            }) {
                Text("Connect")
                    .font(.system(size: 15))
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("surface"))
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color("background-inverse"))
            .cornerRadius(12)
            
            Spacer().frame(width: 16)
            
            Menu {
                ShareLink(item: URL(string: "\(blockURL)")!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                if block.contentClass == "Image" {
                    Button(action: {
                        Defaults[.safariViewURL] = "https://lens.google.com/uploadbyurl?url=\(imageURL)"
                        Defaults[.safariViewOpen] = true
                    }) {
                        Label("Find original", systemImage: "sparkle.magnifyingglass")
                    }
                }
            } label: {
                Text("Actions")
                    .font(.system(size: 15))
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("text-primary"))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color("surface-tertiary"))
                    .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private func connectionsAndComments() -> some View {
        VStack {
            switch connectionsState {
            case .idle:
                EmptyView()
            case .loading:
                CircleLoadingSpinner()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 12)
            case .loaded(let connections, let comments):
                VStack {
                    tabSelector(connectionsCount: connections.count, commentsCount: comments.count)
                    tabContent(connections: connections, comments: comments)
                }
            case .error(let message):
                Text("Error: \(message)")
                    .foregroundStyle(Color.red)
                    .padding()
            }
        }
    }
    
    @ViewBuilder
    private func tabSelector(connectionsCount: Int, commentsCount: Int) -> some View {
        HStack {
            Spacer()
            Button(action: { isConnectionsView = true }) {
                Text("Connections (\(connectionsCount))")
                    .fontWeight(.medium)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color(isConnectionsView ? "text-primary" : "surface-text-secondary"))
            }
            Spacer()
            Button(action: { isConnectionsView = false }) {
                Text("Comments (\(commentsCount))")
                    .fontWeight(.medium)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color(isConnectionsView ? "surface-text-secondary" : "text-primary"))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .font(.system(size: 14))
        
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color(isConnectionsView ? "text-primary" : "text-secondary"))
                .frame(maxWidth: .infinity, maxHeight: 1)
            Rectangle()
                .fill(Color(isConnectionsView ? "text-secondary" : "text-primary"))
                .frame(maxWidth: .infinity, maxHeight: 1)
        }
    }
    
    @ViewBuilder
    private func tabContent(connections: [BlockConnection], comments: [BlockComment]) -> some View {
        LazyVStack(spacing: isConnectionsView ? 12 : 24) {
            if isConnectionsView {
                connectionsContent(connections: connections)
            } else {
                commentsContent(comments: comments)
            }
        }
        .padding(.top, 12)
    }
    
    @ViewBuilder
    private func connectionsContent(connections: [BlockConnection]) -> some View {
        ForEach(connections, id: \.id) { connection in
            NavigationLink(destination: ChannelView(channelSlug: connection.slug)) {
                connectionRow(connection: connection)
            }
            .simultaneousGesture(TapGesture().onEnded{
                let id = UUID()
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm, d MMM y"
                let timestamp = formatter.string(from: Date.now)
                Defaults[.rabbitHole].insert(RabbitHoleItem(id: id.uuidString, type: "channel", subtype: connection.status, itemId: connection.slug, timestamp: timestamp, mainText: connection.title, subText: String(connection.length), imageUrl: String(connection.id)), at: 0)
            })
        }
    }
    
    @ViewBuilder
    private func connectionRow(connection: BlockConnection) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if connection.status != "closed" {
                    Image(systemName: "circle.fill")
                        .scaleEffect(0.5)
                        .foregroundColor(connection.status == "public" ? Color.green : Color.red)
                }
                Text("\(connection.title)")
                    .foregroundStyle(Color("text-primary"))
                    .font(.system(size: 16))
                    .lineLimit(1)
                    .fontDesign(.rounded)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Text("\(connection.length) items")
                .font(.system(size: 14))
                .lineLimit(1)
                .foregroundStyle(Color("surface-text-secondary"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("surface-tertiary"), lineWidth: 2)
        )
    }
    
    @ViewBuilder
    private func commentsContent(comments: [BlockComment]) -> some View {
        if comments.count == 0 {
            EmptyBlockComments()
        } else {
            ForEach(comments, id: \.id) { comment in
                commentRow(comment: comment)
            }
        }
    }
    
    @ViewBuilder
    private func commentRow(comment: BlockComment) -> some View {
        HStack(alignment: .top, spacing: 8) {
            NavigationLink(destination: UserView(userId: comment.user.id)) {
                ProfilePic(imageURL: comment.user.avatarImage.display, initials: comment.user.initials)
            }
            .simultaneousGesture(TapGesture().onEnded{
                AddUserToRabbitHole(user: comment.user)
            })
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    NavigationLink(destination: UserView(userId: comment.user.id)) {
                        Text("\(comment.user.fullName)")
                            .foregroundStyle(Color("text-primary"))
                            .fontDesign(.rounded)
                            .fontWeight(.medium)
                    }
                    .simultaneousGesture(TapGesture().onEnded{
                        AddUserToRabbitHole(user: comment.user)
                    })
                    Spacer()
                    Text("\(relativeTime(comment.createdAt))")
                        .foregroundStyle(Color("surface-text-secondary"))
                        .font(.system(size: 14))
                }
                Text("\(comment.body)")
                    .foregroundStyle(Color("text-primary"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: 15))
        }
    }
    
    @MainActor
    private func loadBlock() async {
        blockState = .loading
        
        do {
            let block = try await services.api.fetchBlock(id: blockId)
            blockState = .loaded(block)
        } catch {
            blockState = .error(error.localizedDescription)
        }
    }
    
    private func fetchConnectionsAndComments() {
        Task {
            await loadConnectionsAndComments()
        }
    }
    
    @MainActor
    private func loadConnectionsAndComments() async {
        connectionsState = .loading
        
        do {
            // Fetch connections and comments in parallel
            async let connectionsResult = services.api.fetchBlockConnections(id: blockId)
            async let commentsResult = fetchAllComments(blockId: blockId)
            
            let connections = try await connectionsResult.connections
            let comments = try await commentsResult
            
            connectionsState = .loaded(connections: connections, comments: comments)
        } catch {
            connectionsState = .error(error.localizedDescription)
        }
    }
    
    private func fetchAllComments(blockId: Int) async throws -> [BlockComment] {
        var allComments: [BlockComment] = []
        var currentPage = 1
        var totalPages = 1
        
        repeat {
            let result = try await services.api.fetchBlockComments(id: blockId, page: currentPage)
            allComments.append(contentsOf: result.comments)
            totalPages = Int(ceil(Double(result.length) / Double(20)))
            currentPage += 1
        } while currentPage <= totalPages
        
        return allComments.reversed()
    }
}

