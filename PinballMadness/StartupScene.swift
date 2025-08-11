//
//  StartupScene.swift
//  PinballTrue
//
//  Created by Muhammad Mahmood on 7/16/25.
//
import UIKit
import SpriteKit

class StartupScene: SKScene {
    var star: SKSpriteNode!
    
    override func didMove(to view: SKView) {
        let bg = SKSpriteNode(imageNamed: "Startup_scene")
        bg.size = self.size
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        addChild(bg)
    }
    
    func addStar(position: CGPoint){
        star = SKSpriteNode(imageNamed: "Star")
        let body = SKPhysicsBody(circleOfRadius: star.size.width / 2)
        body.isDynamic = false
        star.physicsBody = body
        star.position = position
        addChild(star)
    }
}
