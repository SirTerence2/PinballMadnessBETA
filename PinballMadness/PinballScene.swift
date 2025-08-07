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
    let geoSize = UIScreen.main.bounds.size
    let geoWidth = UIScreen.main.bounds.size.width
    let geoHeight = UIScreen.main.bounds.size.height
    
    override func didMove(to view: SKView) {
        guard !isSceneSetup else {
            self.addItemPun()
            self.addItemDup()
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
        addSides(at: CGPoint(x: geoWidth * 0.1, y: geoHeight * 0.032))
        addSides(at: CGPoint(x: geoWidth * 0.89, y: geoHeight * 0.026))
        addTrianglesLeft(at: CGPoint(x: 0, y: -1 * geoHeight * 0.0296))
        addTrianglesRight(at: CGPoint(x:geoWidth * 1.03, y: -1 * geoHeight * 0.013))
        
        addBall()

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
        
        timerBackground = SKShapeNode(rectOf: CGSize(width: geoWidth * 0.36, height: geoHeight * 0.071), cornerRadius: 10)
        timerBackground.name = "timeBackground"
        timerBackground.fillColor = SKColor.black.withAlphaComponent(1)
        timerBackground.strokeColor = .black
        timerBackground.zPosition = 1000
        timerBackground.position = CGPoint(x: size.width / 2, y: geoHeight * 0.91)
        pinballWorldNode.addChild(timerBackground)

        addTimer(position: CGPoint(x: timerBackground.position.x, y: timerBackground.position.y - geoHeight * 0.015), flipped: false)
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
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNode = atPoint(location)
        let positionBall = ball.position as CGPoint
        let ballDistanceLeft = positionBall.x
        let ballDistanceRight = frame.width - positionBall.x
        
        if touchedNode == flipLeft {
            applyLeftFlipperImpulse()
        } else if touchedNode == flipRight {
            applyRightFlipperImpulse()
        } else if touchedNode == ball {
            if jumpBoostAvailable {
                jumpBoostAvailable = false
                if ballDistanceLeft <= ballDistanceRight {
                    ball.physicsBody?.applyImpulse(CGVector(dx: 100, dy: 100))
                }
                else {
                    ball.physicsBody?.applyImpulse(CGVector(dx: -100, dy: 100))
                }
            }
        }
        
        if let sprite = touchedNode as? SKSpriteNode, sprite.name == "fistLeft" {
            let positionMem = sprite.position
            sprite.texture = SKTexture(imageNamed: "PistonCompressed")
            sprite.position = CGPoint(x: 0, y: 20)
            addFistProjectile(isRight: false)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                sprite.texture = SKTexture(imageNamed: "PistonUncompressed")
                sprite.position = positionMem
                sprite.physicsBody?.applyForce(CGVector(dx: 350, dy: 350))
            })
        }
        if let sprite = touchedNode as? SKSpriteNode, sprite.name == "fistRight" {
            let positionMem = sprite.position
            sprite.texture = SKTexture(imageNamed: "PistonCompressed")
            sprite.xScale = -1
            sprite.position = CGPoint(x: 390, y: 20)
            addFistProjectile(isRight: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                sprite.texture = SKTexture(imageNamed: "PistonUncompressed")
                sprite.xScale = -1
                sprite.position = positionMem
                sprite.physicsBody?.applyForce(CGVector(dx: -350, dy: 350))
            })
        }
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard let body = ball.physicsBody else { return }

        let speed = hypot(body.velocity.dx, body.velocity.dy)
        let maxSpeed: CGFloat = 800

        if speed > maxSpeed {
            let scale = maxSpeed / speed
            body.velocity = CGVector(dx: body.velocity.dx * scale, dy: body.velocity.dy * scale)
        }

        timerValue -= 1.0 / 30.0
        timeSurvivedValue += 1.0 / 30.0
        
        if timerValue <= 60 {
            timerColor = "red"
            timerLabel.fontColor = SKColor.red.withAlphaComponent(0.75)
        }
        else if timerValue <= 180 {
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
        
        let minutes = Int(timerValue) / 45
        let seconds = Int(timerValue) % 45
        
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
        
        if ball.position.x < 0 || ball.position.x > geoWidth * 0.95 {
            for node in self.pinballWorldNode.children {
                if node.name == "Pinball" {
                    node.removeFromParent()
                }
            }
            addBall()
        }
        
        if activatedDupPower && activatedPunPower && activatedBossPower && activatedFlipPower {
            powerUpPublisher.send()
        }
        
        for node in self.pinballWorldNode.children {
            if node.name == "PinballDup" {
                dupBallActive = true
            }
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
                self.dupPublisher.send(true)

                self.summonedOtherItems = false;
                DispatchQueue.main.asyncAfter(deadline: .now() + 40.0){
                    for node in self.pinballWorldNode.children {
                        if node.name == "PinballDup" {
                            self.timerValue += 120
                            node.removeFromParent()
                            self.dupPublisher.send(false)
                        }
                    }
                    self.addItemDup()
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
                
                self.addTimer(position: CGPoint(x: self.timerBackground.position.x, y: self.timerBackground.position.y + self.geoHeight * 0.0142), flipped: true)
                
                self.addTrianglesLeftInverse(at: CGPoint(x: 0, y: -1 * self.geoHeight * 0.025))
                self.addTrianglesRightInverse(at: CGPoint(x: self.geoWidth * 1.03, y: -1 * self.geoHeight * 0.013))
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
                    
                    self.addTrianglesLeft(at: CGPoint(x: 0, y: -1 * self.geoHeight * 0.03))
                    self.addTrianglesRight(at: CGPoint(x: self.geoWidth * 1.03, y: -1 * self.geoHeight * 0.013))
                    
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
            losePublisher.send()
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
                    node.removeFromParent()
                }
            }
        }
    }

    func addBall() {
        ball = SKSpriteNode(imageNamed: ballSkin)
        ball.name = "Pinball"
        ball.size = CGSize(width: geoWidth * 0.14, height: geoHeight * 0.065)
        ball.position = CGPoint(x: geoWidth * 0.13, y: geoHeight * 0.59)
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
        ball = SKSpriteNode(imageNamed: "PinballDup")
        ball.name = "PinballDup"
        ball.size = CGSize(width: geoWidth * 0.14, height: geoHeight * 0.065)
        ball.position = CGPoint(x: geoWidth * 0.9, y: geoHeight * 0.59)
        ball.physicsBody = SKPhysicsBody(circleOfRadius: ball.size.width / 2)
        ball.physicsBody?.applyImpulse(CGVector(dx: 20, dy: 20))
        ball.zPosition = -1
        ball.physicsBody?.restitution = 0.0
        ball.physicsBody?.friction = 0.5
        ball.physicsBody?.linearDamping = 0.2
        ball.physicsBody?.angularDamping = 0.5
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.usesPreciseCollisionDetection = true
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ballDup
        ball.physicsBody?.collisionBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.ball | PhysicsCategory.ballDup
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.itemDupli | PhysicsCategory.itemPun | PhysicsCategory.ball | PhysicsCategory.itemFlip | PhysicsCategory.fistAttackLeft | PhysicsCategory.fistLauncher | PhysicsCategory.fistAttackRight | PhysicsCategory.itemBoss | PhysicsCategory.loseBox
        
        pinballWorldNode.addChild(ball)
    }
    
    func addCeiling(){
        let size = CGSize(width: geoWidth * 1.54, height: geoHeight * 0.012)
        let ceiling = SKSpriteNode(color: .clear, size: size)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        ceiling.physicsBody = body
        ceiling.position = CGPoint(x: geoWidth * 0.77, y: geoHeight * 0.88)
        ceiling.name = "ceiling"
        
        pinballWorldNode.addChild(ceiling)
    }
    
    func addLoseBox(){
        let loseBox = SKSpriteNode(color: SKColor.clear, size: CGSize(width: 400, height: 10))
        loseBox.name = "loseBox"
        let body = SKPhysicsBody(rectangleOf: loseBox.size)
        body.isDynamic = false
        loseBox.physicsBody = body
        loseBox.position = CGPoint(x: geoWidth * 0.5, y: 0)
        
        loseBox.physicsBody?.categoryBitMask = PhysicsCategory.loseBox
        loseBox.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        loseBox.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(loseBox)
    }
    
    func addLeftFlipper() {
        flipLeft = SKSpriteNode(imageNamed: "LeftFlipper")
        flipLeft.size = CGSize(width: geoWidth * 0.44, height: geoHeight * 0.27)
        flipLeft.anchorPoint = CGPoint(x: 0.18, y: 0.20)
        flipLeft.position = CGPoint(x: geoWidth * 0.17, y: geoHeight * 0.12)
        flipLeft.name = "flipLeft"

        let bodySize = CGSize(width: geoWidth * 0.26, height: geoHeight * 0.02)
        flipLeft.physicsBody = SKPhysicsBody(rectangleOf: bodySize, center: CGPoint(x: geoWidth * 0.05, y: 0))
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
        pivot.strokeColor = .clear
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
        pin.lowerAngleLimit = -.pi / 3
        pin.upperAngleLimit = .pi / 3
        pin.frictionTorque = 0.0

        physicsWorld.add(pin)
    }
    
    func applyLeftFlipperImpulse() {
        flipLeft.physicsBody?.applyAngularImpulse(100.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.flipLeft.physicsBody?.applyAngularImpulse(-60.0)
        }
    }

    func addRightFlipper() {
        flipRight = SKSpriteNode(imageNamed: "RightFlipper")
        
        flipRight.size = CGSize(width: geoWidth * 0.44, height: geoHeight * 0.27)
        flipRight.anchorPoint = CGPoint(x: 0.85, y: 0.18)
        flipRight.name = "flipRight"
        //flipRight.alpha = 0
        
        let bodySize = CGSize(width: geoWidth * 0.26, height: geoHeight * 0.02)
        flipRight.physicsBody = SKPhysicsBody(rectangleOf: bodySize, center: CGPoint(x: -1 * geoWidth * 0.05, y: 0))
        
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
        pivot.position = CGPoint(x: geoWidth * 0.83, y: geoHeight * 0.12)
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
        pin.upperAngleLimit = .pi / 3
        pin.frictionTorque = 0.0

        self.physicsWorld.add(pin)
    }

    func applyRightFlipperImpulse() {
        flipRight.physicsBody?.applyAngularImpulse(-100)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.flipRight.physicsBody?.applyAngularImpulse(60.0)
        }
    }
    
    func addFistsLeft(){
        fistLeft = SKSpriteNode(imageNamed: "PistonUncompressed")
        fistLeft.size = CGSize(width: geoWidth * 0.77, height: geoHeight * 0.36)
        fistLeft.position = CGPoint(x: geoWidth * 0.09, y: geoHeight * 0.09)
        fistLeft.name = "fistLeft"
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: geoWidth * 0.26, height: geoHeight * 0.02))
        fistLeft.physicsBody = body
        fistLeft.physicsBody?.isDynamic = false
        
        fistLeft.physicsBody?.categoryBitMask = PhysicsCategory.fistLauncher
        fistLeft.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        fistLeft.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(fistLeft)
    }
    
    func addFistsRight(){
        fistRight = SKSpriteNode(imageNamed: "PistonUncompressed")
        fistRight.size = CGSize(width: geoWidth * 0.77, height: geoHeight * 0.36)
        fistRight.position = CGPoint(x: geoWidth * 0.91, y: geoHeight * 0.09)
        fistRight.name = "fistRight"
        fistRight.xScale = -1.0
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: geoWidth * 0.26, height: geoHeight * 0.02))
        fistRight.physicsBody = body
        fistRight.physicsBody?.isDynamic = false
        
        fistRight.physicsBody?.categoryBitMask = PhysicsCategory.fistLauncher
        fistRight.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        fistRight.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(fistRight)
    }
    
    func addFistProjectile(isRight: Bool){
        fistAttack = SKSpriteNode(imageNamed: "PistonProjectile")
        fistAttack.size = CGSize(width: geoWidth * 0.51, height: geoHeight * 0.24)
        fistAttack.name = "fistAttack"
        if isRight{
            fistAttack.xScale *= -1
        }
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: geoWidth * 0.26, height: geoHeight * 0.05))
        fistAttack.physicsBody = body
        fistAttack.physicsBody?.isDynamic = true
        fistAttack.physicsBody?.affectedByGravity = false
        
        if isRight {
            fistAttack.physicsBody?.categoryBitMask = PhysicsCategory.fistAttackRight
            fistAttack.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
            fistAttack.physicsBody?.collisionBitMask = PhysicsCategory.none
            fistAttack.position = CGPoint(x: geoWidth * 0.91, y: geoHeight * 0.09)
            fistAttack.xScale = -1.0
            pinballWorldNode.addChild(fistAttack)
            
            fistAttack.physicsBody?.applyImpulse(CGVector(dx: -1 * geoWidth * 0.77, dy: geoHeight * 0.36))
        }
        else {
            fistAttack.physicsBody?.categoryBitMask = PhysicsCategory.fistAttackLeft
            fistAttack.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
            fistAttack.physicsBody?.collisionBitMask = PhysicsCategory.none
            fistAttack.position = CGPoint(x: geoWidth * 0.09, y: geoHeight * 0.09)
            pinballWorldNode.addChild(fistAttack)
            
            fistAttack.physicsBody?.applyImpulse(CGVector(dx: geoWidth * 0.77, dy: geoHeight * 0.36))
        }
    }
    
    func addSides(at position: CGPoint){
        let size = CGSize(width: geoWidth * 0.22, height: geoHeight * 0.21)
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
        trianglePath.move(to: CGPoint(x: 0, y: geoHeight * 0.16))
        trianglePath.addLine(to: CGPoint(x: 0, y: geoHeight * 0.25))
        trianglePath.addLine(to: CGPoint(x: geoWidth * 0.21, y: geoHeight * 0.16))
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
        trianglePath.move(to: CGPoint(x: 0, y: geoHeight * 0.16))
        trianglePath.addLine(to: CGPoint(x: 0, y: geoHeight * 0.25))
        trianglePath.addLine(to: CGPoint(x: geoWidth * 0.21, y: geoHeight * 0.16))
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
    
    func addTrianglesRight(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: geoHeight * 0.14))
        trianglePath.addLine(to: CGPoint(x: 0, y: geoHeight * 0.25))
        trianglePath.addLine(to: CGPoint(x: -1 * geoWidth * 0.23, y: geoHeight * 0.14))
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
        trianglePath.move(to: CGPoint(x: 0, y: geoHeight * 0.14))
        trianglePath.addLine(to: CGPoint(x: 0, y: geoHeight * 0.25))
        trianglePath.addLine(to: CGPoint(x: -1 * geoWidth * 0.23, y: geoHeight * 0.14))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
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
        bumperLeft.size = CGSize(width: geoWidth * 0.18, height: geoHeight * 0.08)
        print(geoWidth)
        print(geoHeight)
        bumperLeft.position = CGPoint(x: geoWidth * 0.09, y: geoHeight * 0.795)
        
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: -1 * geoWidth * 0.1, y: geoHeight * 0.04))
        trianglePath.addLine(to: CGPoint(x: -1 * geoWidth * 0.1, y: -1 * geoHeight * 0.05))
        trianglePath.addLine(to: CGPoint(x: geoWidth * 0.09, y: geoHeight * 0.04))
        trianglePath.closeSubpath()
        
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
        bumperRight.size = CGSize(width: geoWidth * 0.18, height: geoHeight * 0.083)
        bumperRight.position = CGPoint(x: geoWidth * 0.91, y: geoHeight * 0.735)
        bumperRight.name = "bumperRight"

        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: geoWidth * 0.09, y: geoHeight * 0.04))
        trianglePath.addLine(to: CGPoint(x: geoWidth * 0.09, y: -1 * geoHeight * 0.05))
        trianglePath.addLine(to: CGPoint(x: -1 * geoWidth * 0.08, y: geoHeight * 0.04))
        trianglePath.closeSubpath()
        
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
        bumperCenter.size = CGSize(width: geoWidth * 0.26, height: geoHeight * 0.11)
        bumperCenter.position = CGPoint(x: geoWidth * 0.5, y: geoHeight * 0.5)
        
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
        wall.size = CGSize(width: geoWidth * 0.13, height: geoHeight * 0.06)
        wall.position =  CGPoint(x: wall.size.width / 2, y: geoHeight * 0.625)
        wall.physicsBody = SKPhysicsBody(rectangleOf: wall.size)
        wall.physicsBody!.isDynamic = false
        wall.physicsBody!.affectedByGravity = false

        pinballWorldNode.addChild(wall)
        
        wall.run(wallMovement())
    }
    
    func addWallBottomLeft(){
        wall = SKSpriteNode(imageNamed: "Obstacle")
        wall.name = "obstacle"
        wall.size = CGSize(width: geoWidth * 0.13, height: geoHeight * 0.06)
        wall.position = CGPoint(x: wall.size.width / 2, y: geoHeight * 0.375)
        wall.physicsBody = SKPhysicsBody(rectangleOf: wall.size)
        wall.physicsBody!.isDynamic = false
        wall.physicsBody!.affectedByGravity = false

        pinballWorldNode.addChild(wall)
        wall.run(wallMovement())
    }
    
    func wallMovement() -> SKAction{
        let wait = SKAction.wait(forDuration: 0.5)

        let moveRight = SKAction.moveBy(x: geoWidth - wall.size.width, y: 0, duration: 2.0)
        let waitMid = SKAction.wait(forDuration: 0.3)
        let moveLeft = SKAction.moveBy(x: (-1 * geoWidth) + wall.size.width, y: 0, duration: 2.0)
        let waitMid3 = SKAction.wait(forDuration: 0.3)

        let pattern = SKAction.sequence([wait, moveRight, waitMid, moveLeft, waitMid3])

        let loop = SKAction.repeatForever(pattern)
        
        return loop
    }
    
    func addItemDup(){
        let delay = 40 * Double.random(in: 2...5)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let dupItem = SKSpriteNode(imageNamed: "Duplicate_Item")
                    dupItem.name = "dupItem"
                    dupItem.size = CGSize(width: self.geoWidth * 0.26, height: self.geoHeight * 0.12)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...(self.geoWidth * 0.49))
                        let randomY: CGFloat = CGFloat.random(in: (self.geoHeight * 0.26)...(self.geoWidth * 0.50))
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
        let delay = 50 * Double.random(in: 2...5)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let punItem = SKSpriteNode(imageNamed: "Punch_Item")
                    punItem.name = "punItem"
                    punItem.size = CGSize(width: self.geoWidth * 0.26, height: self.geoHeight * 0.12)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...(self.geoWidth * 0.49))
                        let randomY: CGFloat = CGFloat.random(in: (self.geoHeight * 0.26)...(self.geoWidth * 0.50))
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
        let delay = 30 * Double.random(in: 1...6)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let flipItem = SKSpriteNode(imageNamed: "Flip_Item")
                    flipItem.name = "punItem"
                    flipItem.size = CGSize(width: self.geoWidth * 0.26, height: self.geoHeight * 0.12)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...(self.geoWidth * 0.49))
                        let randomY: CGFloat = CGFloat.random(in: (self.geoHeight * 0.26)...(self.geoWidth * 0.50))
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
        let delay = 70 * Double.random(in: 1...6)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let bossItem = SKSpriteNode(imageNamed: "Boss_Item")
                    bossItem.name = "bossItem"
                    bossItem.size = CGSize(width: self.geoWidth * 0.26, height: self.geoHeight * 0.12)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...(self.geoWidth * 0.49))
                        let randomY: CGFloat = CGFloat.random(in: (self.geoHeight * 0.26)...(self.geoWidth * 0.50))
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
