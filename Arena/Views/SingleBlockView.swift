//
//  SingleBlockView.swift
//  Arena
//
//  Created by Yihui Hu on 21/10/23.
//

import SwiftUI
import Defaults

struct SingleBlockView: View {
    let block: Block
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    let bottomPaddingExtra: CGFloat = Defaults[.hasNotch] ? 12.0 : 24.0
    
    @State private var showInfoModal: Bool = false
    @State private var selectedConnectionSlug: String?
    @State private var scrollOffset: CGFloat = 0
    @State private var showGradient: Bool = false
    @State private var titleExpanded: Bool = false
    @State private var descriptionExpanded: Bool = false
    @State private var isConnectionsView = true
    @State private var viewState: ViewState = .idle
    
    enum ViewState {
        case idle
        case loading
        case loaded(connections: [BlockConnection], comments: [BlockComment])
        case error(String)
    }
    
    struct InfoModalButton: View {
        @Binding var showInfoModal: Bool
        var icon: String
        
        var body: some View {
            Button(action: {
                withAnimation(.bouncy(duration: 0.3, extraBounce: -0.1)) {
                    showInfoModal.toggle()
                }
            }) {
                Image(systemName: icon)
                    .foregroundStyle(Color("text-primary"))
                    .fontWeight(.semibold)
            }
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.4), trigger: showInfoModal)
        }
    }
    
    var body: some View {
        let screenHeight = UIScreen.main.bounds.size.height
        let screenWidth = UIScreen.main.bounds.size.width
        let bottomPadding: CGFloat = screenHeight * 0.4 + bottomPaddingExtra
        
        NavigationView {
            BlockPreview(blockData: block, fontSize: 16)
                .padding(.horizontal, 16)
                .padding(.bottom, showInfoModal ? bottomPadding : 0)
                .padding(.top, showInfoModal ? 16 : 0)
                .frame(maxHeight: showInfoModal ? .infinity : screenHeight * 0.6)
        }
        .background(Color("background"))
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
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
            // Floating action buttons
            ZStack {
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
                
                ZStack {
                    if showInfoModal {
                        HStack(alignment: .top) {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 20) {
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
                                            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.4), trigger: titleExpanded)
                                        
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
                                            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.4), trigger: descriptionExpanded)
                                    }
                                    
                                    // Metadata
                                    VStack(spacing: 4) {
                                        // Added date
                                        HStack(spacing: 20) {
                                            Text("Created")
                                                .fontDesign(.rounded)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text("\(createdAt != "" ? relativeTime(createdAt) : "unknown")")
                                                .foregroundStyle(Color("surface-text-secondary"))
                                        }
                                        Divider().frame(height: 0.5)
                                        
                                        // Updated date
                                        HStack(spacing: 20) {
                                            Text("Updated")
                                                .fontDesign(.rounded)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text("\(updatedAt != "" ? relativeTime(updatedAt) : "unknown")")
                                                .foregroundStyle(Color("surface-text-secondary"))
                                        }
                                        Divider().frame(height: 0.5)
                                        
                                        // By
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
                                            .id(byId)
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
                                    
                                    // Connect and Actions Button
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
                                            
                                            if block.contentClass == "Image", let url = URL(string: imageURL) {
                                                Button {
                                                    Defaults[.toastMessage] = "Saving image..."
                                                    Defaults[.showToast] = true
                                                    
                                                    let task = URLSession.shared.dataTask(with: url) { data, response, error in
                                                        guard let data = data else { return }
                                                        DispatchQueue.main.async {
                                                            let image = UIImage(data: data) ?? UIImage()
                                                            let imageSaver = ImageSaver()
                                                            imageSaver.writeToPhotoAlbum(image: image)
                                                        }
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                            Defaults[.showToast] = false
                                                        }
                                                    }
                                                    task.resume()
                                                } label: {
                                                    Label("Save Image", systemImage: "square.and.arrow.down")
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
                                    
                                    // Connections and Comments
                                    VStack {
                                        switch viewState {
                                        case .idle:
                                            EmptyView()
                                        case .loading:
                                            CircleLoadingSpinner()
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .padding(.vertical, 12)
                                        case .loaded(let connections, let comments):
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    Button(action: { isConnectionsView = true }) {
                                                        Text("Connections (\(connections.count))")
                                                            .fontWeight(.medium)
                                                            .fontDesign(.rounded)
                                                            .frame(maxWidth: .infinity)
                                                            .foregroundStyle(Color(isConnectionsView ? "text-primary" : "surface-text-secondary"))
                                                    }
                                                    Spacer()
                                                    Button(action: { isConnectionsView = false }) {
                                                        Text("Comments (\(comments.count))")
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
                                                
                                                LazyVStack(spacing: isConnectionsView ? 12 : 24) {
                                                    if isConnectionsView {
                                                        ForEach(connections, id: \.id) { connection in
                                                            NavigationLink(destination: ChannelView(channelSlug: connection.slug)) {
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
                                                            .simultaneousGesture(TapGesture().onEnded{
                                                                let id = UUID()
                                                                let formatter = DateFormatter()
                                                                formatter.dateFormat = "HH:mm, d MMM y"
                                                                let timestamp = formatter.string(from: Date.now)
                                                                Defaults[.rabbitHole].insert(RabbitHoleItem(id: id.uuidString, type: "channel", subtype: connection.status, itemId: connection.slug, timestamp: timestamp, mainText: connection.title, subText: String(connection.length), imageUrl: String(connection.id)), at: 0)
                                                            })
                                                        }
                                                    } else {
                                                        if (comments.count == 0) {
                                                            EmptyBlockComments()
                                                        } else {
                                                            ForEach(comments, id: \.id) { comment in
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
                                                        }
                                                    }
                                                }
                                                .padding(.top, 12)
                                            }
                                        case .error(let message):
                                            Text("Error: \(message)")
                                                .foregroundStyle(Color.red)
                                                .padding()
                                        }
                                    }
                                }
                                .opacity(showInfoModal ? 1 : 0)
                            }
                        }
                    }
                    
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
                    .onChange(of: showInfoModal) { _, _ in
                        if showInfoModal {
                            fetchConnectionsAndComments()
                        }
                    }
                }
                .frame(maxWidth: showInfoModal ? 360 : 40, maxHeight: showInfoModal ? screenHeight * 0.4 : 40, alignment: .top)
                .background(.thinMaterial)
                .clipShape(showInfoModal ? RoundedRectangle(cornerRadius: 24) : RoundedRectangle(cornerRadius: 100))
                .offset(x: showInfoModal ? 0 : 80, y: showInfoModal ? -8 : 0)
                .padding(.horizontal, 16)
                .zIndex(9)
            }
            .padding(.top, showInfoModal ? screenHeight * 0.4 : 0)
            .padding(.bottom, showInfoModal ? 4 : 16)
        }
        .contentMargins(.top, 16)
    }
    
    private func fetchConnectionsAndComments() {
        Task {
            await loadConnectionsAndComments()
        }
    }
    
    @MainActor
    private func loadConnectionsAndComments() async {
        viewState = .loading
        
        do {
            // Fetch connections and comments in parallel
            async let connectionsResult = services.api.fetchBlockConnections(id: block.id)
            async let commentsResult = fetchAllComments(blockId: block.id)
            
            let connections = try await connectionsResult.connections
            let comments = try await commentsResult
            
            viewState = .loaded(connections: connections, comments: comments)
        } catch {
            viewState = .error(error.localizedDescription)
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
