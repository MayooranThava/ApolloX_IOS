//
//  NodePool.swift
//  ApolloX
//

import SpriteKit

/// Simple reuse pool to avoid constant alloc/dealloc of short-lived sprites.
final class NodePool {
    private var nodes: [SKSpriteNode] = []
    private let makeNode: () -> SKSpriteNode

    init(prewarm: Int = 0, makeNode: @escaping () -> SKSpriteNode) {
        self.makeNode = makeNode
        if prewarm > 0 {
            nodes.reserveCapacity(prewarm)
            for _ in 0..<prewarm {
                nodes.append(makeNode())
            }
        }
    }

    func checkout() -> SKSpriteNode {
        let node = nodes.popLast() ?? makeNode()
        node.removeAllActions()
        node.alpha = 1
        node.zRotation = 0
        node.setScale(1)
        node.isHidden = false
        return node
    }

    func recycle(_ node: SKSpriteNode) {
        node.removeAllActions()
        node.removeFromParent()
        node.physicsBody = nil
        nodes.append(node)
    }
}
