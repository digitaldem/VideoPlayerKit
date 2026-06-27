//
//  VLCPlaybackCoordinator.swift
//

import Foundation
#if os(macOS)
import VLCKit
#elseif os(iOS)
import MobileVLCKit
#elseif os(tvOS)
import TVVLCKit
#endif

@MainActor
class VLCPlaybackCoordinator: NSObject, @preconcurrency VLCMediaPlayerDelegate {
    var url: URL?
    var referer: URL?
    var profile: VideoPlayerProfile?
    var isMuted = false
    var seekInterval = 30

    private(set) var totalMinutes = 0
    private var lastPublishedMinute = -1
    private var didSendPlaybackEvent = false

    var reloadObserver: NSObjectProtocol?
    var toggleObserver: NSObjectProtocol?
    var seekObserver: NSObjectProtocol?

    /// Overridden by platform subclasses to expose the player they own.
    var mediaPlayer: VLCMediaPlayer? { nil }

    func togglePlayPause() {
        guard let mediaPlayer else { return }
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
    }

    func performSeek(interval: Int) {
        guard let mediaPlayer else { return }
        if interval > 0 {
            mediaPlayer.jumpForward(Int32(interval))
        } else if interval < 0 {
            mediaPlayer.jumpBackward(Int32(-interval))
        }
    }

    /// Clears per-session tracking so a reloaded player re-announces playback start
    /// and resumes emitting playerPlaybackTimeChanged from the current position.
    func resetPlaybackTracking() {
        lastPublishedMinute = -1
        didSendPlaybackEvent = false
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        let isHLS = (url?.pathExtension.lowercased() == "m3u8")

        switch player.state {
        case .opening:
            print("🌐 VLC Player: opening...")

        case .buffering:
            break

        case .esAdded:
            print("➕ VLC Player: elementary stream added")
            if isHLS, !didSendPlaybackEvent {
                didSendPlaybackEvent = true
                NotificationCenter.default.post(
                    name: .playerPlaybackStarted,
                    object: nil,
                    userInfo: ["url": url as Any]
                )
            }

        case .playing:
            print("▶️ VLC Player: stream playing")
            NotificationCenter.default.post(
                name: .playerPlaybackResumed,
                object: nil,
                userInfo: ["url": url as Any]
            )
            if !isHLS, !didSendPlaybackEvent {
                if totalMinutes == 0 {
                    totalMinutes = Int(player.media?.length.intValue ?? 0) / 1000 / 60
                }
                didSendPlaybackEvent = true
                NotificationCenter.default.post(
                    name: .playerPlaybackStarted,
                    object: nil,
                    userInfo: ["url": url as Any]
                )
            }

        case .paused:
            print("⏸️ VLC Player: stream paused")
            NotificationCenter.default.post(
                name: .playerPlaybackPaused,
                object: nil,
                userInfo: ["url": url as Any]
            )

        case .stopped:
            // No-op: stop is also triggered by our own reload/teardown paths, so it
            // doesn't reliably mean "playback ended" and isn't posted as an event.
            print("⏹️ VLC Player: stream stopped")

        case .ended:
            print("⏏️ VLC Player: stream ended")

        case .error:
            print("⚠️ VLC Player: error")
            NotificationCenter.default.post(
                name: .playerPlaybackError,
                object: nil,
                userInfo: ["url": url as Any]
            )

        @unknown default:
            print("❓ VLC Player: unknown state [\(player.state.rawValue)]")
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        let currentMS = Int(player.time.intValue)
        guard currentMS > 0 else { return }
        let currentMinute = currentMS / 1000 / 60
        if currentMinute > lastPublishedMinute {
            lastPublishedMinute = currentMinute
            NotificationCenter.default.post(
                name: .playerPlaybackTimeChanged,
                object: nil,
                userInfo: [
                    "total": totalMinutes,
                    "current": currentMinute
                ]
            )
        }
    }
}
