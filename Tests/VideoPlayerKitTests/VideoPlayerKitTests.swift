import XCTest
import SwiftUI
@testable import VideoPlayerKit

final class VideoPlayerKitTests: XCTestCase {
    
    func testNotificationNamesAreUnique() {
        let notifications: [Notification.Name] = [
            .playerInitializing,
            .playerPlaybackError,
            .playerPlaybackPaused,
            .playerPlaybackResumed,
            .playerPlaybackStarted,
            .playerPlaybackStopped,
            .playerPlaybackTimeChanged,
            .playerSeek,
            .playerTogglePlayPause,
            .playerTriggerReload
        ]

        let uniqueNotifications = Set(notifications.map { $0.rawValue })
        XCTAssertEqual(notifications.count, uniqueNotifications.count, "Notification names should be unique")
    }

    func testNotificationNamesHaveCorrectPrefix() {
        let notifications: [Notification.Name] = [
            .playerInitializing,
            .playerPlaybackError,
            .playerPlaybackPaused,
            .playerPlaybackResumed,
            .playerPlaybackStarted,
            .playerPlaybackStopped,
            .playerPlaybackTimeChanged,
            .playerSeek,
            .playerTogglePlayPause,
            .playerTriggerReload
        ]

        for notification in notifications {
            XCTAssertTrue(
                notification.rawValue.hasPrefix("com.digitaldementia.VideoPlayerKit."),
                "Notification '\(notification.rawValue)' should have correct prefix"
            )
        }
    }
    
    @MainActor
    func testVideoPlayerViewCanBeCreated() {
        let view = VideoPlayer(
            url: "https://example.com/stream.m3u8",
            referer: "https://example.com",
            isLive: true,
            isMuted: false
        )
        
        XCTAssertNotNil(view, "VideoPlayerView should be created")
    }
    
    @MainActor
    func testVideoPlayerViewWithDifferentParameters() {
        let testCases: [(url: String, referer: String, isLive: Bool, isMuted: Bool, reloadTrigger: Bool)] = [
            ("https://test.com/video.mp4", "", false, false, false),
            ("https://test.com/live.m3u8", "https://test.com", true, true, false),
            ("https://test.com/stream", "https://referer.com", true, false, true),
            ("https://test.com/vod.mp4", "", false, true, false),
            ("https://test.com/live", "https://test.com", true, false, false),
        ]
        
        for testCase in testCases {
            let view = VideoPlayer(
                url: testCase.url,
                referer: testCase.referer,
                isLive: testCase.isLive,
                isMuted: testCase.isMuted
            )
            XCTAssertNotNil(view, "VideoPlayerView should be created with parameters: \(testCase)")
        }
    }
    
    @MainActor
    func testVideoPlayerViewWithInvalidURL() {
        let view = VideoPlayer(
            url: "",
            referer: "",
            isLive: false,
            isMuted: false
        )
        
        XCTAssertNotNil(view, "VideoPlayerView should handle invalid URLs gracefully")
    }
    
    func testPlayerPlaybackStartedNotification() {
        let expectation = expectation(description: "Playback started notification received")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .playerPlaybackStarted,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["url"])
            expectation.fulfill()
        }
        
        NotificationCenter.default.post(
            name: .playerPlaybackStarted,
            object: nil,
            userInfo: ["url": URL(string: "https://example.com/stream.m3u8")!]
        )
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testPlayerPlaybackTimeChangedNotification() {
        let expectation = expectation(description: "Time changed notification received")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .playerPlaybackTimeChanged,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["total"])
            XCTAssertNotNil(notification.userInfo?["current"])
            
            let total = notification.userInfo?["total"] as? Int
            let current = notification.userInfo?["current"] as? Int
            
            XCTAssertEqual(total, 120)
            XCTAssertEqual(current, 45)
            
            expectation.fulfill()
        }
        
        NotificationCenter.default.post(
            name: .playerPlaybackTimeChanged,
            object: nil,
            userInfo: [
                "total": 120,
                "current": 45
            ]
        )
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testPlayerTogglePlayPauseNotification() {
        let expectation = expectation(description: "Toggle play/pause notification received")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .playerTogglePlayPause,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        NotificationCenter.default.post(name: .playerTogglePlayPause, object: nil)
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testPlayerErrorNotification() {
        let expectation = expectation(description: "Error notification received")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .playerPlaybackError,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["url"])
            expectation.fulfill()
        }
        
        NotificationCenter.default.post(
            name: .playerPlaybackError,
            object: nil,
            userInfo: ["url": URL(string: "https://example.com/stream.m3u8")!]
        )
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testPlayerSeekNotification() {
        let expectation = expectation(description: "Seek notification received")

        let observer = NotificationCenter.default.addObserver(
            forName: .playerSeek,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["interval"] as? Int, -15)
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: .playerSeek,
            object: nil,
            userInfo: ["interval": -15]
        )

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testPlayerPlaybackResumedNotification() {
        let expectation = expectation(description: "Playback resumed notification received")

        let observer = NotificationCenter.default.addObserver(
            forName: .playerPlaybackResumed,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["url"])
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: .playerPlaybackResumed,
            object: nil,
            userInfo: ["url": URL(string: "https://example.com/stream.m3u8")!]
        )

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testCorrectPlatformIsUsed() {
        #if os(macOS)
        XCTAssertTrue(true, "Running on macOS")
        #elseif os(iOS)
        XCTAssertTrue(true, "Running on iOS")
        #elseif os(tvOS)
        XCTAssertTrue(true, "Running on tvOS")
        #else
        XCTFail("Unsupported platform")
        #endif
    }

    func testPreciseProfileOptions() {
        let options = VideoPlayerProfile.precise.vlc.options
        XCTAssertEqual(options["network-caching"] as? Int, 3000)
        XCTAssertEqual(options["live-caching"] as? Int, 3000)
        XCTAssertEqual(options["clock-jitter"] as? Int, 5000)
        XCTAssertEqual(options["clock-synchro"] as? Int, 0)
        XCTAssertEqual(options["skip-frames"] as? Bool, false)
        XCTAssertEqual(options["drop-late-frames"] as? Bool, false)
        XCTAssertEqual(options["avcodec-hurry-up"] as? Bool, false)
        XCTAssertEqual(options["avcodec-skip-frame"] as? Int, 0)
        XCTAssertEqual(options["avcodec-skip-idct"] as? Int, 0)
        XCTAssertEqual(options["avcodec-hw"] as? String, "any")
        XCTAssertEqual(options["http-reconnect"] as? Bool, true)
    }

    func testAdaptiveProfileOptions() {
        let options = VideoPlayerProfile.adaptive.vlc.options
        XCTAssertEqual(options["network-caching"] as? Int, 1500)
        XCTAssertEqual(options["live-caching"] as? Int, 1500)
        XCTAssertEqual(options["clock-jitter"] as? Int, 500)
        XCTAssertEqual(options["clock-synchro"] as? Int, 0)
        XCTAssertEqual(options["skip-frames"] as? Bool, true)
        XCTAssertEqual(options["drop-late-frames"] as? Bool, true)
        XCTAssertEqual(options["avcodec-hurry-up"] as? Bool, true)
        XCTAssertEqual(options["http-reconnect"] as? Bool, true)
    }

    @MainActor
    func testCoordinatorTogglePlayPauseNoOpsWithoutPlayer() {
        let coordinator = VLCPlaybackCoordinator()
        coordinator.togglePlayPause()
    }

    @MainActor
    func testCoordinatorPerformSeekNoOpsWithoutPlayer() {
        let coordinator = VLCPlaybackCoordinator()
        coordinator.performSeek(interval: 30)
        coordinator.performSeek(interval: -30)
        coordinator.performSeek(interval: 0)
    }

    @MainActor
    func testCoordinatorIgnoresNotificationsFromUnrelatedObjects() {
        let coordinator = VLCPlaybackCoordinator()
        let bogusNotification = Notification(name: Notification.Name("com.digitaldementia.test.bogus"), object: "not a player")
        coordinator.mediaPlayerStateChanged(bogusNotification)
        coordinator.mediaPlayerTimeChanged(bogusNotification)
    }

    #if os(macOS)
    @MainActor
    func testPlatformViewFallsBackToPlaceholderURLForEmptyString() {
        let view = NSViewVLCPlayer(profile: .precise, url: "", referer: "", isLive: false, isMuted: false, seekInterval: 30)
        XCTAssertEqual(view.url.absoluteString, "https://invalid-url")
        XCTAssertNil(view.referer, "An empty referer string should not produce a URL")
    }

    @MainActor
    func testPlatformViewStoresConfiguredValues() {
        let view = NSViewVLCPlayer(profile: .adaptive, url: "https://example.com/video.mp4", referer: "https://example.com", isLive: true, isMuted: true, seekInterval: 45)
        XCTAssertEqual(view.url.absoluteString, "https://example.com/video.mp4")
        XCTAssertEqual(view.referer?.absoluteString, "https://example.com")
        XCTAssertEqual(view.seekInterval, 45)
        XCTAssertTrue(view.isLive)
        XCTAssertTrue(view.isMuted)
    }

    @MainActor
    func testVideoPlayerAppliesDefaultProfileAndSeekInterval() {
        let view = VideoPlayer(url: "https://example.com/video.mp4", referer: "", isLive: false, isMuted: false)
        guard let representable = view as? NSViewVLCPlayer else {
            return XCTFail("Expected VideoPlayer to resolve to NSViewVLCPlayer on macOS")
        }
        XCTAssertEqual(representable.seekInterval, 30)
        guard case .precise = representable.profile else {
            return XCTFail("Expected default profile to be .precise")
        }
    }
    #elseif os(iOS) || os(tvOS)
    @MainActor
    func testPlatformViewFallsBackToPlaceholderURLForEmptyString() {
        let view = UIViewVLCPlayer(profile: .precise, url: "", referer: "", isLive: false, isMuted: false, seekInterval: 30)
        XCTAssertEqual(view.url.absoluteString, "https://invalid-url")
        XCTAssertNil(view.referer, "An empty referer string should not produce a URL")
    }

    @MainActor
    func testPlatformViewStoresConfiguredValues() {
        let view = UIViewVLCPlayer(profile: .adaptive, url: "https://example.com/video.mp4", referer: "https://example.com", isLive: true, isMuted: true, seekInterval: 45)
        XCTAssertEqual(view.url.absoluteString, "https://example.com/video.mp4")
        XCTAssertEqual(view.referer?.absoluteString, "https://example.com")
        XCTAssertEqual(view.seekInterval, 45)
        XCTAssertTrue(view.isLive)
        XCTAssertTrue(view.isMuted)
    }

    @MainActor
    func testVideoPlayerAppliesDefaultProfileAndSeekInterval() {
        let view = VideoPlayer(url: "https://example.com/video.mp4", referer: "", isLive: false, isMuted: false)
        guard let representable = view as? UIViewVLCPlayer else {
            return XCTFail("Expected VideoPlayer to resolve to UIViewVLCPlayer on this platform")
        }
        XCTAssertEqual(representable.seekInterval, 30)
        guard case .precise = representable.profile else {
            return XCTFail("Expected default profile to be .precise")
        }
    }
    #endif
}
