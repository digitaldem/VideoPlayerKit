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

/// Caching trades buffer depth against how long the picture takes to appear, but on these providers
/// the trade is hard to measure: repeat runs against one 1080p59 HLS channel put time to first
/// video output anywhere between 4 and 10 seconds at a fixed setting, so server response dominates
/// whatever this is set to. 7000 is a judgement call — deeper than the old 1500/3000, and short
/// enough that it is not the thing making startup slow.
public enum VideoPlayerProfile {
    case precise
    case adaptive

    internal var vlc: VLCPlayerProfile {
        switch self {
        case .precise:
            return VLCPlayerProfile(networkCaching: 7000, liveCaching: 7000,
                                    clockJitter: 5000, clockSynchro: 0,
                                    skipFrames: false, dropLateFrames: false, hurryUp: false)
        case .adaptive:
            return VLCPlayerProfile(networkCaching: 7000, liveCaching: 7000,
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
            "skip-frames": skipFrames,
            "drop-late-frames": dropLateFrames,
            "avcodec-hurry-up": hurryUp,
            "avcodec-skip-frame": 0,
            "avcodec-skip-idct": 0,
            "avcodec-hw": "any",
            "http-reconnect": true,
            // NOT http-continuous: with it enabled VLC re-requests the HLS playlist in a loop and
            // never fetches a segment at all. Measured against this provider — 0 segments in 25s
            // with it on, 13-14 with it off, at any caching value.
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
