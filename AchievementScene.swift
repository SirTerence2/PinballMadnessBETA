//
//  AchievementScene.swift
//  PinballMadness
//
//  Created by Muhammad Mahmood on 8/2/25.
//
import SpriteKit

class AchievementScene : SKScene {
    override func didMove(to view: SKView) {
        let bg = SKSpriteNode(imageNamed: "AchievementsPage")
        bg.size = self.size
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        addChild(bg)
    }
}
