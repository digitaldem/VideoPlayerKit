//
//  AudioSessionHold.swift
//

#if os(iOS) || os(tvOS)
import AVFoundation

/// Keeps the audio session up across a pause, by rendering silence while playback is paused.
///
/// VLC 3's iOS/tvOS audio output stops its audio unit and deactivates the session on every pause,
/// then reactivates it on resume. Over HDMI the audio output then has to come back up, and VLC does
/// not hold the picture for it: in corsair on 25 Nov 2026 audio returned about five seconds after
/// the video on every resume, on an Apple TV straight into a TV's speakers. A session with audio
/// still running in it cannot be deactivated -- the call fails as busy, and VLC carries on -- so
/// holding silence from just before the pause until playback resumes means the route never goes
/// down and there is nothing to bring back.
///
/// Held only while paused, so it costs nothing during playback and never competes with VLC's own
/// output format.
@MainActor
final class AudioSessionHold {
    static let shared = AudioSessionHold()

    private let engine = AVAudioEngine()
    private var holding = false

    private init() {
        let silence = AVAudioSourceNode { isSilence, _, _, buffers in
            for buffer in UnsafeMutableAudioBufferListPointer(buffers) {
                if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
            }
            isSilence.pointee = true
            return noErr
        }
        engine.attach(silence)
        engine.connect(silence, to: engine.mainMixerNode, format: nil)
    }

    /// Starts rendering silence. Called immediately before VLC is asked to pause, so the session is
    /// already busy when VLC tries to deactivate it.
    func hold() {
        guard !holding else { return }
        do {
            try engine.start()
            holding = true
        } catch {
            print("🔇 AudioSessionHold: could not start: \(error)")
        }
    }

    /// Stops it. The session stays active -- stopping an engine does not deactivate anything -- and
    /// is VLC's again.
    func release() {
        guard holding else { return }
        engine.stop()
        holding = false
    }
}
#endif
