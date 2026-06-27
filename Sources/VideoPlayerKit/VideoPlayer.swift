//
//  VideoPlayer.swift
//

import SwiftUI


@MainActor
@ViewBuilder
public func VideoPlayer(profile: VideoPlayerProfile = .precise, url: String, referer: String, isLive: Bool, isMuted: Bool, seekInterval: Int = 30) -> some View {
    #if canImport(UIKit)
    UIViewVLCPlayer(profile: profile, url: url, referer: referer, isLive: isLive, isMuted: isMuted, seekInterval: seekInterval)
    #elseif canImport(AppKit)
    NSViewVLCPlayer(profile: profile, url: url, referer: referer, isLive: isLive, isMuted: isMuted, seekInterval: seekInterval)
    #endif
}
