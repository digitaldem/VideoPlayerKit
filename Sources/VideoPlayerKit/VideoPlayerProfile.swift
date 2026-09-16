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

/// Caching is sized against how these providers actually deliver, not against the bitrate. A
/// measured 1080p59 HLS channel hands over a 10-second segment and then goes quiet for 6-9 seconds
/// before the next one arrives, so a buffer shorter than that empties between segments and the
/// picture stalls. 9 seconds covers a full segment and the worst gap measured (9.1s), which is
/// about as much headroom as is worth buying before startup latency becomes the bigger annoyance.
public enum VideoPlayerProfile {
    case precise
    case adaptive

    internal var vlc: VLCPlayerProfile {
        switch self {
        case .precise:
            return VLCPlayerProfile(networkCaching: 9000, liveCaching: 9000,
                                    clockJitter: 5000, clockSynchro: 0,
                                    skipFrames: false, dropLateFrames: false, hurryUp: false)
        case .adaptive:
            return VLCPlayerProfile(networkCaching: 9000, liveCaching: 9000,
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
            // These providers answer with `Connection: close` and a fresh redirect token per
            // request, so every playlist refresh and every segment needs a new connection.
            "http-reconnect": true,
            "http-continuous": true,
            // Target distance behind the live edge for the adaptive/HLS demuxer. Matching the
            // caching window stops it from chasing an edge the buffer cannot sustain.
            "adaptive-livedelay": liveCaching,
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
