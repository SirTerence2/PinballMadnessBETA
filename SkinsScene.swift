//
//  SkinsScene.swift
//  PinballMadness
//
//  Created by Muhammad Mahmood on 7/29/25.
//
import SpriteKit

class SkinsScene: SKScene {
    override func didMove(to view: SKView) {
        let bg = SKSpriteNode(imageNamed: "SkinsScene")
        bg.size = self.size
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        addChild(bg)
    }
}
