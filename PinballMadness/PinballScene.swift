//
//  PinballScene.swift
//  PinballTrue
//
//  Created by Muhammad Mahmood on 6/30/25.
//
import SpriteKit
import Combine

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
}

class PinballScene: SKScene, ObservableObject, SKPhysicsContactDelegate{
    var ball: SKSpriteNode!
    var dupBall: SKSpriteNode!
    var ballSkin: String = "Pinball"
    
    var flipLeft: SKSpriteNode!
    var flipRight: SKSpriteNode!
    
    var fistLeft: SKSpriteNode!
    var fistRight: SKSpriteNode!
    var fistAttack: SKSpriteNode!
    
    var wall: SKSpriteNode!
    
    var bumperLeft: SKSpriteNode!
    var bumperRight: SKSpriteNode!
    var bumperCenter: SKSpriteNode!
    
    var summonedOtherItems: Bool = false
    var jumpBoostAvailable: Bool = true
    var dupBallActive: Bool = false
    
    var activatedDupPower: Bool = false
    var activatedPunPower: Bool = false
    var activatedFlipPower: Bool = false
    var activatedBossPower: Bool = false
    
    var timerLabel: SKLabelNode!
    var timerBackground: SKShapeNode!
    var timerValue: TimeInterval = 300
    var timerColor: String = "green"
    
    var timeSurvivedValue: TimeInterval = 0
    
    var pinballWorldNode = SKNode()
    var backgroundWidth : CGFloat = 0
    var backgroundHeight : CGFloat = 0
    let flipPublisher = PassthroughSubject<Void, Never>()
    let bossPublisher = PassthroughSubject<Void, Never>()
    let dupPublisher = PassthroughSubject<Bool, Never>()
    let losePublisher = PassthroughSubject<Void, Never>()
    let powerUpPublisher = PassthroughSubject<Void, Never>()
    
    var isSceneSetup: Bool = false
    
    override func didMove(to view: SKView) {
        guard !isSceneSetup else {
            self.addItemPun()
            if !dupBallActive {
                self.addItemDup()
            }
            self.addItemFlip()
            self.addBossItem()
            return
        }
        isSceneSetup = true
        
        addChild(pinballWorldNode)
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -10)
        backgroundColor = .clear
        
        addBackdrop()
        
        addCeiling()
        addSides(at: CGPoint(x: 42, y: 10))
        addSides(at: CGPoint(x: 359, y: 10))
        addTrianglesLeft(at: CGPoint(x: 0, y: -22))
        addTrianglesRight(at: CGPoint(x: 400, y: -11))
        
        addBall(position: CGPoint(x: 50, y: 500))
        
        addLeftFlipper()
        applyLeftFlipperImpulse()
        addRightFlipper()
        applyRightFlipperImpulse()
        
        addWallBottomLeft()
        addWallTopLeft()
        
        addBumperLeft()
        addBumperRight()
        addBumperCenter()
        
        addBossItem()
        addItemDup()
        addItemPun()
        addItemFlip()
        
        timerBackground = SKShapeNode(rectOf: CGSize(width: 140, height: 60), cornerRadius: 10)
        timerBackground.name = "timeBackground"
        timerBackground.fillColor = SKColor.black.withAlphaComponent(1)
        timerBackground.strokeColor = .black
        timerBackground.zPosition = 1000
        timerBackground.position = CGPoint(x: size.width / 2, y: 765)
        pinballWorldNode.addChild(timerBackground)
        
        addTimer(position: CGPoint(x: timerBackground.position.x, y: timerBackground.position.y - 13), flipped: false)
        addLoseBox()
    }
    
    struct PhysicsCategory {
        static let none: UInt32 = 0
        static let flipper: UInt32 = 0b1
        static let ball: UInt32 = 0b10
        static let triangleWall: UInt32 = 0b100
        static let bumper: UInt32 = 0b1000
        static let rectangleWall: UInt32 = 0b10000
        static let itemDupli: UInt32 = 0b100000
        static let itemPun: UInt32 = 0b1000000
        static let itemFlip: UInt32 = 0b10000000
        static let fistLauncher: UInt32 = 0b100000000
        static let fistAttackLeft: UInt32 = 0b1000000000
        static let fistAttackRight: UInt32 = 0b10000000000
        static let itemBoss: UInt32 = 0b100000000000
        static let loseBox: UInt32 = 0b1000000000000
        static let ballDup: UInt32 = 0b10000000000000
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        bumperBallCollision(contact)
        ballItemCollision(contact)
        ballFlipperCollison(contact)
        ballFistProjectileCollision(contact)
        ballLoseBoxCollision(contact)
        dupBallLoseBoxCollision(contact)
    }
    
    func addBackdrop() {
        let bg = SKSpriteNode(imageNamed: "BackgroundSpace")
        bg.size = self.size
        backgroundWidth = bg.size.width
        backgroundHeight = bg.size.height
        bg.position = CGPoint(x: bg.size.width / 2, y: bg.size.height / 2)
        bg.zPosition = -1
        bg.name = "Background"
        pinballWorldNode.addChild(bg)
    }
    
    func addTimer(position: CGPoint, flipped: Bool){
        timerLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        timerLabel.fontSize = 48
        if timerColor == "green" {
            timerLabel.fontColor = SKColor.green.withAlphaComponent(0.75)
        }
        else if timerColor == "yellow" {
            timerLabel.fontColor = SKColor.yellow.withAlphaComponent(0.75)
        }
        else {
            timerLabel.fontColor = SKColor.red.withAlphaComponent(0.75)
        }
        
        if(flipped){
            self.timerLabel.yScale *= -1
        }
        timerLabel.zPosition = 1001
        timerLabel.text = "Time: 0.0"
        timerLabel.position = position
        timerLabel.name = "timer"
        pinballWorldNode.addChild(timerLabel)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            var handled = false
            
            // 1) Hit-test using PHYSICS bodies at the touch point
            physicsWorld.enumerateBodies(at: p) { body, stop in
                guard let node = body.node else { return }
                switch node.name {
                case "flipLeft":
                    self.applyLeftFlipperImpulse()
                    handled = true
                    stop.pointee = true
                    
                case "flipRight":
                    self.applyRightFlipperImpulse()
                    handled = true
                    stop.pointee = true
                    
                case "Pinball":
                    if self.jumpBoostAvailable {
                        self.jumpBoostAvailable = false
                        // compute side vs center using BALL position
                        let ballX = self.ball.position.x
                        let ballDistanceLeft = ballX
                        let ballDistanceRight = self.frame.width - ballX
                        let dx: CGFloat = (ballDistanceLeft <= ballDistanceRight) ? 100 : -100
                        self.ball.physicsBody?.applyImpulse(CGVector(dx: dx, dy: 100))
                    }
                    handled = true
                    stop.pointee = true
                    
                case "PinballDup":
                    if self.jumpBoostAvailable {
                        self.jumpBoostAvailable = false
                        // compute side vs center using DUP BALL position
                        let x = node.position.x
                        let left = x
                        let right = self.frame.width - x
                        let dx: CGFloat = (left <= right) ? 100 : -100
                        node.physicsBody?.applyImpulse(CGVector(dx: dx, dy: 100))
                    }
                    handled = true
                    stop.pointee = true
                    
                case "fistLeft":
                    if let sprite = node as? SKSpriteNode {
                        let positionMem = sprite.position
                        sprite.texture = SKTexture(imageNamed: "PistonCompressed")
                        sprite.position = CGPoint(x: 0, y: 20)
                        self.addFistProjectile(isRight: false)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            sprite.texture = SKTexture(imageNamed: "PistonUncompressed")
                            sprite.position = positionMem
                            sprite.physicsBody?.applyForce(CGVector(dx: 350, dy: 350))
                        }
                        handled = true
                        stop.pointee = true
                    }
                    
                case "fistRight":
                    if let sprite = node as? SKSpriteNode {
                        let positionMem = sprite.position
                        sprite.texture = SKTexture(imageNamed: "PistonCompressed")
                        sprite.xScale = -1
                        sprite.position = CGPoint(x: 390, y: 20)
                        self.addFistProjectile(isRight: true)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            sprite.texture = SKTexture(imageNamed: "PistonUncompressed")
                            sprite.xScale = -1
                            sprite.position = positionMem
                            sprite.physicsBody?.applyForce(CGVector(dx: -350, dy: 350))
                        }
                        handled = true
                        stop.pointee = true
                    }
                    
                default:
                    break
                }
            }
            
            if handled { continue }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        //control speed for main ball
        guard let bodyBall = ball.physicsBody else { return }
        
        let speedBall = hypot(bodyBall.velocity.dx, bodyBall.velocity.dy)
        let maxSpeedBall: CGFloat = 800
        
        if speedBall > maxSpeedBall {
            let scale = maxSpeedBall / speedBall
            bodyBall.velocity = CGVector(dx: bodyBall.velocity.dx * scale, dy: bodyBall.velocity.dy * scale)
        }
        
        timerValue -= 1.0 / 60.0
        timeSurvivedValue += 1.0 / 60.0
        
        if timerValue <= 60 {
            timerColor = "red"
            timerLabel.fontColor = SKColor.red.withAlphaComponent(0.75)
        }
        else if timerValue <= 120 {
            timerColor = "yellow"
            timerLabel.fontColor = SKColor.yellow.withAlphaComponent(0.75)
        }
        else {
            timerColor = "green"
            timerLabel.fontColor = SKColor.green.withAlphaComponent(0.75)
        }
        
        if timerValue <= 0 {
            losePublisher.send()
        }
        
        let minutes = Int(timerValue) / 60
        let seconds = Int(timerValue) % 60
        
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
        
        if ball.position.x < 0 || ball.position.x > 375 {
            for node in self.pinballWorldNode.children {
                if node.name == "Pinball" {
                    node.removeFromParent()
                }
            }
            addBall(position: CGPoint(x: 50, y: 500))
        }
        
        if activatedDupPower && activatedPunPower && activatedBossPower && activatedFlipPower {
            powerUpPublisher.send()
        }
        
        for node in self.pinballWorldNode.children {
            if node.name == "PinballDup" {
                dupBallActive = true
            }
        }
        
        //control speed for dup ball
        if dupBallActive == false { return }
        guard let bodyBallDup = dupBall.physicsBody else { return }
        
        let speedDupBall = hypot(bodyBallDup.velocity.dx, bodyBallDup.velocity.dy)
        let maxSpeedDupBall: CGFloat = 800
        
        if speedDupBall > maxSpeedDupBall {
            let scale = maxSpeedDupBall / speedDupBall
            bodyBallDup.velocity = CGVector(dx: bodyBallDup.velocity.dx * scale, dy: bodyBallDup.velocity.dy * scale)
        }
        
    }
    
    func ballFistProjectileCollision(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.fistAttackLeft {
            ball.physicsBody?.applyImpulse(CGVector(dx: 100, dy: 200))
        }
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.fistAttackRight {
            ball.physicsBody?.applyImpulse(CGVector(dx: -100, dy: 200))
        }
    }
    
    func bumperBallCollision(_ contact: SKPhysicsContact){
        let ballCategory = PhysicsCategory.ball
        let bumperCategory = PhysicsCategory.bumper
        
        let a = contact.bodyA
        let b = contact.bodyB
        
        guard let ball = (a.categoryBitMask == ballCategory ? a : b).node as? SKSpriteNode,
              let bumper = (a.categoryBitMask == bumperCategory ? a : b).node else {
            return
        }
        
        if let body = ball.physicsBody {
            var impulse = CGVector(dx: 0, dy: 0)
            
            switch bumper.name {
            case "bumperRight":
                impulse = CGVector(dx: -80, dy: 0)
            case "bumperLeft":
                impulse = CGVector(dx: 80, dy: 0)
            case "bumperCenter":
                if let ballPhysicsBody = ball.physicsBody {
                    let currentVelocity = ballPhysicsBody.velocity
                    let oppositeImpulse = CGVector(dx: -currentVelocity.dx, dy: -currentVelocity.dy)
                    ballPhysicsBody.applyImpulse(oppositeImpulse)
                }
            default:
                impulse = CGVector(dx: 0, dy: 30)
            }
            
            body.applyImpulse(impulse)
        }
    }
    
    func ballFlipperCollison(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.flipper {
            jumpBoostAvailable = true;
        }
    }
    
    func ballItemCollision(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.itemDupli {
            activatedDupPower = true
            DispatchQueue.main.async {
                otherNode.removeFromParent()
                self.addDupBall()
                self.dupBallActive = true
                self.dupPublisher.send(true)
                
                self.summonedOtherItems = false;
                DispatchQueue.main.asyncAfter(deadline: .now() + 40.0){
                    for node in self.pinballWorldNode.children {
                        if node.name == "PinballDup" {
                            self.timerValue += 60
                            node.removeFromParent()
                            self.dupBallActive = false
                            self.dupPublisher.send(false)
                        }
                    }
                    if !self.dupBallActive {
                        self.addItemDup()
                    }
                }
                self.addItemPun()
                self.addItemFlip()
                self.addBossItem()
            }
        }
        else if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.itemPun {
            activatedPunPower = true
            DispatchQueue.main.async {
                otherNode.removeFromParent()
                for node in self.pinballWorldNode.children {
                    if node.name == "flipLeft" || node.name == "flipRight" {
                        node.removeFromParent()
                    }
                }
                
                self.addFistsLeft()
                self.addFistsRight()
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0){
                    for node in self.pinballWorldNode.children {
                        if node.name == "fistLeft" || node.name == "fistRight" || node.name == "flipLeftPivot" || node.name == "flipRightPivot"{
                            node.removeFromParent()
                        }
                    }
                    self.addLeftFlipper()
                    self.flipLeft.zRotation = 0
                    self.flipLeft.physicsBody?.angularVelocity = 0
                    self.flipLeft.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
                    self.addRightFlipper()
                    self.flipRight.zRotation = 0
                    self.flipRight.physicsBody?.angularVelocity = 0
                    self.flipRight.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
                    self.summonedOtherItems = false
                    self.applyLeftFlipperImpulse()
                    self.applyRightFlipperImpulse()
                }
                self.addItemPun()
                if !self.dupBallActive {
                    self.addItemDup()
                }
                self.addItemFlip()
                self.addBossItem()
            }
        }
        else if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.itemFlip {
            activatedFlipPower = true
            DispatchQueue.main.async {
                otherNode.removeFromParent()
                let sceneHeight = self.size.height
                
                for node in self.pinballWorldNode.children {
                    if node.name == "triangleWall" {
                        node.removeFromParent()
                    }
                    
                    if node.name == "timer" {
                        print("removedFirst")
                        node.removeFromParent()
                    }
                }
                
                for node in self.children {
                    node.yScale *= -1
                    
                    let newY = sceneHeight - node.position.y
                    node.position.y = newY
                }
                
                self.addTimer(position: CGPoint(x: self.timerBackground.position.x, y: self.timerBackground.position.y + 12), flipped: true)
                
                self.addTrianglesLeftInverse(at: CGPoint(x: 0, y: 90))
                self.addTrianglesRightInverse(at: CGPoint(x: 402, y: 90))
                self.applyLeftFlipperImpulse()
                self.applyRightFlipperImpulse()
                
                self.flipPublisher.send()
                DispatchQueue.main.asyncAfter(deadline:.now() + 7.5){
                    self.physicsWorld.gravity.dy *= -0.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                    for node in self.children {
                        node.yScale *= -1
                        
                        let newY = sceneHeight - node.position.y
                        node.position.y = newY
                    }
                    
                    for node in self.pinballWorldNode.children {
                        if node.name == "triangleWall" {
                            node.removeFromParent()
                        }
                        if node.name == "timer" {
                            print("removedSecond")
                            node.removeFromParent()
                        }
                    }
                    self.addTimer(position: CGPoint(x: self.timerBackground.position.x, y: self.timerBackground.position.y - 13), flipped: true)
                    
                    self.timerLabel.yScale *= -1
                    
                    self.addTrianglesLeft(at: CGPoint(x: 0, y: -22))
                    self.addTrianglesRight(at: CGPoint(x: 400, y: -11))
                    
                    self.flipPublisher.send()
                    self.physicsWorld.gravity.dy *= (-10 / 3)
                    
                    self.addItemPun()
                    if !self.dupBallActive {
                        self.addItemDup()
                    }
                    self.addItemFlip()
                    self.addBossItem()
                }
            }
        }
        else if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.itemBoss {
            activatedBossPower = true
            DispatchQueue.main.async {
                self.bossPublisher.send()
                otherNode.removeFromParent()
                
                self.summonedOtherItems = false
                self.addItemPun()
                if !self.dupBallActive {
                    self.addItemDup()
                }
                self.addItemFlip()
                self.addBossItem()
            }
        }
    }
    
    func ballLoseBoxCollision(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.loseBox {
            if dupBallActive {
                for node in self.pinballWorldNode.children {
                    if node.name == "Pinball"{
                        node.removeFromParent()
                    }
                }
                addBall(position: dupBall.position)
                for node in self.pinballWorldNode.children {
                    if node.name == "PinballDup"{
                        node.removeFromParent()
                    }
                }
                dupBallActive = false
                dupPublisher.send(false)
            }
            else {
                losePublisher.send()
            }
        }
    }
    
    func dupBallLoseBoxCollision(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.ballDup {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.ballDup {
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.loseBox {
            for node in self.pinballWorldNode.children {
                if node.name == "PinballDup" {
                    dupBallActive = false
                    self.dupPublisher.send(false)
                    node.removeFromParent()
                }
            }
        }
    }
    
    func addBall(position: CGPoint) {
        ball = SKSpriteNode(imageNamed: ballSkin)
        ball.name = "Pinball"
        ball.size = CGSize(width: 55, height: 55)
        ball.position = position
        ball.physicsBody = SKPhysicsBody(circleOfRadius: ball.size.width / 2)
        ball.zPosition = -1
        ball.physicsBody?.restitution = 0.0
        ball.physicsBody?.friction = 0.5
        ball.physicsBody?.linearDamping = 0.2
        ball.physicsBody?.angularDamping = 0.5
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.usesPreciseCollisionDetection = true
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.physicsBody?.collisionBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.ballDup | PhysicsCategory.ball
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.itemDupli | PhysicsCategory.itemPun | PhysicsCategory.ball | PhysicsCategory.itemFlip | PhysicsCategory.fistAttackLeft | PhysicsCategory.fistLauncher | PhysicsCategory.fistAttackRight | PhysicsCategory.itemBoss | PhysicsCategory.loseBox
        
        pinballWorldNode.addChild(ball)
    }
    
    func addDupBall() {
        dupBall = SKSpriteNode(imageNamed: "PinballDup")
        dupBall.name = "PinballDup"
        dupBall.size = CGSize(width: 55, height: 55)
        dupBall.position = CGPoint(x: 351, y: 500)
        dupBall.physicsBody = SKPhysicsBody(circleOfRadius: dupBall.size.width / 2)
        dupBall.zPosition = -1
        dupBall.physicsBody?.restitution = 0.0
        dupBall.physicsBody?.friction = 0.5
        dupBall.physicsBody?.linearDamping = 0.9
        dupBall.physicsBody?.angularDamping = 0.5
        dupBall.physicsBody?.isDynamic = true
        dupBall.physicsBody?.usesPreciseCollisionDetection = true
        dupBall.physicsBody?.categoryBitMask = PhysicsCategory.ballDup
        dupBall.physicsBody?.collisionBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.ball | PhysicsCategory.ballDup
        dupBall.physicsBody?.contactTestBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.itemDupli | PhysicsCategory.itemPun | PhysicsCategory.ball | PhysicsCategory.itemFlip | PhysicsCategory.fistAttackLeft | PhysicsCategory.fistLauncher | PhysicsCategory.fistAttackRight | PhysicsCategory.itemBoss | PhysicsCategory.loseBox
        
        pinballWorldNode.addChild(dupBall)
    }
    
    func addCeiling(){
        let size = CGSize(width: 600, height: 10)
        let ceiling = SKSpriteNode(color: .clear, size: size)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        ceiling.physicsBody = body
        ceiling.position = CGPoint(x: 300, y: 740)
        ceiling.name = "ceiling"
        
        pinballWorldNode.addChild(ceiling)
    }
    
    func addLoseBox(){
        let loseBox = SKSpriteNode(color: SKColor.clear, size: CGSize(width: 400, height: 10))
        loseBox.name = "loseBox"
        let body = SKPhysicsBody(rectangleOf: loseBox.size)
        body.isDynamic = false
        loseBox.physicsBody = body
        loseBox.position = CGPoint(x: 195, y: 0)
        
        loseBox.physicsBody?.categoryBitMask = PhysicsCategory.loseBox
        loseBox.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        loseBox.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(loseBox)
    }
    
    func addLeftFlipper() {
        flipLeft = SKSpriteNode(imageNamed: "LeftFlipper")
        flipLeft.size = CGSize(width: 180, height: 180)
        flipLeft.anchorPoint = CGPoint(x: 0.18, y: 0.20)
        flipLeft.position = CGPoint(x: 66, y: 90)
        flipLeft.name = "flipLeft"
        
        let bodySize = CGSize(width: 110, height: 80)
        flipLeft.physicsBody = SKPhysicsBody(rectangleOf: bodySize, center: CGPoint(x: 20, y: 0))
        flipLeft.physicsBody?.isDynamic = true
        flipLeft.physicsBody?.affectedByGravity = false
        flipLeft.physicsBody?.allowsRotation = true
        flipLeft.physicsBody?.angularDamping = 0.0
        flipLeft.physicsBody?.friction = 0.2
        flipLeft.physicsBody?.density = 100.0
        flipLeft.physicsBody?.restitution = 0.0
        flipLeft.physicsBody?.usesPreciseCollisionDetection = true
        
        flipLeft.physicsBody?.categoryBitMask = PhysicsCategory.flipper
        flipLeft.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        flipLeft.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(flipLeft)
        
        let pivot = SKShapeNode(circleOfRadius: 5)
        pivot.name = "flipLeftPivot"
        pivot.position = flipLeft.position
        pivot.physicsBody = SKPhysicsBody(circleOfRadius: 1)
        pivot.physicsBody?.isDynamic = false
        pinballWorldNode.addChild(pivot)
        
        let pin = SKPhysicsJointPin.joint(
            withBodyA: pivot.physicsBody!,
            bodyB: flipLeft.physicsBody!,
            anchor: pivot.position
        )
        pin.shouldEnableLimits = true
        pin.lowerAngleLimit = -.pi / 4
        pin.upperAngleLimit = .pi / 3
        pin.frictionTorque = 0.0
        
        physicsWorld.add(pin)
    }
    
    func applyLeftFlipperImpulse() {
        flipLeft.physicsBody?.applyAngularImpulse(150.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.flipLeft.physicsBody?.applyAngularImpulse(-60.0)
        }
    }
    
    func addRightFlipper() {
        flipRight = SKSpriteNode(imageNamed: "RightFlipper")
        
        flipRight.size = CGSize(width: 180, height: 180)
        flipRight.anchorPoint = CGPoint(x: 0.82, y: 0.20)
        flipRight.name = "flipRight"
        //flipRight.alpha = 0
        
        let bodySize = CGSize(width: 100, height: 80)
        flipRight.physicsBody = SKPhysicsBody(rectangleOf: bodySize, center: CGPoint(x: -20, y: 0))
        
        flipRight.physicsBody?.isDynamic = true
        flipRight.physicsBody?.affectedByGravity = false
        flipRight.physicsBody?.allowsRotation = true
        flipRight.physicsBody?.angularDamping = 0.0
        flipRight.physicsBody?.friction = 0.2
        flipRight.physicsBody?.density = 100.0
        flipRight.physicsBody?.restitution = 0.0
        flipRight.physicsBody?.usesPreciseCollisionDetection = true
        
        flipRight.physicsBody?.categoryBitMask = PhysicsCategory.flipper
        flipRight.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        flipRight.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(flipRight)
        
        let pivot = SKShapeNode(circleOfRadius: 1)
        pivot.position = CGPoint(x: 324, y: 90)
        pivot.strokeColor = .clear
        pivot.name = "flipRightPivot"
        flipRight.position = pivot.position
        
        pivot.physicsBody = SKPhysicsBody(circleOfRadius: 1)
        pivot.physicsBody?.isDynamic = false
        pinballWorldNode.addChild(pivot)
        
        let pin = SKPhysicsJointPin.joint(
            withBodyA: pivot.physicsBody!,
            bodyB: flipRight.physicsBody!,
            anchor: pivot.position
        )
        
        pin.shouldEnableLimits = true
        pin.lowerAngleLimit = -.pi / 3
        pin.upperAngleLimit = .pi / 4
        pin.frictionTorque = 0.0
        
        self.physicsWorld.add(pin)
    }
    
    func applyRightFlipperImpulse() {
        flipRight.physicsBody?.applyAngularImpulse(-150)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.flipRight.physicsBody?.applyAngularImpulse(60.0)
        }
    }
    
    func addFistsLeft(){
        fistLeft = SKSpriteNode(imageNamed: "PistonUncompressed")
        fistLeft.size = CGSize(width: 300, height: 300)
        fistLeft.position = CGPoint(x: 35, y: 75)
        fistLeft.name = "fistLeft"
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 100, height: 17))
        fistLeft.physicsBody = body
        fistLeft.physicsBody?.isDynamic = false
        
        fistLeft.physicsBody?.categoryBitMask = PhysicsCategory.fistLauncher
        fistLeft.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        fistLeft.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(fistLeft)
    }
    
    func addFistsRight(){
        fistRight = SKSpriteNode(imageNamed: "PistonUncompressed")
        fistRight.size = CGSize(width: 300, height: 300)
        fistRight.position = CGPoint(x: 355, y: 75)
        fistRight.name = "fistRight"
        fistRight.xScale = -1.0
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 100, height: 17))
        fistRight.physicsBody = body
        fistRight.physicsBody?.isDynamic = false
        
        fistRight.physicsBody?.categoryBitMask = PhysicsCategory.fistLauncher
        fistRight.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        fistRight.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(fistRight)
    }
    
    func addFistProjectile(isRight: Bool){
        fistAttack = SKSpriteNode(imageNamed: "PistonProjectile")
        fistAttack.size = CGSize(width: 200, height: 200)
        fistAttack.name = "fistAttack"
        if isRight{
            fistAttack.xScale *= -1
        }
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 100, height: 40))
        fistAttack.physicsBody = body
        fistAttack.physicsBody?.isDynamic = true
        fistAttack.physicsBody?.affectedByGravity = false
        
        if isRight {
            fistAttack.physicsBody?.categoryBitMask = PhysicsCategory.fistAttackRight
            fistAttack.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
            fistAttack.physicsBody?.collisionBitMask = PhysicsCategory.none
            fistAttack.position = CGPoint(x: 355, y: 75)
            fistAttack.xScale = -1.0
            pinballWorldNode.addChild(fistAttack)
            
            fistAttack.physicsBody?.applyImpulse(CGVector(dx: -300, dy: 300))
        }
        else {
            fistAttack.physicsBody?.categoryBitMask = PhysicsCategory.fistAttackLeft
            fistAttack.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
            fistAttack.physicsBody?.collisionBitMask = PhysicsCategory.none
            fistAttack.position = CGPoint(x: 35, y: 75)
            pinballWorldNode.addChild(fistAttack)
            
            fistAttack.physicsBody?.applyImpulse(CGVector(dx: 300, dy: 300))
        }
    }
    
    func addSides(at position: CGPoint){
        let size = CGSize(width: 85, height: 180)
        let sideRectangle = SKSpriteNode(color: .clear, size: size)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        sideRectangle.physicsBody = body
        sideRectangle.position = position
        sideRectangle.physicsBody?.categoryBitMask = PhysicsCategory.rectangleWall
        sideRectangle.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        sideRectangle.physicsBody?.contactTestBitMask = PhysicsCategory.none
        sideRectangle.name = "sideRectangle"
        pinballWorldNode.addChild(sideRectangle)
    }
    
    func addTrianglesLeft(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: 122))
        trianglePath.addLine(to: CGPoint(x: 0, y: 195))
        trianglePath.addLine(to: CGPoint(x: 86, y: 122))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
        triangleWall.strokeColor = .clear
        triangleWall.position = position
        
        let body = SKPhysicsBody(polygonFrom: trianglePath)
        body.isDynamic = false
        triangleWall.physicsBody = body
        triangleWall.name = "triangleWall"
        triangleWall.zPosition = -1
        triangleWall.physicsBody?.categoryBitMask = PhysicsCategory.triangleWall
        triangleWall.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        triangleWall.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(triangleWall)
    }
    
    func addTrianglesLeftInverse(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: 0))
        trianglePath.addLine(to: CGPoint(x: 0, y: 85))
        trianglePath.addLine(to: CGPoint(x: 100, y: 0))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
        triangleWall.strokeColor = .clear
        triangleWall.fillColor = .clear
        triangleWall.position = position
        
        let body = SKPhysicsBody(polygonFrom: trianglePath)
        body.isDynamic = false
        triangleWall.physicsBody = body
        triangleWall.name = "triangleWall"
        triangleWall.zPosition = -1
        triangleWall.physicsBody?.categoryBitMask = PhysicsCategory.triangleWall
        triangleWall.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        triangleWall.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(triangleWall)
    }
    
    func addTrianglesRight(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: 110))
        trianglePath.addLine(to: CGPoint(x: 0, y: 183))
        trianglePath.addLine(to: CGPoint(x: -86, y: 110))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
        triangleWall.strokeColor = .clear
        triangleWall.position = position
        
        let body = SKPhysicsBody(polygonFrom: trianglePath)
        body.isDynamic = false
        triangleWall.physicsBody = body
        triangleWall.name = "triangleWall"
        triangleWall.zPosition = -1
        triangleWall.physicsBody?.categoryBitMask = PhysicsCategory.triangleWall
        triangleWall.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        triangleWall.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(triangleWall)
    }
    
    func addTrianglesRightInverse(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: 0))
        trianglePath.addLine(to: CGPoint(x: 0, y: 85))
        trianglePath.addLine(to: CGPoint(x: -100, y: 0))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
        triangleWall.strokeColor = .clear
        triangleWall.fillColor = .clear
        triangleWall.position = position
        
        let body = SKPhysicsBody(polygonFrom: trianglePath)
        body.isDynamic = false
        triangleWall.physicsBody = body
        triangleWall.name = "triangleWall"
        triangleWall.zPosition = -1
        triangleWall.physicsBody?.categoryBitMask = PhysicsCategory.triangleWall
        triangleWall.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        triangleWall.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(triangleWall)
    }
    
    func addBumperLeft(){
        bumperLeft = SKSpriteNode(imageNamed: "BumperLeft")
        bumperLeft.size = CGSize(width: 70, height: 70)
        bumperLeft.position = CGPoint(x: 35, y: 700)
        
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: -39, y: 34))
        trianglePath.addLine(to: CGPoint(x: -39, y: -42))
        trianglePath.addLine(to: CGPoint(x: 35, y: 34))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
        triangleWall.strokeColor = .clear
        triangleWall.position = bumperLeft.position
        
        let body = SKPhysicsBody(polygonFrom: trianglePath)
        body.isDynamic = false
        body.affectedByGravity = false
        
        bumperLeft.physicsBody = body
        bumperLeft.name = "bumperLeft"
        bumperLeft.physicsBody?.restitution = 0.0
        bumperLeft.physicsBody?.categoryBitMask = PhysicsCategory.bumper
        bumperLeft.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        bumperLeft.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(bumperLeft)
    }
    
    func addBumperRight(){
        let bumperRight = SKSpriteNode(imageNamed: "BumperRight")
        bumperRight.size = CGSize(width: 70, height: 70)
        bumperRight.position = CGPoint(x: 355, y: 700)
        bumperRight.name = "bumperRight"
        
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 35, y: 35))
        trianglePath.addLine(to: CGPoint(x: 35, y: -42))
        trianglePath.addLine(to: CGPoint(x: -31, y: 35))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
        triangleWall.strokeColor = .clear
        triangleWall.position = bumperRight.position
        
        let body = SKPhysicsBody(polygonFrom: trianglePath)
        body.isDynamic = false
        body.affectedByGravity = false
        body.restitution = 0.0
        body.categoryBitMask = PhysicsCategory.bumper
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
        
        bumperRight.physicsBody = body
        pinballWorldNode.addChild(bumperRight)
    }
    
    func addBumperCenter(){
        bumperCenter = SKSpriteNode(imageNamed: "BumperCenter")
        bumperCenter.size = CGSize(width: 100, height: 100)
        bumperCenter.position = CGPoint(x: 195, y: 450)
        
        let body = SKPhysicsBody(circleOfRadius: 3.0)
        body.isDynamic = false
        body.affectedByGravity = false
        
        bumperCenter.physicsBody = body
        bumperCenter.name = "bumperCenter"
        bumperCenter.physicsBody?.restitution = 0.0
        
        bumperCenter.physicsBody?.categoryBitMask = PhysicsCategory.bumper
        bumperCenter.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        bumperCenter.physicsBody?.contactTestBitMask = PhysicsCategory.none
        pinballWorldNode.addChild(bumperCenter)
    }
    
    func addWallTopLeft(){
        wall = SKSpriteNode(imageNamed: "Obstacle")
        wall.name = "obstacle"
        wall.size = CGSize(width: 50, height: 50)
        wall.position =  CGPoint(x: wall.size.width / 2, y: 550)
        wall.physicsBody = SKPhysicsBody(rectangleOf: wall.size)
        wall.physicsBody!.isDynamic = false
        wall.physicsBody!.affectedByGravity = false
        
        pinballWorldNode.addChild(wall)
        
        wall.run(wallMovement())
    }
    
    func addWallBottomLeft(){
        wall = SKSpriteNode(imageNamed: "Obstacle")
        wall.name = "obstacle"
        wall.size = CGSize(width: 50, height: 50)
        wall.position = CGPoint(x: wall.size.width / 2, y: 350)
        wall.physicsBody = SKPhysicsBody(rectangleOf: wall.size)
        wall.physicsBody!.isDynamic = false
        wall.physicsBody!.affectedByGravity = false
        
        pinballWorldNode.addChild(wall)
        wall.run(wallMovement())
    }
    
    func wallMovement() -> SKAction{
        let wait = SKAction.wait(forDuration: 0.5)
        
        let moveRight = SKAction.moveBy(x: backgroundWidth - wall.size.width, y: 0, duration: 2.0)
        let waitMid = SKAction.wait(forDuration: 0.3)
        let moveLeft = SKAction.moveBy(x: (-1 * backgroundWidth) + wall.size.width, y: 0, duration: 2.0)
        let waitMid3 = SKAction.wait(forDuration: 0.3)
        
        let pattern = SKAction.sequence([wait, moveRight, waitMid, moveLeft, waitMid3])
        
        let loop = SKAction.repeatForever(pattern)
        
        return loop
    }
    
    func addItemDup(){
        let delay = 30 * Double.random(in: 1...3)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let dupItem = SKSpriteNode(imageNamed: "Duplicate_Item")
                    dupItem.name = "dupItem"
                    dupItem.size = CGSize(width: 100, height: 100)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...190)
                        let randomY: CGFloat = CGFloat.random(in: 220...422)
                        position = CGPoint(x: randomX, y: randomY)
                    } while position.distance(to: self.ball.position) < 50
                    dupItem.position = position
                    dupItem.physicsBody = SKPhysicsBody(rectangleOf: dupItem.size)
                    dupItem.physicsBody!.isDynamic = false
                    dupItem.physicsBody?.affectedByGravity = false
                    
                    dupItem.physicsBody?.categoryBitMask = PhysicsCategory.itemDupli
                    dupItem.physicsBody?.collisionBitMask = PhysicsCategory.ball
                    dupItem.physicsBody?.contactTestBitMask = PhysicsCategory.none
                    
                    if(!self.summonedOtherItems){
                        self.summonedOtherItems = true
                        self.pinballWorldNode.addChild(dupItem)
                    }
                }
            ]))
        }
    }
    
    func addItemPun(){
        let delay = 30 * Double.random(in: 1...3)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let punItem = SKSpriteNode(imageNamed: "Punch_Item")
                    punItem.name = "punItem"
                    punItem.size = CGSize(width: 100, height: 100)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...190)
                        let randomY: CGFloat = CGFloat.random(in: 220...422)
                        position = CGPoint(x: randomX, y: randomY)
                    } while position.distance(to: self.ball.position) < 50
                    
                    punItem.position = position
                    
                    punItem.physicsBody = SKPhysicsBody(rectangleOf: punItem.size)
                    punItem.physicsBody!.isDynamic = false
                    punItem.physicsBody?.affectedByGravity = false
                    
                    punItem.physicsBody?.categoryBitMask = PhysicsCategory.itemPun
                    punItem.physicsBody?.collisionBitMask = PhysicsCategory.ball
                    punItem.physicsBody?.contactTestBitMask = PhysicsCategory.none
                    
                    if(!self.summonedOtherItems){
                        self.summonedOtherItems = true
                        self.pinballWorldNode.addChild(punItem)
                    }
                }
            ]))
        }
    }
    
    func addItemFlip(){
        let delay = 30 * Double.random(in: 1...3)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let flipItem = SKSpriteNode(imageNamed: "Flip_Item")
                    flipItem.name = "flipItem"
                    flipItem.size = CGSize(width: 100, height: 100)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...190)
                        let randomY: CGFloat = CGFloat.random(in: 220...422)
                        position = CGPoint(x: randomX, y: randomY)
                    } while position.distance(to: self.ball.position) < 50
                    flipItem.position = position
                    flipItem.physicsBody = SKPhysicsBody(rectangleOf: flipItem.size)
                    flipItem.physicsBody!.isDynamic = false
                    flipItem.physicsBody?.affectedByGravity = false
                    
                    flipItem.physicsBody?.categoryBitMask = PhysicsCategory.itemFlip
                    flipItem.physicsBody?.collisionBitMask = PhysicsCategory.ball
                    flipItem.physicsBody?.contactTestBitMask = PhysicsCategory.none
                    
                    if(!self.summonedOtherItems){
                        self.summonedOtherItems = true
                        self.pinballWorldNode.addChild(flipItem)
                    }
                }
            ]))
        }
    }
    
    func addBossItem(){
        let delay = 1 * Double.random(in: 1...3)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let bossItem = SKSpriteNode(imageNamed: "Boss_Item")
                    bossItem.name = "bossItem"
                    bossItem.size = CGSize(width: 100, height: 100)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...190)
                        let randomY: CGFloat = CGFloat.random(in: 220...422)
                        position = CGPoint(x: randomX, y: randomY)
                    } while position.distance(to: self.ball.position) < 50
                    bossItem.position = position
                    bossItem.physicsBody = SKPhysicsBody(rectangleOf: bossItem.size)
                    bossItem.physicsBody!.isDynamic = false
                    bossItem.physicsBody?.affectedByGravity = false
                    
                    bossItem.physicsBody?.categoryBitMask = PhysicsCategory.itemBoss
                    bossItem.physicsBody?.collisionBitMask = PhysicsCategory.ball
                    bossItem.physicsBody?.contactTestBitMask = PhysicsCategory.none
                    
                    if(!self.summonedOtherItems){
                        self.summonedOtherItems = true
                        self.pinballWorldNode.addChild(bossItem)
                    }
                }
            ]))
        }
    }
}
