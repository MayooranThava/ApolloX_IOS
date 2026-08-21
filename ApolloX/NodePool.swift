//
//  NodePool.swift
//  ApolloX
//

import SpriteKit

/// Sprite with gameplay fields stored on the node to avoid per-spawn `NSMutableDictionary` churn.
final class PooledSprite: SKSpriteNode {
    var lastPosition: CGPoint = .zero
    var hitRadius: CGFloat = 0
    var physicsRadius: CGFloat = 0
    var obstacleKind: GameConstants.ObstacleKind?
    var obstacleHP: Int = 1
    var powerUpKind: GameConstants.PowerUpKind?

    func resetGameplayState() {
        lastPosition = .zero
        hitRadius = 0
        obstacleKind = nil
        obstacleHP = 1
        powerUpKind = nil
        name = nil
        userData = nil
    }

    /// Reuses the existing circle body when the radius has not changed (typical for bullets).
    func attachCirclePhysics(radius: CGFloat, category: UInt32, contact: UInt32) {
        if physicsBody != nil, abs(physicsRadius - radius) < 0.5 {
            physicsBody?.categoryBitMask = category
            physicsBody?.contactTestBitMask = contact
            physicsBody?.collisionBitMask = GameConstants.PhysicsCategory.none
            physicsBody?.isDynamic = true
            physicsBody?.affectedByGravity = false
            physicsBody?.allowsRotation = false
            physicsBody?.usesPreciseCollisionDetection = false
            return
        }

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        // Swept hit tests in GameScene already catch tunneling; CCD is extra CPU at 120 Hz.
        body.usesPreciseCollisionDetection = false
        body.categoryBitMask = category
        body.collisionBitMask = GameConstants.PhysicsCategory.none
        body.contactTestBitMask = contact
        physicsBody = body
        physicsRadius = radius
    }
}

/// Simple reuse pool to avoid constant alloc/dealloc of short-lived sprites.
final class NodePool<Node: SKSpriteNode> {
    private var nodes: [Node] = []
    private let makeNode: () -> Node
    private let maxIdle: Int

    init(prewarm: Int = 0, maxIdle: Int = 32, makeNode: @escaping () -> Node) {
        self.makeNode = makeNode
        self.maxIdle = max(prewarm, maxIdle)
        if prewarm > 0 {
            nodes.reserveCapacity(prewarm)
            for _ in 0..<prewarm {
                nodes.append(makeNode())
            }
        }
    }

    var idleCount: Int { nodes.count }

    func checkout() -> Node {
        let node = nodes.popLast() ?? makeNode()
        node.removeAllActions()
        node.alpha = 1
        node.zRotation = 0
        node.setScale(1)
        node.isHidden = false
        if let pooled = node as? PooledSprite {
            pooled.resetGameplayState()
        } else {
            node.userData = nil
        }
        return node
    }

    func recycle(_ node: Node) {
        node.removeAllActions()
        node.removeFromParent()
        node.isHidden = true
        node.physicsBody?.categoryBitMask = GameConstants.PhysicsCategory.none
        node.physicsBody?.contactTestBitMask = GameConstants.PhysicsCategory.none
        if let pooled = node as? PooledSprite {
            pooled.resetGameplayState()
        } else {
            node.userData = nil
        }
        // Callers never double-recycle the same live node; skip O(n) identity scan.
        guard nodes.count < maxIdle else { return }
        nodes.append(node)
    }
}
