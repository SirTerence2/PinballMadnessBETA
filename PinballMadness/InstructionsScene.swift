//
//  InstructionsScene.swift
//  PinballMadness
//
//  Created by Muhammad Mahmood on 9/2/25.
//
import UIKit
import SpriteKit

class InstructionsScene: SKScene {
    var star: SKSpriteNode!
    
    override func didMove(to view: SKView) {
        let bg = SKSpriteNode(imageNamed: "BackgroundTutorial")
        bg.size = CGSize(width: self.size.width, height: self.size.height)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        addChild(bg)
    }
}
