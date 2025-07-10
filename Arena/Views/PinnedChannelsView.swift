//
//  ChannelsView.swift
//  Arena
//
//  Created by Yihui Hu on 12/10/23.
//

import SwiftUI
import Defaults
import Combine

struct PinnedChannelsView: View {
    @Environment(\.services) private var services
    @Default(.pinnedChannels) var pinnedChannels
    @Default(.pinnedChannelsChanged) var pinnedChannelsChanged
    @Default(.widgetBlockId) var widgetBlockId
    @Default(.widgetTapped) var widgetTapped
    
    @State private var viewState: ViewState = .loading
    
    enum ViewState {
        case loading
        case loaded([ArenaChannelPreview])
        case error(String)
    }
    
    var body: some View {
        NavigationStack {
            HStack(alignment: .center) {
                if pinnedChannels.isEmpty {
                    InitialPinnedChannels()
                } else {
                    switch viewState {
                    case .loading:
                        CircleLoadingSpinner()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    case .loaded(let channels):
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(channels, id: \.id) { channel in
                                    ChannelCard(channel: channel, showPin: false)
                                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 32))
                                        .contextMenu {
                                            Button {
                                                Defaults[.connectSheetOpen] = true
                                                Defaults[.connectItemId] = channel.id
                                                Defaults[.connectItemType] = "Channel"
                                            } label: {
                                                Label("Connect", systemImage: "arrow.right")
                                            }
                                            
                                            Button {
                                                removePinnedChannel(channel.id)
                                                displayToast("Bookmark removed!")
                                            } label: {
                                                Label(pinnedChannels.contains(channel.id) ? "Remove bookmark" : "Bookmark", systemImage: pinnedChannels.contains(channel.id) ? "bookmark.fill" : "bookmark")
                                            }
                                        }
                                }
                            }
                        }
                        .padding(.bottom, 4)
                        .refreshable {
                            do { try await Task.sleep(nanoseconds: 500_000_000) } catch {}
                            await loadPinnedChannels()
                        }
                    case .error(let message):
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text("Error loading bookmarks")
                                .font(.headline)
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task {
                                    await loadPinnedChannels()
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
            }
            .task {
                await loadPinnedChannels()
            }
            .onChange(of: pinnedChannelsChanged) { _, changed in
                if changed {
                    Task {
                        await loadPinnedChannels()
                    }
                    Defaults[.pinnedChannelsChanged] = false
                }
            }
            .navigationDestination(isPresented: $widgetTapped) {
                HistorySingleBlockView(blockId: widgetBlockId)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Bookmarks")
                        .foregroundStyle(Color("text-primary"))
                        .font(.system(size: 20))
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color("background"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(Color("background"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color("background"))
        .contentMargins(.leading, 0, for: .scrollIndicators)
        .contentMargins(16)
    }
    
    @MainActor
    private func loadPinnedChannels() async {
        guard !pinnedChannels.isEmpty else {
            viewState = .loaded([])
            return
        }
        
        viewState = .loading
        
        do {
            let channels = try await services.api.fetchPinnedChannels(channelIds: pinnedChannels)
            viewState = .loaded(channels)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    private func removePinnedChannel(_ channelId: Int) {
        // Remove from local state immediately for responsive UI
        if case .loaded(let channels) = viewState {
            let updatedChannels = channels.filter { $0.id != channelId }
            viewState = .loaded(updatedChannels)
        }
        
        // Remove from pinned channels array
        pinnedChannels.removeAll { $0 == channelId }
    }
}

#Preview {
    PinnedChannelsView()
}
