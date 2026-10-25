//
//  RemoteGestures.swift
//  VideoPlayerKit
//

#if os(tvOS)
import SwiftUI
import UIKit

/// Tells a Siri Remote arrow *click* apart from a *swipe*.
///
/// SwiftUI reports both through `onMoveCommand` as the same directional move, so anything bound
/// there fires on a thumb resting against the remote as readily as on a deliberate press. That is
/// tolerable for seeking, where a wrong guess costs a few seconds, and not for switching stream,
/// which drops the picture and opens another connection.
///
/// UIKit can separate them: a click arrives as a press type on a tap recogniser, a swipe as a swipe
/// recogniser. The hosting view never takes focus, so the focus engine is left alone.
///
///     .background(
///         RemoteGestures(
///             onArrow: { step($0 == .left ? -1 : 1) },
///             onSwipe: { $0 == .up ? showProgress() : showDetail() }
///         )
///     )
public struct RemoteGestures: UIViewRepresentable {
    public enum Arrow { case left, right }
    public enum Swipe { case up, down }

    private let onArrow: (Arrow) -> Void
    private let onSwipe: (Swipe) -> Void

    public init(onArrow: @escaping (Arrow) -> Void = { _ in },
                onSwipe: @escaping (Swipe) -> Void = { _ in }) {
        self.onArrow = onArrow
        self.onSwipe = onSwipe
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let c = context.coordinator

        let left = UITapGestureRecognizer(target: c, action: #selector(Coordinator.leftClick))
        left.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        view.addGestureRecognizer(left)

        let right = UITapGestureRecognizer(target: c, action: #selector(Coordinator.rightClick))
        right.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        view.addGestureRecognizer(right)

        let up = UISwipeGestureRecognizer(target: c, action: #selector(Coordinator.swipeUp))
        up.direction = .up
        view.addGestureRecognizer(up)

        let down = UISwipeGestureRecognizer(target: c, action: #selector(Coordinator.swipeDown))
        down.direction = .down
        view.addGestureRecognizer(down)

        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    public final class Coordinator: NSObject {
        fileprivate var parent: RemoteGestures
        fileprivate init(_ parent: RemoteGestures) { self.parent = parent }

        @objc fileprivate func leftClick()  { parent.onArrow(.left) }
        @objc fileprivate func rightClick() { parent.onArrow(.right) }
        @objc fileprivate func swipeUp()    { parent.onSwipe(.up) }
        @objc fileprivate func swipeDown()  { parent.onSwipe(.down) }
    }
}
#endif
