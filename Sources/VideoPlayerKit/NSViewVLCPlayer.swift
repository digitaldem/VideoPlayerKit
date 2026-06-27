//
//  NSViewVLCPlayer.swift
//

#if os(macOS)
import SwiftUI
import AppKit
import VLCKit

struct NSViewVLCPlayer: NSViewRepresentable {
    typealias NSViewType = PlayerContainerView

    let profile: VideoPlayerProfile
    let url: URL
    let referer: URL?
    let isLive: Bool
    let isMuted: Bool
    let seekInterval: Int

    init(profile: VideoPlayerProfile, url: String, referer: String, isLive: Bool, isMuted: Bool, seekInterval: Int) {
        self.profile = profile
        self.url = URL(string: url) ?? URL(string: "https://invalid-url")!
        self.referer = URL(string: referer)
        self.isLive = isLive
        self.isMuted = isMuted
        self.seekInterval = seekInterval
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PlayerContainerView {
        let containerView = PlayerContainerView()
        let player = profile.vlc.createPlayer(url: url, referer: referer)

        player.drawable = containerView
        player.audio?.isMuted = isMuted

        context.coordinator.containerView = containerView
        context.coordinator.player = player
        context.coordinator.profile = profile
        context.coordinator.url = url
        context.coordinator.referer = referer
        context.coordinator.isMuted = isMuted
        context.coordinator.seekInterval = seekInterval

        if (isLive) {
            context.coordinator.reloadObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name.playerTriggerReload,
                object: nil,
                queue: .main
            ) { [weak coordinator = context.coordinator] _ in
                MainActor.assumeIsolated {
                    coordinator?.performReload()
                }
            }

        } else {
            context.coordinator.toggleObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name.playerTogglePlayPause,
                object: nil,
                queue: .main
            ) { [weak coordinator = context.coordinator] _ in
                MainActor.assumeIsolated {
                    coordinator?.togglePlayPause()
                }
            }
            context.coordinator.seekObserver = NotificationCenter.default.addObserver(
                forName: .playerSeek,
                object: nil,
                queue: .main
            ) { [weak coordinator = context.coordinator] notification in
                let explicitInterval = notification.userInfo?["interval"] as? Int
                MainActor.assumeIsolated {
                    coordinator?.performSeek(interval: explicitInterval ?? coordinator?.seekInterval ?? 30)
                }
            }
        }

        player.delegate = context.coordinator
        player.play()

        return containerView
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        context.coordinator.player?.audio?.isMuted = isMuted
    }

    static func dismantleNSView(_ nsView: PlayerContainerView, coordinator: Coordinator) {
        if let toggle = coordinator.toggleObserver {
            NotificationCenter.default.removeObserver(toggle)
            coordinator.toggleObserver = nil
        }
        if let reload = coordinator.reloadObserver {
            NotificationCenter.default.removeObserver(reload)
            coordinator.reloadObserver = nil
        }
        if let seek = coordinator.seekObserver {
            NotificationCenter.default.removeObserver(seek)
            coordinator.seekObserver = nil
        }

        coordinator.player?.stop()
        coordinator.player = nil
    }

    class PlayerContainerView: NSView {
        var onDisappear: (() -> Void)?

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil {
                onDisappear?()
            }
        }
    }

    final class Coordinator: VLCPlaybackCoordinator {
        weak var containerView: PlayerContainerView?
        var player: VLCMediaPlayer?

        override var mediaPlayer: VLCMediaPlayer? { player }

        func performReload() {
            guard let containerView, let profile, let url else { return }

            player?.stop()
            NotificationCenter.default.post(
                name: .playerInitializing,
                object: nil,
                userInfo: ["url": url as Any]
            )

            let newPlayer = profile.vlc.createPlayer(url: url, referer: referer)
            newPlayer.drawable = containerView
            newPlayer.audio?.isMuted = isMuted

            resetPlaybackTracking()
            player = newPlayer

            newPlayer.delegate = self
            newPlayer.play()
        }
    }
}
#endif
