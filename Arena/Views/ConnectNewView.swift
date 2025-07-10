//
//  ConnectNewView.swift
//  Arena
//
//  Created by Yihui Hu on 12/12/23.
//

import SwiftUI
import Defaults

struct ConnectNewView: View {
    @StateObject var channelsData: ChannelsData
    @Environment(\.services) private var services
    @FocusState private var searchInputIsFocused: Bool
    
    @State private var searchTerm: String = ""
    @State private var searchResults: ArenaSearchResults?
    @State private var isLoading = false
    @State private var selection: String = "Channels"
    @State private var channelsToConnect: [String] = []
    @State private var isConnecting: Bool = false
    
    @Binding var imageData: [Data]
    @Binding var textData: String
    @Binding var linkData: [String]
    @Binding var titleData: [String]
    @Binding var descriptionData: [String]
    
    @Environment(\.dismiss) private var dismiss
    
    init(imageData: Binding<[Data]>, textData: Binding<String>, linkData: Binding<[String]>, titleData: Binding<[String]>, descriptionData: Binding<[String]>) {
        self._channelsData = StateObject(wrappedValue: ChannelsData(userId: Defaults[.userId]))
        self._imageData = imageData
        self._textData = textData
        self._linkData = linkData
        self._titleData = titleData
        self._descriptionData = descriptionData
    }
    
    var body: some View {
        let userChannels = channelsData.channels?.channels ?? []
        
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 12) {
                TextField("Search...", text: $searchTerm)
                    .onChange(of: searchTerm, debounceTime: .seconds(0.5)) { newValue in
                        Task {
                            if newValue.isEmpty {
                                searchResults = nil
                            } else {
                                await searchChannels(query: newValue)
                            }
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .textFieldStyle(SearchBarStyle())
                    .autocorrectionDisabled()
                    .onAppear {
                        UITextField.appearance().clearButtonMode = .always
                    }
                    .focused($searchInputIsFocused)
                    .onSubmit {
                        Task {
                            await searchChannels(query: searchTerm)
                        }
                    }
                    .submitLabel(.search)
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
                
                if !(channelsToConnect.isEmpty), !searchInputIsFocused {
                    Button(action: {
                        isConnecting = true
                        Defaults[.connectedItem] = true
                        
                        if !(imageData.isEmpty) {
                            Task {
                                await connectImagesToChannel(channels: channelsToConnect, selectedPhotosData: imageData, titles: titleData, descriptions: descriptionData) {
                                    isConnecting = false
                                    channelsToConnect = []
                                }
                            }
                        } else if !(textData.isEmpty) {
                            Task {
                                await connectTextToChannel(channels: channelsToConnect, text: textData, title: titleData, description: descriptionData) {
                                    isConnecting = false
                                    channelsToConnect = []
                                }
                            }
                        } else if !(linkData.isEmpty) {
                            Task {
                                await connectLinksToChannel(channels: channelsToConnect, links: linkData, title: titleData, description: descriptionData) {
                                    isConnecting = false
                                    channelsToConnect = []
                                }
                            }
                        }
                    }) {
                        if isConnecting {
                            CircleLoadingSpinner(customColor: "background", customBgColor: "surface")
                        } else {
                            Text("Connect")
                                .font(.system(size: 15))
                                .fontWeight(.medium)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color("background"))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("text-primary"))
                    .cornerRadius(64)
                    .disabled(isConnecting)
                }
            }
            .animation(.bouncy(duration: 0.3), value: UUID())
            .padding(16)
            
            // List of channels
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let searchResults = searchResults, searchTerm != "" {
                        ForEach(searchResults.channels, id: \.id) { channel in
                            Button(action: {
                                searchInputIsFocused = false
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    if channelsToConnect.contains(channel.slug) {
                                        channelsToConnect.removeAll { $0 == channel.slug }
                                    } else {
                                        channelsToConnect.append(channel.slug)
                                    }
                                }
                            }) {
                                SmallChannelPreview(channel: channel)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(channelsToConnect.contains(channel.slug) ? Color("surface-text-secondary") : Color.clear, lineWidth: 2)
                                    )
                                    .padding(.bottom, 8)
                                    .onBecomingVisible {
                                        // Note: Simplified - removed pagination for connect view
                                    }
                            }
                            .buttonStyle(ConnectChannelButtonStyle())
                        }
                        
                        if isLoading, searchTerm != "" {
                            CircleLoadingSpinner()
                                .padding(.vertical, 12)
                        }
                        
                        if searchResults.channels.isEmpty {
                            EmptySearch(items: "channels", searchTerm: searchTerm)
                        }
                    } else if isLoading, searchTerm != "" {
                        CircleLoadingSpinner()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.top, 64)
                    } else {
                        if !channelsData.isLoading, userChannels.isEmpty {
                            EmptyUserChannels()
                        } else {
                            ForEach(Array(zip(userChannels.indices, userChannels)), id: \.0) { _, channel in
                                Button(action: {
                                    searchInputIsFocused = false
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        if channelsToConnect.contains(channel.slug) {
                                            channelsToConnect.removeAll { $0 == channel.slug }
                                        } else {
                                            channelsToConnect.append(channel.slug)
                                        }
                                    }
                                }) {
                                    SmallChannelPreviewUser(channel: channel)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(channelsToConnect.contains(channel.slug) ? Color("surface-text-secondary") : Color.clear, lineWidth: 2)
                                        )
                                        .padding(.bottom, 8)
                                        .onBecomingVisible {
                                            if userChannels.count >= 1 {
                                                if userChannels[userChannels.count - 1].id == channel.id {
                                                    channelsData.loadMore(userId: Defaults[.userId])
                                                }
                                            }
                                        }
                                }
                                .buttonStyle(ConnectChannelButtonStyle())
                            }
                            
                            if channelsData.isLoading {
                                CircleLoadingSpinner()
                                    .padding(.top, 16)
                                    .padding(.bottom, 12)
                            }
                            
                            if channelsData.currentPage > channelsData.totalPages {
                                EndOfUser()
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .contentMargins(.top, 1)
        .contentMargins(.top, -1, for: .scrollIndicators)
        .padding(.bottom, 4)
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
        }
        .toolbarBackground(Color("background"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func searchChannels(query: String) async {
        isLoading = true
        
        do {
            let results: ArenaSearchResults = try await services.api.search("/search/channels", query: query, page: 1, per: 20)
            searchResults = results
        } catch {
            print("Search error: \(error)")
            searchResults = nil
        }
        
        isLoading = false
    }
}
