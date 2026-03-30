//
//  VideoPlayerProfile.swift
//

#if os(macOS)
import VLCKit
#elseif os(iOS)
import MobileVLCKit
#elseif os(tvOS)
import TVVLCKit
#endif

public enum VideoPlayerProfile {
    case precise
    case adaptive

    internal var vlc: VLCPlayerProfile {
        switch self {
        case .precise:
            return VLCPlayerProfile(networkCaching: 3000, liveCaching: 3000,
                                    clockJitter: 5000, clockSynchro: 0,
                                    skipFrames: false, dropLateFrames: false, hurryUp: false)
        case .adaptive:
            return VLCPlayerProfile(networkCaching: 1500, liveCaching: 1500,
                                    clockJitter: 500, clockSynchro: 0,
                                    skipFrames: true, dropLateFrames: true, hurryUp: true)
        }
    }
}

internal struct VLCPlayerProfile {
    let networkCaching: Int
    let liveCaching: Int
    let clockJitter: Int
    let clockSynchro: Int
    let skipFrames: Bool
    let dropLateFrames: Bool
    let hurryUp: Bool

    var options: [String: Any] {
        [
            "network-caching": networkCaching,
            "live-caching": liveCaching,
            "clock-jitter": clockJitter,
            "clock-synchro": clockSynchro,
            "skip-frames": skipFrames ? 1 : 0,
            "drop-late-frames": dropLateFrames ? 1 : 0,
            "avcodec-hurry-up": hurryUp ? 1 : 0,
            "avcodec-skip-frame": 0,
            "avcodec-skip-idct": 0,
            "avcodec-hw": "any",
            "http-reconnect": true,
        ]
    }

    func createPlayer(url: URL, referer: URL?) -> VLCMediaPlayer {
        let player = VLCMediaPlayer()
        let media = VLCMedia(url: url)

        if let referer, !referer.absoluteString.isEmpty {
            media.addOption(":http-referrer=\(referer.absoluteString)")
        }

        media.addOptions(options)
        player.media = media
        return player
    }
}
