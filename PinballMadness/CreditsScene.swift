//
//  CreditsScene.swift
//  PinballMadness
//
//  Created by Muhammad Mahmood on 9/3/25.
//
import UIKit
import SpriteKit

class CreditsScene: SKScene {
    var star: SKSpriteNode!
    
    override func didMove(to view: SKView) {
        let bg = SKSpriteNode(imageNamed: "CreditsScene")
        bg.size = self.size
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        addChild(bg)
    }
}
