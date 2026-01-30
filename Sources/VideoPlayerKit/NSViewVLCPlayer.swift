//
//  NSViewVLCPlayer.swift
//

#if os(macOS)
import SwiftUI
import AppKit
import VLCKit

struct NSViewVLCPlayer: NSViewRepresentable {
    typealias NSViewType = PlayerContainerView
    
    let url: URL
    let referer: URL?
    let isLive: Bool
    let isMuted: Bool

    init(url: String, referer: String, isLive: Bool, isMuted: Bool) {
        self.url = URL(string: url) ?? URL(string: "https://invalid-url")!
        self.referer = URL(string: referer)
        self.isLive = isLive
        self.isMuted = isMuted
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PlayerContainerView {
        let containerView = PlayerContainerView()
        let player = Self.createPlayer(url: url, referer: referer)
        
        player.drawable = containerView
        player.audio?.isMuted = isMuted
        
        context.coordinator.containerView = containerView
        context.coordinator.player = player
        context.coordinator.url = url
        context.coordinator.referer = referer
        context.coordinator.isMuted = isMuted
        
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

    @MainActor
    final class Coordinator: NSObject, @preconcurrency VLCMediaPlayerDelegate {
        weak var containerView: PlayerContainerView?
        var player: VLCMediaPlayer?
        var url: URL?
        var referer: URL?
        var isMuted: Bool = false
        var totalMinutes: Int = 0
        var lastPublishedMinute: Int = -1
        var didSendPlaybackEvent = false
        var reloadObserver: NSObjectProtocol?
        var toggleObserver: NSObjectProtocol?
        
        func togglePlayPause() {
            guard let player else { return }
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
        }
        
        func performReload() {
            guard let containerView, let url else { return }
            
            self.player?.stop()

            let newPlayer = NSViewVLCPlayer.createPlayer(url: url, referer: referer)
            newPlayer.drawable = containerView
            newPlayer.audio?.isMuted = isMuted

            self.didSendPlaybackEvent = false
            self.player = newPlayer

            newPlayer.delegate = self
            newPlayer.play()
        }
        
        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard let player = aNotification.object as? VLCMediaPlayer else { return }
            let isHLS = (url?.pathExtension.lowercased() == "m3u8")

            switch player.state {
            case .esAdded:
                if isHLS, !didSendPlaybackEvent {
                    didSendPlaybackEvent = true
                    NotificationCenter.default.post(name: .playerPlaybackStarted, object: nil, userInfo: ["url": url as Any])
                }
            case .playing:
                if !isHLS, !didSendPlaybackEvent {
                    if totalMinutes == 0 {
                        totalMinutes = Int(player.media?.length.intValue ?? 0) / 1000 / 60
                    }
                    didSendPlaybackEvent = true
                    NotificationCenter.default.post(name: .playerPlaybackStarted, object: nil, userInfo: ["url": url as Any])
                }
            case .error:
                NotificationCenter.default.post(name: .playerPlaybackError, object: nil, userInfo: ["url": url as Any])
            default:
                break
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
                    name: Notification.Name.playerPlaybackTimeChanged,
                    object: nil,
                    userInfo: [
                        "total": totalMinutes,
                        "current": currentMinute
                    ]
                )
            }
        }
    }

    static func createPlayer(url: URL, referer: URL?) -> VLCMediaPlayer {
        NotificationCenter.default.post(name: .playerInitializing, object: nil, userInfo: ["url": url as Any])
        
        let player = VLCMediaPlayer()
        let media = VLCMedia(url: url)
        if let referer = referer, !referer.absoluteString.isEmpty {
            media.addOption(":http-referrer=\(referer.absoluteString)")
        }
        
        media.addOptions([
            "network-caching": 3000,
            "live-caching": 3000,
            "clock-jitter": 5000,
            "clock-synchro": 0,
            "skip-frames": 0,
            "drop-late-frames": 0,
            "avcodec-hurry-up": 0,
            "avcodec-skip-frame": 0,
            "avcodec-skip-idct": 0,
        ])

        player.media = media
        return player
    }
}
#endif
