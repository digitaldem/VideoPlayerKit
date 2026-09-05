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

    /// Only live streams are auto-recovered. Reloading a VOD stream would restart it from zero,
    /// which is far worse than showing the error and letting the viewer decide.
    var isLive = false

    private(set) var totalMinutes = 0
    private var lastPublishedMinute = -1
    private var didSendPlaybackEvent = false

    /// Identity of the player we currently care about. Retired players keep emitting state changes
    /// from libVLC worker threads while their (possibly hung) `stop()` unwinds; without this guard
    /// a dying player's `.error`/`.stopped` would be attributed to the freshly created one.
    private var activePlayerID: ObjectIdentifier?

    /// Guards against a stream that never resolves or that silently stops delivering data
    /// (dead host, black-holed connection, upstream that stalls mid-programme, etc).
    private var stallWatchdog: Task<Void, Never>?
    private let stallTimeoutSeconds: UInt64 = 20

    /// Backoff state for automatic recovery of a wedged live stream. The budget is spent per outage
    /// and refilled the moment the stream delivers real data again, so a channel that flaps keeps
    /// getting retried while one that is genuinely down stops after `maxRecoveryAttempts`.
    private var recoveryTask: Task<Void, Never>?
    private var recoveryAttempts = 0
    private let maxRecoveryAttempts = 3

    var reloadObserver: NSObjectProtocol?
    var toggleObserver: NSObjectProtocol?
    var seekObserver: NSObjectProtocol?

    /// Overridden by platform subclasses to expose the player they own.
    var mediaPlayer: VLCMediaPlayer? { nil }

    /// Overridden by platform subclasses to retire the current player and start a fresh one on the
    /// same URL. Also invoked by automatic stall/error recovery, not just the user's reload button.
    func performReload() {}

    /// Overridden by platform subclasses to drop their strong reference to a player that has just
    /// been retired, so nothing can hand a dead player back to us.
    func clearPlayerReference() {}

    /// Entry point for the user's reload control. An explicit reload refills the automatic retry
    /// budget, so a viewer who comes back to a channel that gave up earlier gets the full set of
    /// attempts again rather than a single try.
    func performManualReload() {
        recoveryAttempts = 0
        performReload()
    }

    // MARK: - Player lifecycle

    /// Wires a freshly created player up to this coordinator and starts playback.
    func adopt(_ player: VLCMediaPlayer) {
        activePlayerID = ObjectIdentifier(player)
        player.delegate = self
        player.play()
    }

    /// Tears a player down without ever touching UIKit/AppKit off the main thread.
    ///
    /// Order matters, and all three steps exist because of hung network streams specifically:
    ///  1. Drop the delegate so the dying player can't report `.error`/`.stopped` into live UI.
    ///  2. Release the drawable *here on the main actor*. `drawable` is a `strong` property, so if
    ///     the player were instead deallocated on a background queue it would release the backing
    ///     `UIView`/`NSView` there too — a UIKit/AppKit dealloc off the main thread, which crashes.
    ///  3. Run the blocking `stop()` on a serial background queue, then hand the last strong
    ///     reference back to the main queue so `-[VLCMediaPlayer dealloc]` also runs on main.
    func retire(_ player: VLCMediaPlayer) {
        if activePlayerID == ObjectIdentifier(player) {
            activePlayerID = nil
            cancelStallWatchdog()
        }
        recoveryTask?.cancel()
        recoveryTask = nil
        player.delegate = nil
        player.drawable = nil
        player.retireAsync()
        clearPlayerReference()
    }

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
        cancelStallWatchdog()
    }

    // MARK: - Stall watchdog

    /// Armed whenever the stream is not delivering pictures (`.opening`, `.buffering`) and cancelled
    /// as soon as it is (`.playing`, `.esAdded`, or a time update). A brief rebuffer therefore never
    /// trips it, but an internet stream that wedges mid-playback does.
    private func startStallWatchdog() {
        guard stallWatchdog == nil else { return }
        stallWatchdog = Task { [weak self, stallTimeoutSeconds] in
            try? await Task.sleep(nanoseconds: stallTimeoutSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.handleStallTimeout()
        }
    }

    private func cancelStallWatchdog() {
        stallWatchdog?.cancel()
        stallWatchdog = nil
    }

    private func handleStallTimeout() {
        stallWatchdog = nil
        guard let mediaPlayer, activePlayerID == ObjectIdentifier(mediaPlayer) else { return }
        let state = mediaPlayer.state
        guard state == .opening || state == .buffering else { return }
        print("⏱️ VLC Player: stalled for \(stallTimeoutSeconds)s, aborting")
        recoverOrReportFailure(reason: "stalled")
    }

    // MARK: - Automatic recovery

    /// Refilled by evidence that the stream is actually alive, so a channel that drops once an hour
    /// gets a fresh budget each time rather than exhausting one over the whole viewing session.
    private func noteStreamIsHealthy() {
        recoveryAttempts = 0
    }

    /// Reloads a wedged live stream after a short backoff, or gives up and surfaces the error.
    private func recoverOrReportFailure(reason: String) {
        // Retire before anything else: it stops the wedged stream eating sockets and threads during
        // the backoff, and clearing `activePlayerID` means a dying player can't re-enter here and
        // burn the whole retry budget in one go.
        if let mediaPlayer, activePlayerID == ObjectIdentifier(mediaPlayer) {
            retire(mediaPlayer)
        }

        guard isLive, recoveryAttempts < maxRecoveryAttempts else {
            if isLive {
                print("🛑 VLC Player: \(reason), giving up after \(recoveryAttempts) reload attempts")
            }
            NotificationCenter.default.post(
                name: .playerPlaybackError,
                object: nil,
                userInfo: ["url": url as Any]
            )
            return
        }

        recoveryAttempts += 1
        // 1s, 2s, 4s — long enough to let a blipping upstream settle, short enough that a viewer
        // watching live TV sees it come back on its own.
        let delaySeconds = UInt64(1) << (recoveryAttempts - 1)
        print("🔁 VLC Player: \(reason), reloading in \(delaySeconds)s (attempt \(recoveryAttempts)/\(maxRecoveryAttempts))")

        // Show the spinner immediately rather than leaving the last frame frozen for the backoff.
        NotificationCenter.default.post(
            name: .playerInitializing,
            object: nil,
            userInfo: ["url": url as Any]
        )

        recoveryTask?.cancel()
        recoveryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.recoveryTask = nil
            self?.performReload()
        }
    }

    // MARK: - VLCMediaPlayerDelegate

    /// VLCKit does not guarantee delegate callbacks arrive on the main thread (notably for `.error`,
    /// which is usually reported directly from libVLC's worker thread). Stay `nonisolated` here, pull
    /// out the plain values we need while still on the caller's thread, and hop to the main actor with
    /// just those — `Notification`/`VLCMediaPlayer` themselves aren't `Sendable` so they can't cross.
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        let playerID = ObjectIdentifier(player)
        let state = player.state
        let totalLengthMs = player.media.map { Int($0.length.intValue) }
        Task { @MainActor [weak self] in
            guard let self, self.activePlayerID == playerID else { return }
            self.handleStateChanged(state: state, totalLengthMs: totalLengthMs)
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        let playerID = ObjectIdentifier(player)
        let currentMS = Int(player.time.intValue)
        Task { @MainActor [weak self] in
            guard let self, self.activePlayerID == playerID else { return }
            self.handleTimeChanged(currentMS: currentMS)
        }
    }

    private func handleStateChanged(state: VLCMediaPlayerState, totalLengthMs: Int?) {
        let isHLS = (url?.pathExtension.lowercased() == "m3u8")

        switch state {
        case .opening:
            print("🌐 VLC Player: opening...")
            startStallWatchdog()

        case .buffering:
            // Also covers a mid-playback rebuffer that never completes.
            startStallWatchdog()

        case .esAdded:
            print("➕ VLC Player: elementary stream added")
            cancelStallWatchdog()
            noteStreamIsHealthy()
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
            cancelStallWatchdog()
            noteStreamIsHealthy()
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
            cancelStallWatchdog()
            NotificationCenter.default.post(
                name: .playerPlaybackPaused,
                object: nil,
                userInfo: ["url": url as Any]
            )

        case .stopped:
            // No-op: stop is also triggered by our own reload/teardown paths, so it
            // doesn't reliably mean "playback ended" and isn't posted as an event.
            print("⏹️ VLC Player: stream stopped")
            cancelStallWatchdog()

        case .ended:
            print("⏏️ VLC Player: stream ended")
            cancelStallWatchdog()

        case .error:
            // A stream that hangs long enough usually lands here rather than staying in `.buffering`,
            // so this shares the stall path's retry budget instead of failing straight to the UI.
            print("⚠️ VLC Player: error")
            cancelStallWatchdog()
            recoverOrReportFailure(reason: "playback error")

        @unknown default:
            print("❓ VLC Player: unknown state [\(state.rawValue)]")
        }
    }

    private func handleTimeChanged(currentMS: Int) {
        // Real progress means the stream is alive, whatever state libVLC last reported.
        cancelStallWatchdog()
        guard currentMS > 0 else { return }
        noteStreamIsHealthy()
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

/// Serial, so that repeatedly reloading a wedged stream queues the blocking `stop()` calls onto one
/// thread. On the global concurrent queue each hung `stop()` parks a worker for the full socket
/// timeout, and libdispatch responds by spinning up more threads — on top of libVLC's own.
private let vlcTeardownQueue = DispatchQueue(
    label: "com.digitaldementia.VideoPlayerKit.teardown",
    qos: .utility
)

extension VLCMediaPlayer {
    /// Stops playback on a background queue so a stuck network/demux thread can't block the calling
    /// (typically main) thread while libVLC unwinds a slow or hung connection attempt, then releases
    /// the final reference back on the main queue so `dealloc` doesn't run off-main.
    ///
    /// Callers must clear `delegate` and `drawable` first — see `VLCPlaybackCoordinator.retire(_:)`.
    func retireAsync() {
        vlcTeardownQueue.async { [self] in
            self.stop()
            DispatchQueue.main.async {
                withExtendedLifetime(self) {}
            }
        }
    }
}
