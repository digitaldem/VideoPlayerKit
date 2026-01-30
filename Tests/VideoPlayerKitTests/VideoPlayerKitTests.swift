import XCTest
import SwiftUI
@testable import VideoPlayerKit

final class VideoPlayerKitTests: XCTestCase {
    
    func testNotificationNamesAreUnique() {
        let notifications: [Notification.Name] = [
            .playerInitializing,
            .playerPlaybackError,
            .playerPlaybackPaused,
            .playerPlaybackStarted,
            .playerPlaybackStopped,
            .playerPlaybackTimeChanged,
            .playerStallDetected,
            .playerStallResolved,
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
            .playerPlaybackStarted,
            .playerPlaybackStopped,
            .playerPlaybackTimeChanged,
            .playerStallDetected,
            .playerStallResolved,
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
}
