import XCTest
@testable import VideoPlayerKit

@MainActor
final class PlayerBannerControllerTests: XCTestCase {

    private let content = PlayerBannerContent(title: "Law & Order", subtitle: "S05E12", details: ["server7:1234"])

    func testShowPresentsTheContent() {
        let banner = PlayerBannerController(duration: .seconds(5))
        banner.show(content)
        XCTAssertEqual(banner.content, content)
        XCTAssertTrue(banner.isVisible)
    }

    func testHidesOnItsOwn() async throws {
        let banner = PlayerBannerController(duration: .milliseconds(150))
        banner.show(content)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertNil(banner.content)
    }

    /// Stepping through feeds shows the banner again and again; each show has to buy a full
    /// duration, or the banner would vanish mid-step while the viewer is still reading it.
    func testShowingAgainRestartsTheClock() async throws {
        let banner = PlayerBannerController(duration: .milliseconds(300))
        banner.show(content)
        try await Task.sleep(for: .milliseconds(200))
        let next = PlayerBannerContent(title: "Law & Order", subtitle: "S05E13")
        banner.show(next)
        try await Task.sleep(for: .milliseconds(200))
        // 400ms after the first show, past its expiry, but only 200ms into the second.
        XCTAssertEqual(banner.content, next)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(banner.content)
    }

    func testHideCancelsThePendingTimer() async throws {
        let banner = PlayerBannerController(duration: .milliseconds(200))
        banner.show(content)
        banner.hide()
        XCTAssertNil(banner.content)
        // A stale timer firing later must not matter, and a fresh show must get its own full time.
        banner.show(content)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(banner.content, content)
    }
}
