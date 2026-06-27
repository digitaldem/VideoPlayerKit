//
//  UIViewVLCPlayer.swift
//

import SwiftUI
import AVKit
import AVFoundation
#if os(iOS)
import MobileVLCKit
#elseif os(tvOS)
import TVVLCKit
#endif

#if os(iOS) || os(tvOS)
struct UIViewVLCPlayer: UIViewControllerRepresentable {
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

    func makeUIViewController(context: Context) -> VLCPlayerViewController {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        #endif

        let controller = VLCPlayerViewController()
        controller.seekInterval = seekInterval
        let player = profile.vlc.createPlayer(url: url, referer: referer)

        let isLiveStream = self.isLive
        controller.onSeek = { [weak coordinator = context.coordinator] interval in
            if !isLiveStream {
                Task { @MainActor in
                    coordinator?.performSeek(interval: interval)
                }
            }
        }

        controller.mediaPlayer = player
        player.drawable = controller.view
        player.audio?.isMuted = isMuted

        context.coordinator.controller = controller
        context.coordinator.profile = profile
        context.coordinator.url = url
        context.coordinator.referer = referer
        context.coordinator.isMuted = isMuted
        context.coordinator.seekInterval = seekInterval

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
            context.coordinator.seekObserver = NotificationCenter.default.addObserver(
                forName: .playerSeek,
                object: nil,
                queue: .main
            ) { [weak coordinator = context.coordinator] notification in
                let explicitInterval = notification.userInfo?["interval"] as? Int
                Task { @MainActor in
                    coordinator?.performSeek(interval: explicitInterval ?? coordinator?.seekInterval ?? 30)
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
        if let seek = coordinator.seekObserver {
            NotificationCenter.default.removeObserver(seek)
            coordinator.seekObserver = nil
        }

        uiViewController.mediaPlayer?.stop()
        uiViewController.mediaPlayer = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class VLCPlayerViewController: UIViewController {
        var onPlayPause: (() -> Void)?
        var onSeek: ((Int) -> Void)?
        var mediaPlayer: VLCMediaPlayer?
        var seekInterval = 30

        #if os(tvOS)
        private var pausedForBackground = false
        #endif

        override func viewDidLoad() {
            super.viewDidLoad()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        }

        @objc private func applicationDidEnterBackground() {
            #if os(iOS)
            // Detach the drawable but keep the player running so audio continues in the background.
            mediaPlayer?.drawable = nil
            #elseif os(tvOS)
            // tvOS apps are expected to stop playback when backgrounded, unlike iOS.
            if mediaPlayer?.isPlaying == true {
                pausedForBackground = true
                mediaPlayer?.pause()
            }
            #endif
        }

        @objc private func applicationWillEnterForeground() {
            #if os(iOS)
            mediaPlayer?.drawable = self.view
            #elseif os(tvOS)
            if pausedForBackground {
                pausedForBackground = false
                mediaPlayer?.play()
            }
            #endif
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            mediaPlayer?.stop()
            mediaPlayer = nil
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var handled = false
            for press in presses {
                #if os(tvOS)
                if press.type == .leftArrow {
                    onSeek?(-seekInterval)
                    handled = true
                } else if press.type == .rightArrow {
                    onSeek?(seekInterval)
                    handled = true
                }
                #endif
            }
            if !handled {
                super.pressesBegan(presses, with: event)
            }
        }
    }

    final class Coordinator: VLCPlaybackCoordinator {
        weak var controller: VLCPlayerViewController?

        override var mediaPlayer: VLCMediaPlayer? { controller?.mediaPlayer }

        func performReload() {
            guard let controller, let profile, let url else { return }

            controller.mediaPlayer?.stop()
            NotificationCenter.default.post(
                name: .playerInitializing,
                object: nil,
                userInfo: ["url": url as Any]
            )

            let newPlayer = profile.vlc.createPlayer(url: url, referer: referer)
            controller.mediaPlayer = newPlayer

            newPlayer.drawable = controller.view
            newPlayer.audio?.isMuted = isMuted

            resetPlaybackTracking()

            newPlayer.delegate = self
            newPlayer.play()
        }
    }
}
#endif
