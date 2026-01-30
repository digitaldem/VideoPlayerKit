//
//  VideoPlayerKit+Notification.swift
//

import SwiftUI

public extension Notification.Name {
    static let playerInitializing = Notification.Name("com.digitaldementia.VideoPlayerKit.playerInitializing")
    static let playerPlaybackError = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackError")
    static let playerPlaybackPaused = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackPaused")
    static let playerPlaybackStarted = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackStarted")
    static let playerPlaybackStopped = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackStopped")
    static let playerPlaybackTimeChanged = Notification.Name("com.digitaldementia.VideoPlayerKit.playerPlaybackTimeChanged")
    static let playerStallDetected  = Notification.Name("com.digitaldementia.VideoPlayerKit.playerStallDetected")
    static let playerStallResolved  = Notification.Name("com.digitaldementia.VideoPlayerKit.playerStallResolved")
    static let playerTogglePlayPause = Notification.Name("com.digitaldementia.VideoPlayerKit.playerTogglePlayPause")
    static let playerTriggerReload = Notification.Name("com.digitaldementia.VideoPlayerKit.playerTriggerReload")
}
