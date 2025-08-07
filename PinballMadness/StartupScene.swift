//
//  StartupScene.swift
//  PinballTrue
//
//  Created by Muhammad Mahmood on 7/16/25.
//
import SpriteKit

class StartupScene: SKScene {
    override func didMove(to view: SKView) {
        let bg = SKSpriteNode(imageNamed: "Startup_scene")
        bg.size = self.size
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        addChild(bg)
    }
}
