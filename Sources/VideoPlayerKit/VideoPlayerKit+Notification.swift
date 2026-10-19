//
//  VideoPlayerKit+Notification.swift
//

import SwiftUI

public extension Notification.Name {
    static let playerInitializing = Notification.Name("com.digitaldementia.VideoPlayerKit.playerInitializing")
    /// The media reached its own end. Distinct from `playerPlaybackStopped`, which a teardown or a
    /// reload also produces: this one only ever means the item finished playing.
    static let playerPlaybackEnded = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackEnded")
    static let playerPlaybackError = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackError")
    static let playerPlaybackPaused = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackPaused")
    static let playerPlaybackResumed = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackResumed")
    static let playerPlaybackStarted = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackStarted")
    static let playerPlaybackStopped = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackStopped")
    static let playerPlaybackTimeChanged = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackTimeChanged")
    static let playerTogglePlayPause = Notification.Name("com.digitaldementia.VideoPlayerKit.playerTogglePlayPause")
    static let playerTriggerReload = Notification.Name("com.digitaldementia.VideoPlayerKit.playerTriggerReload")
    static let playerSeek = Notification.Name("com.digitaldementia.VideoPlayerKit.playerSeek")
}
