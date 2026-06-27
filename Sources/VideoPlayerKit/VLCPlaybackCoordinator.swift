//
//  VLCPlaybackCoordinator.swift
//

import Foundation
#if os(macOS)
@preconcurrency import VLCKit
#elseif os(iOS)
@preconcurrency import MobileVLCKit
#elseif os(tvOS)
@preconcurrency import TVVLCKit
#endif

@MainActor
class VLCPlaybackCoordinator: NSObject, VLCMediaPlayerDelegate {
    var url: URL?
    var referer: URL?
    var profile: VideoPlayerProfile?
    var isMuted = false
    var seekInterval = 30

    private(set) var totalMinutes = 0
    private var lastPublishedMinute = -1
    private var didSendPlaybackEvent = false

    /// Guards against an opening/buffering stream that never resolves (dead host, black-holed connection, etc).
    private var loadWatchdog: Task<Void, Never>?
    private let loadTimeoutSeconds: UInt64 = 15

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
        cancelLoadWatchdog()
    }

    private func startLoadWatchdog() {
        guard loadWatchdog == nil else { return }
        loadWatchdog = Task { [weak self, loadTimeoutSeconds] in
            try? await Task.sleep(nanoseconds: loadTimeoutSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.handleLoadTimeout()
        }
    }

    private func cancelLoadWatchdog() {
        loadWatchdog?.cancel()
        loadWatchdog = nil
    }

    private func handleLoadTimeout() {
        loadWatchdog = nil
        guard let mediaPlayer, mediaPlayer.state == .opening || mediaPlayer.state == .buffering else { return }
        print("⏱️ VLC Player: timed out while loading, aborting")
        mediaPlayer.stopAsync()
        NotificationCenter.default.post(
            name: .playerPlaybackError,
            object: nil,
            userInfo: ["url": url as Any]
        )
    }

    /// VLCKit does not guarantee delegate callbacks arrive on the main thread (notably for `.error`,
    /// which is usually reported directly from libVLC's worker thread). Stay `nonisolated` here, pull
    /// out the plain values we need while still on the caller's thread, and hop to the main actor with
    /// just those — `Notification`/`VLCMediaPlayer` themselves aren't `Sendable` so they can't cross.
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        let state = player.state
        let totalLengthMs = player.media.map { Int($0.length.intValue) }
        Task { @MainActor [weak self] in
            self?.handleStateChanged(state: state, totalLengthMs: totalLengthMs)
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        let currentMS = Int(player.time.intValue)
        Task { @MainActor [weak self] in
            self?.handleTimeChanged(currentMS: currentMS)
        }
    }

    private func handleStateChanged(state: VLCMediaPlayerState, totalLengthMs: Int?) {
        let isHLS = (url?.pathExtension.lowercased() == "m3u8")

        switch state {
        case .opening:
            print("🌐 VLC Player: opening...")
            startLoadWatchdog()

        case .buffering:
            break

        case .esAdded:
            print("➕ VLC Player: elementary stream added")
            cancelLoadWatchdog()
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
            cancelLoadWatchdog()
            NotificationCenter.default.post(
                name: .playerPlaybackResumed,
                object: nil,
                userInfo: ["url": url as Any]
            )
            if !isHLS, !didSendPlaybackEvent {
                if totalMinutes == 0 {
                    totalMinutes = (totalLengthMs ?? 0) / 1000 / 60
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
            cancelLoadWatchdog()

        case .ended:
            print("⏏️ VLC Player: stream ended")
            cancelLoadWatchdog()

        case .error:
            print("⚠️ VLC Player: error")
            cancelLoadWatchdog()
            NotificationCenter.default.post(
                name: .playerPlaybackError,
                object: nil,
                userInfo: ["url": url as Any]
            )

        @unknown default:
            print("❓ VLC Player: unknown state [\(state.rawValue)]")
        }
    }

    private func handleTimeChanged(currentMS: Int) {
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

extension VLCMediaPlayer {
    /// Stops playback on a background queue so a stuck network/demux thread can't block the calling
    /// (typically main) thread while libVLC unwinds a slow or hung connection attempt.
    func stopAsync() {
        DispatchQueue.global(qos: .utility).async { [self] in
            self.stop()
        }
    }
}
