//
//  PlayfieldLayout.swift
//  ApolloX
//

import SpriteKit
import UIKit

/// Correctly maps the visible, safe portion of an `.aspectFill` scene onto phone screens
/// (Dynamic Island, home indicator, and side crop).
struct PlayfieldLayout {
    let fullSceneSize: CGSize
    /// Scene-space rectangle that is both on-screen and inside the safe area.
    let safeRect: CGRect
    /// Scene-space rectangle that is on-screen (may extend under notch / home indicator).
    let visibleRect: CGRect
    /// Uniform scale used by `.aspectFill`.
    let fillScale: CGFloat

    static func current(in scene: SKScene) -> PlayfieldLayout {
        let sceneSize = scene.size

        guard let view = scene.view, view.bounds.width > 0, view.bounds.height > 0 else {
            let fallback = CGRect(origin: .zero, size: sceneSize).insetBy(dx: 48, dy: 80)
            return PlayfieldLayout(
                fullSceneSize: sceneSize,
                safeRect: fallback,
                visibleRect: CGRect(origin: .zero, size: sceneSize),
                fillScale: 1
            )
        }

        // `.aspectFill` picks the larger scale so the scene covers the view; excess is cropped.
        let fillScale = max(view.bounds.width / sceneSize.width, view.bounds.height / sceneSize.height)
        let visibleSize = CGSize(
            width: view.bounds.width / fillScale,
            height: view.bounds.height / fillScale
        )
        let visibleOrigin = CGPoint(
            x: (sceneSize.width - visibleSize.width) * 0.5,
            y: (sceneSize.height - visibleSize.height) * 0.5
        )
        let visibleRect = CGRect(origin: visibleOrigin, size: visibleSize)

        let safeInsets = UIEdgeInsets(
            top: view.safeAreaInsets.top / fillScale,
            left: view.safeAreaInsets.left / fillScale,
            bottom: view.safeAreaInsets.bottom / fillScale,
            right: view.safeAreaInsets.right / fillScale
        )

        // Extra padding beyond the hardware safe area so labels never kiss the clipped edge.
        let padding = UIEdgeInsets(
            top: max(safeInsets.top, 24) + 28,
            left: max(safeInsets.left, 16) + 28,
            bottom: max(safeInsets.bottom, 20) + 24,
            right: max(safeInsets.right, 16) + 28
        )

        let safeRect = visibleRect.inset(by: padding)
        return PlayfieldLayout(
            fullSceneSize: sceneSize,
            safeRect: safeRect,
            visibleRect: visibleRect,
            fillScale: fillScale
        )
    }
}

extension SKScene {
    var playfield: PlayfieldLayout {
        PlayfieldLayout.current(in: self)
    }
}
