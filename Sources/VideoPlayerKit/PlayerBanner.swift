//
//  PlayerBanner.swift
//  VideoPlayerKit
//

import SwiftUI

/// What the banner says: a headline, an optional line under it, and any number of detail lines.
public struct PlayerBannerContent: Equatable, Sendable {
    public var title: String
    public var subtitle: String?
    public var details: [String]

    public init(title: String, subtitle: String? = nil, details: [String] = []) {
        self.title = title
        self.subtitle = subtitle
        self.details = details
    }
}

/// How the banner looks. The app supplies it from its own theme: the kit draws the banner but owns
/// none of its colour or type, so each app keeps its visual system in one place.
public struct PlayerBannerStyle {
    public let background: Color
    public let titleFont: Font
    public let titleColor: Color
    public let subtitleFont: Font
    public let subtitleColor: Color
    public let detailFont: Font
    public let detailColor: Color

    public init(background: Color,
                titleFont: Font, titleColor: Color,
                subtitleFont: Font, subtitleColor: Color,
                detailFont: Font, detailColor: Color) {
        self.background = background
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.detailFont = detailFont
        self.detailColor = detailColor
    }
}

/// Shows the banner and puts it away again.
///
/// The banner is a glance, not a panel: there is no control to dismiss it with -- tvOS has nothing
/// to hang one off -- so it has to time out on its own. Showing it again while it is up replaces
/// the text and restarts the clock, so stepping through feeds keeps it on screen for as long as the
/// stepping goes on and reads each new feed as it arrives.
@MainActor
public final class PlayerBannerController: ObservableObject {
    @Published public private(set) var content: PlayerBannerContent?

    private let duration: Duration
    private var hideTask: Task<Void, Never>?

    public init(duration: Duration = .seconds(5)) {
        self.duration = duration
    }

    public var isVisible: Bool { content != nil }

    public func show(_ content: PlayerBannerContent) {
        withAnimation(.easeOut(duration: 0.25)) { self.content = content }
        hideTask?.cancel()
        hideTask = Task { [weak self, duration] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    public func hide() {
        hideTask?.cancel()
        hideTask = nil
        withAnimation(.easeIn(duration: 0.25)) { content = nil }
    }
}

private struct PlayerBannerOverlay: View {
    @ObservedObject var controller: PlayerBannerController
    let style: PlayerBannerStyle

    // Structural only; every colour and font arrives in `style`.
    #if os(tvOS)
    private let topInset: CGFloat = 50
    private let sideInset: CGFloat = 80
    private let maxWidth: CGFloat = 1200
    private let padding = EdgeInsets(top: 22, leading: 34, bottom: 22, trailing: 34)
    private let cornerRadius: CGFloat = 20
    #else
    private let topInset: CGFloat = 16
    private let sideInset: CGFloat = 16
    private let maxWidth: CGFloat = 720
    private let padding = EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
    private let cornerRadius: CGFloat = 14
    #endif

    var body: some View {
        VStack(spacing: 0) {
            if let content = controller.content {
                VStack(alignment: .leading, spacing: 6) {
                    Text(content.title)
                        .font(style.titleFont)
                        .foregroundStyle(style.titleColor)
                        .lineLimit(1)
                    if let subtitle = content.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(style.subtitleFont)
                            .foregroundStyle(style.subtitleColor)
                            .lineLimit(2)
                    }
                    ForEach(Array(content.details.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(style.detailFont)
                            .foregroundStyle(style.detailColor)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                .padding(padding)
                .frame(maxWidth: maxWidth, alignment: .leading)
                .background(style.background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .padding(.top, topInset)
                .padding(.horizontal, sideInset)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        // Never in the way: the remote and the pointer keep talking to the player underneath.
        .allowsHitTesting(false)
    }
}

public extension View {
    /// Overlays the controller's banner along the top edge of this view.
    func playerBanner(_ controller: PlayerBannerController, style: PlayerBannerStyle) -> some View {
        overlay(alignment: .top) {
            PlayerBannerOverlay(controller: controller, style: style)
        }
    }
}
