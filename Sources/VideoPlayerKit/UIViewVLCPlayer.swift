//
//  UIViewVLCPlayer.swift
//

import SwiftUI
import AVKit
#if os(iOS)
import MobileVLCKit
#elseif os(tvOS)
import TVVLCKit
#endif

#if os(iOS) || os(tvOS)
struct UIViewVLCPlayer: UIViewControllerRepresentable {
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

    func makeUIViewController(context: Context) -> VLCPlayerViewController {
        let controller = VLCPlayerViewController()
        let player = Self.createPlayer(url: url, referer: referer)
    
        controller.mediaPlayer = player
        player.drawable = controller.view
        player.audio?.isMuted = isMuted

        context.coordinator.controller = controller
        context.coordinator.url = url
        context.coordinator.referer = referer
        context.coordinator.isMuted = isMuted

        player.delegate = context.coordinator
        player.play()

        if isLive {
            context.coordinator.reloadObserver = NotificationCenter.default.addObserver(
                forName: .playerTriggerReload,
                object: nil,
                queue: .main
            ) { [weak coordinator = context.coordinator] _ in
                Task { @MainActor in
                    coordinator?.performReload()
                }
            }
        } else {
            context.coordinator.toggleObserver = NotificationCenter.default.addObserver(
                forName: .playerTogglePlayPause,
                object: nil,
                queue: .main
            ) { [weak coordinator = context.coordinator] _ in
                Task { @MainActor in
                    coordinator?.togglePlayPause()
                }
            }
        }

        return controller
    }

    func updateUIViewController(_ vc: VLCPlayerViewController, context: Context) {
        context.coordinator.controller = vc
        vc.mediaPlayer?.audio?.isMuted = isMuted
    }
    
    static func dismantleUIViewController(_ uiViewController: VLCPlayerViewController, coordinator: Coordinator) {
        if let toggle = coordinator.toggleObserver {
            NotificationCenter.default.removeObserver(toggle)
            coordinator.toggleObserver = nil
        }
        if let reload = coordinator.reloadObserver {
            NotificationCenter.default.removeObserver(reload)
            coordinator.reloadObserver = nil
        }
        
        uiViewController.mediaPlayer?.stop()
        uiViewController.mediaPlayer = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class VLCPlayerViewController: UIViewController {
        var onPlayPause: (() -> Void)?
        var mediaPlayer: VLCMediaPlayer?

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            mediaPlayer?.stop()
            mediaPlayer = nil
        }
    }

    @MainActor
    class Coordinator: NSObject, @preconcurrency VLCMediaPlayerDelegate {
        weak var controller: VLCPlayerViewController?
        var url: URL?
        var referer: URL?
        var isMuted: Bool = false
        var totalMinutes: Int = 0
        var lastPublishedMinute: Int = -1
        var didSendPlaybackEvent: Bool = false
        
        var reloadObserver: NSObjectProtocol?
        var toggleObserver: NSObjectProtocol?
        
        func togglePlayPause() {
            guard let player = controller?.mediaPlayer else { return }
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
        }
        
        func performReload() {
            guard let controller, let url else { return }
            
            controller.mediaPlayer?.stop()

            let newPlayer = UIViewVLCPlayer.createPlayer(url: url, referer: referer)
            controller.mediaPlayer = newPlayer
            
            newPlayer.drawable = controller.view
            newPlayer.audio?.isMuted = isMuted
        
            self.didSendPlaybackEvent = false
        
            newPlayer.delegate = self
            newPlayer.play()
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard let player = aNotification.object as? VLCMediaPlayer else { return }
            let isHLS = (url?.pathExtension.lowercased() == "m3u8")
            
            switch player.state {
            case .opening:
                print("🌐 VLC Player: opening...")
                break
        
            case .buffering:
                //print("⏳ VLC Player: buffering...")
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
                break

            case .playing:
                print("▶️ VLC Player: stream playing")
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
                break
        
            case .paused:
                print("⏸️ VLC Player: stream paused")
                break
        
            case .stopped:
                print("⏹️ VLC Player: stream stopped")
                break
        
            case .ended:
                print("⏏️ VLC Player: stream ended")
                break
        
            case .error:
                print("⚠️ VLC Player: error")
                NotificationCenter.default.post(
                    name: .playerPlaybackError,
                    object: nil,
                    userInfo: ["url": url as Any]
                )
                break
        
            @unknown default:
                print("❓ VLC Player: unknown state [\(player.state.rawValue)]")
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
