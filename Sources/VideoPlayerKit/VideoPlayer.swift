//
//  VideoPlayer.swift
//

import SwiftUI


@MainActor
@ViewBuilder
public func VideoPlayer(url: String, referer: String, isLive: Bool, isMuted: Bool) -> some View {
    #if canImport(UIKit)
    UIViewVLCPlayer(url: url, referer: referer, isLive: isLive, isMuted: isMuted)
    #elseif canImport(AppKit)
    NSViewVLCPlayer(url: url, referer: referer, isLive: isLive, isMuted: isMuted)
    #endif
}
