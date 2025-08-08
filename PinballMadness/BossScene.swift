//
//  BossScene.swift
//  PinballMadness
//
//  Created by Muhammad Mahmood on 7/26/25.
//
import SpriteKit
import Combine

class BossScene: SKScene, SKPhysicsContactDelegate {
    var bumperLeft: SKSpriteNode!
    var bumperRight: SKSpriteNode!
    
    var ball: SKSpriteNode!
    var dupBall: SKSpriteNode!
    var ballSkin: String = "Pinball"
    var dupBallThere: Bool = false
    var jumpBoostAvailable: Bool = true
    
    var boss: SKSpriteNode!
    
    var flipLeft: SKSpriteNode!
    var flipRight: SKSpriteNode!
    
    var bossHealth: Int = 20
    var bossPushAttack: SKSpriteNode!
    var bossLaserAttack: SKSpriteNode!
    
    var ballHealth: Int = 1000
    var chargedShot: Bool = false
    
    var meteor: SKSpriteNode!
    var meteorThere: Bool = false
    
    var hpLabelBoss: SKLabelNode!
    var hpCategoryBoss: SKLabelNode!
    var hpLabelPlayer: SKLabelNode!
    var hpCategoryPlayer: SKLabelNode!
    var hpBackground: SKShapeNode!
    var hpColor: String = "green"
    
    var timeSurvivedValue: TimeInterval = 0
    
    let victoryPublisher = PassthroughSubject<Void, Never>()
    let losePublisher = PassthroughSubject<Void, Never>()
    let neverRecievedDamagePublisher = PassthroughSubject<Void, Never>()
    
    init(size: CGSize, ballSkin: String, dupBallThere: Bool) {
        self.ballSkin = ballSkin
        self.dupBallThere = dupBallThere
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        static let bossEnt: UInt32 = 0b1000000000000
        static let meteor: UInt32 = 0b10000000000000
        static let bossAttack: UInt32 = 0b1000000000000000
        static let loseBox: UInt32 = 0b10000000000000000
        static let ballDup: UInt32 = 0b100000000000000000
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
        
        if bossHealth <= 0 {
            if ballHealth == 1000 {
                neverRecievedDamagePublisher.send()
            }
            clearScene()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.victoryPublisher.send()
            }
        }
        hpLabelBoss.text = String(bossHealth)
        hpLabelPlayer.text = String(ballHealth)
        
        timeSurvivedValue += 1 / 60.0

        print("Boss " + String(Int(timeSurvivedValue)))
        if ballHealth <= 0 {
            losePublisher.send()
        }
        
        if dupBallThere == false { return }
        guard let bodyBallDup = dupBall.physicsBody else { return }

        let speedDupBall = hypot(bodyBallDup.velocity.dx, bodyBallDup.velocity.dy)
        let maxSpeedDupBall: CGFloat = 800

        if speedDupBall > maxSpeedDupBall {
            let scale = maxSpeedDupBall / speedDupBall
            bodyBallDup.velocity = CGVector(dx: bodyBallDup.velocity.dx * scale, dy: bodyBallDup.velocity.dy * scale)
        }
    }
    
    override func didMove(to view: SKView) {
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        self.physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        backgroundColor = .clear
        
        addBackground()
        addBumperLeft()
        addBumperRight()
        
        addSides(at: CGPoint(x: 39, y: 27))
        addSides(at: CGPoint(x: 349, y: 22))
        addTrianglesLeft(at: CGPoint(x: 0, y: -25))
        addTrianglesRight(at: CGPoint(x:400, y: -11))
        addCeiling()
        
        addBall(position: CGPoint(x: 50, y: 500))
        if dupBallThere {
            addDupBall()
        }
        
        addLeftFlipper()
        applyLeftFlipperImpulse()
        addRightFlipper()
        applyRightFlipperImpulse()
        
        addBoss()
        addLoseBox()
        let attackAction = SKAction.run {
            let random = Int.random(in: 0...1)
            if random == 0 {
                self.addPushAttack()
            } else {
                self.addLaserAttack()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                for node in self.children {
                    if node.name == "pushAttack" || node.name == "laserAttack" {
                        node.removeFromParent()
                    }
                }
            }
        }
        
        let waitAttackAction = SKAction.wait(forDuration: 5.0)
        
        let attackSequence = SKAction.sequence([attackAction, waitAttackAction])
        let repeatAttackForever = SKAction.repeatForever(attackSequence)
        
        self.run(repeatAttackForever, withKey: "attackLoop")
        
        let spawnAction = SKAction.run {
            if(!self.meteorThere) {
                self.addMeteor()
                self.meteorThere = true
            }
        }
        
        let waitAction = SKAction.wait(forDuration: 2.0)
        
        let sequence = SKAction.sequence([spawnAction, waitAction])
        let repeatForever = SKAction.repeatForever(sequence)
        
        self.run(repeatForever, withKey: "spawnLoop")

        addBackground(position: CGPoint(x: size.width / 4, y: 736))
        hpLabelBoss = SKLabelNode(fontNamed: "Copperplate-Bold")
        hpLabelBoss.fontSize = 23
        if bossHealth >= 400 {
            hpLabelBoss.fontColor = SKColor.green.withAlphaComponent(0.75)
        }
        else if bossHealth >= 200 {
            hpLabelBoss.fontColor = SKColor.yellow.withAlphaComponent(0.75)
        }
        else if bossHealth >= 0 {
            hpLabelBoss.fontColor = SKColor.red.withAlphaComponent(0.75)
        }
        
        hpLabelBoss.zPosition = 1001
        hpLabelBoss.text = String(bossHealth)
        hpLabelBoss.position = CGPoint(x: size.width / 4, y: hpBackground.position.y - 15)
        hpLabelBoss.name = "hpBoss"
        
        hpCategoryBoss = SKLabelNode(fontNamed: "Copperplate-Bold")
        hpCategoryBoss.fontSize = 20
        hpCategoryBoss.zPosition = 1001
        hpCategoryBoss.fontColor = SKColor.red.withAlphaComponent(0.75)
        hpCategoryBoss.position = CGPoint(x: hpLabelBoss.position.x, y: hpLabelBoss.position.y + 20)
        hpCategoryBoss.text = "Boss:"
        hpCategoryBoss.name = "hpCategoryBoss"
        
        addChild(hpCategoryBoss)
        addChild(hpLabelBoss)
        
        addBackground(position: CGPoint(x: 3 * size.width / 4, y: 736))
        hpLabelPlayer = SKLabelNode(fontNamed: "Copperplate-Bold")
        hpLabelPlayer.fontSize = 22
        if ballHealth >= 400 {
            hpLabelPlayer.fontColor = SKColor.green.withAlphaComponent(0.75)
        }
        else if ballHealth >= 200 {
            hpLabelPlayer.fontColor = SKColor.yellow.withAlphaComponent(0.75)
        }
        else if ballHealth >= 0 {
            hpLabelPlayer.fontColor = SKColor.red.withAlphaComponent(0.75)
        }
        
        hpLabelPlayer.zPosition = 1001
        hpLabelPlayer.text = String(ballHealth)
        hpLabelPlayer.position = CGPoint(x: 3 * size.width / 4, y: hpBackground.position.y - 15)
        hpLabelPlayer.name = "hpPlayer"
        
        hpCategoryPlayer = SKLabelNode(fontNamed: "Copperplate-Bold")
        hpCategoryPlayer.fontSize = 15
        hpCategoryPlayer.zPosition = 1001
        hpCategoryPlayer.fontColor = SKColor.green.withAlphaComponent(0.75)
        hpCategoryPlayer.position = CGPoint(x: hpLabelPlayer.position.x, y: hpLabelPlayer.position.y + 20)
        hpCategoryPlayer.text = "Player:"
        hpCategoryPlayer.name = "hpCategory"
        
        addChild(hpCategoryPlayer)
        addChild(hpLabelPlayer)
    }
    
    func addBackground(position: CGPoint){
        hpBackground = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 10)
        hpBackground.name = "timeBackground"
        hpBackground.fillColor = SKColor.black.withAlphaComponent(1)
        hpBackground.strokeColor = .black
        hpBackground.zPosition = 1000
        hpBackground.position = position
        addChild(hpBackground)
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        bumperBallCollision(contact)
        ballFlipperCollison(contact)
        ballBossCollision(contact)
        ballMeteorCollision(contact)
        meteorBossCollision(contact)
        attackBallCollision(contact)
        attackObjectCollision(contact)
        ballLoseBoxCollision(contact)
        dupBallLoseBoxCollision(contact)
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
    
    func ballBossCollision(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.bossEnt {
            if !chargedShot {
                bossHealth -= 25
            } else {
                bossHealth -= 50
            }

            guard let ballPhysicsBody = ball?.physicsBody else { return }

            let currentVelocity = ballPhysicsBody.velocity

            let reverseImpulse = CGVector(
                dx: -currentVelocity.dx * 0.75,
                dy: -currentVelocity.dy * 0.75
            )

            ballPhysicsBody.applyImpulse(reverseImpulse)
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
            default:
                impulse = CGVector(dx: 0, dy: 30)
            }

            body.applyImpulse(impulse)
        }
    }
    
    func ballMeteorCollision(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.meteor {
            meteorApplyImpulse()
        }
    }
    
    func meteorBossCollision(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.bossEnt {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.bossEnt {
            otherNode = contact.bodyA.node!
        } else {
            return
        }

        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.meteor {
            otherNode.removeFromParent()
            bossHealth -= 100
            meteorThere = false
        }
    }
    
    func attackBallCollision(_ contact: SKPhysicsContact){
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.ball {
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.bossAttack {
            if otherNode.name == "pushAttack" {
                ball.physicsBody?.applyImpulse(CGVector(dx: (bossPushAttack.physicsBody?.velocity.dx)! * 200, dy: (bossPushAttack.physicsBody?.velocity.dx)! * 200))
            }
            else {
                ballHealth -= 100
            }
            otherNode.removeFromParent()
        }
    }
    
    func attackObjectCollision(_ contact: SKPhysicsContact){
        let attackNode: SKNode
        let otherNode: SKNode
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.bossAttack {
            attackNode = contact.bodyA.node!
            otherNode = contact.bodyB.node!
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.bossAttack {
            attackNode = contact.bodyB.node!
            otherNode = contact.bodyA.node!
        } else {
            return
        }
        
        if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.flipper || otherNode.physicsBody?.categoryBitMask == PhysicsCategory.meteor || otherNode.physicsBody?.categoryBitMask == PhysicsCategory.bumper || otherNode.physicsBody?.categoryBitMask == PhysicsCategory.rectangleWall || otherNode.physicsBody?.categoryBitMask == PhysicsCategory.triangleWall || otherNode.physicsBody?.categoryBitMask == PhysicsCategory.loseBox {
            attackNode.removeFromParent()
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
            if dupBallThere {
                for node in self.children {
                    if node.name == "Pinball"{
                        node.removeFromParent()
                    }
                }
                addBall(position: dupBall.position)
                for node in self.children {
                    if node.name == "PinballDup"{
                        node.removeFromParent()
                    }
                }
                dupBallThere = false
            } else {
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
            for node in self.children {
                if node.name == "PinballDup" {
                    self.dupBallThere = false
                    node.removeFromParent()
                }
            }
        }
    }
    
    func meteorApplyImpulse(){
        let differenceX = boss.position.x - meteor.position.x
        let differenceY = boss.position.y - meteor.position.y
        let direction = CGVector(dx: differenceX, dy: differenceY)

        let length = sqrt(differenceX * differenceX + differenceY * differenceY)
        if length == 0 { return }

        let normalized = CGVector(dx: direction.dx / length, dy: direction.dy / length)
        let force = CGVector(dx: normalized.dx * 2, dy: normalized.dy * 2)

        boss.physicsBody?.applyImpulse(force)
    }
    
    func clearScene() {
        self.removeAllActions()
            
            // Make a copy of the children list before removing
            let childrenCopy = self.children
            for child in childrenCopy {
                child.removeFromParent()
            }

            self.removeAllChildren()
            self.isPaused = true
    }
    
    func addBackground(){
        let bg = SKSpriteNode(imageNamed: "BossStage")
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.size = self.size
        bg.zPosition = -1
        addChild(bg)
    }
    
    func addLoseBox(){
        let loseBox = SKSpriteNode(color: SKColor.clear, size: CGSize(width: 400, height: 10))
        loseBox.name = "loseBox"
        let body = SKPhysicsBody(rectangleOf: loseBox.size)
        body.isDynamic = false
        loseBox.physicsBody = body
        loseBox.position = CGPoint(x: frame.width / 2, y: 0)
        
        loseBox.physicsBody?.categoryBitMask = PhysicsCategory.loseBox
        loseBox.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        loseBox.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        addChild(loseBox)
    }
    
    func addMeteor(){
        meteor = SKSpriteNode(imageNamed: "Aestroid")
        meteor.size = CGSize(width: 100, height: 100)
        let body = SKPhysicsBody(circleOfRadius: meteor.size.width / 2)
        let randomX = CGFloat.random(in: ((frame.width / 4)...(3 * (frame.width / 4))))
        let randomY = CGFloat.random(in: ((frame.height / 4)...(2 * (frame.height / 4))))
        meteor.physicsBody = body
        meteor.position = CGPoint(x: randomX, y: randomY)
        meteor.physicsBody?.isDynamic = true
        meteor.physicsBody?.affectedByGravity = false
        meteor.physicsBody?.categoryBitMask = PhysicsCategory.meteor
        meteor.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.flipper | PhysicsCategory.triangleWall | PhysicsCategory.rectangleWall | PhysicsCategory.bumper | PhysicsCategory.bossEnt | PhysicsCategory.ballDup
        meteor.physicsBody?.contactTestBitMask = PhysicsCategory.ball | PhysicsCategory.bossEnt | PhysicsCategory.ballDup
        addChild(meteor)
    }
    
    func addBall(position: CGPoint) {
        ball = SKSpriteNode(imageNamed: ballSkin)
        ball.name = "Pinball"
        ball.size = CGSize(width: 55, height: 55)
        ball.position = position
        ball.physicsBody = SKPhysicsBody(circleOfRadius: ball.size.width / 2)
        ball.zPosition = -1
        ball.physicsBody?.restitution = 0.5
        ball.physicsBody?.friction = 0.5
        ball.physicsBody?.linearDamping = 0.2
        ball.physicsBody?.angularDamping = 0.5
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.usesPreciseCollisionDetection = true
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.physicsBody?.collisionBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.ballDup | PhysicsCategory.ball
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.itemDupli | PhysicsCategory.itemPun | PhysicsCategory.ball | PhysicsCategory.itemFlip | PhysicsCategory.fistAttackLeft | PhysicsCategory.fistLauncher | PhysicsCategory.fistAttackRight | PhysicsCategory.itemBoss | PhysicsCategory.bossEnt | PhysicsCategory.bossAttack | PhysicsCategory.loseBox
        
        addChild(ball)
    }
    
    func addDupBall() {
        dupBall = SKSpriteNode(imageNamed: "PinballDup")
        dupBall.name = "PinballDup"
        dupBall.size = CGSize(width: 55, height: 55)
        dupBall.position = CGPoint(x: 351, y: 500)
        dupBall.physicsBody = SKPhysicsBody(circleOfRadius: ball.size.width / 2)
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
        
        addChild(dupBall)
    }
    
    func addBumperLeft(){
        bumperLeft = SKSpriteNode(imageNamed: "BumperLeft")
        bumperLeft.size = CGSize(width: 70, height: 70)
        bumperLeft.position = CGPoint(x: 35, y: 680)
        
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: -40, y: 35))
        trianglePath.addLine(to: CGPoint(x: -40, y: -40))
        trianglePath.addLine(to: CGPoint(x: 35, y: 35))
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
        
        addChild(bumperLeft)
    }
    
    func addBumperRight(){
        let bumperRight = SKSpriteNode(imageNamed: "BumperRight")
        bumperRight.size = CGSize(width: 70, height: 70)
        bumperRight.position = CGPoint(x: 367, y: 680)
        bumperRight.name = "bumperRight"

        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 35, y: 35))
        trianglePath.addLine(to: CGPoint(x: 35, y: -40))
        trianglePath.addLine(to: CGPoint(x: -30, y: 35))
        trianglePath.closeSubpath()
        
        let body = SKPhysicsBody(polygonFrom: trianglePath)
        body.isDynamic = false
        body.affectedByGravity = false
        body.restitution = 0.0
        body.categoryBitMask = PhysicsCategory.bumper
        body.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        body.contactTestBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup

        bumperRight.physicsBody = body
        addChild(bumperRight)
    }
    
    func addBoss(){
        boss = SKSpriteNode(imageNamed: "BossEntity")
        boss.size = CGSize(width: 180, height: 180)
        
        let body = SKPhysicsBody(circleOfRadius: boss.size.width / 2)
        boss.position = CGPoint(x: frame.width / 2, y: 625)
        boss.physicsBody = body
        boss.physicsBody?.isDynamic = false
        boss.physicsBody?.affectedByGravity = false
        
        boss.physicsBody?.categoryBitMask = PhysicsCategory.bossEnt
        boss.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.meteor | PhysicsCategory.ballDup
        boss.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        addChild(boss)
    }
    
    func addPushAttack(){
        bossPushAttack = SKSpriteNode(imageNamed: "BossAttackPush")
        bossPushAttack.size = CGSize(width: 150, height: 150)
        bossPushAttack.position = CGPoint(x: frame.width / 2, y: 670)
        
        let body = SKPhysicsBody(circleOfRadius: bossPushAttack.size.width / 2)
        body.isDynamic = true
        body.affectedByGravity = false
        bossPushAttack.physicsBody = body
        
        let differenceX = boss.position.x - ball.position.x
        let differenceY = boss.position.y - ball.position.y
        let direction = CGVector(dx: differenceX, dy: differenceY)

        let length = sqrt(differenceX * differenceX + differenceY * differenceY)
        if length == 0 {
            return
        }

        let normalized = CGVector(dx: direction.dx / length, dy: direction.dy / length)
        let force = CGVector(dx: normalized.dx * -500, dy: normalized.dy * -500)
        let angle = atan2(force.dy, force.dx)
        bossPushAttack.zRotation = angle
        
        bossPushAttack.name = "pushAttack"
        bossPushAttack.physicsBody?.categoryBitMask = PhysicsCategory.bossAttack
        bossPushAttack.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.triangleWall | PhysicsCategory.rectangleWall | PhysicsCategory.ballDup
        bossPushAttack.physicsBody?.contactTestBitMask = PhysicsCategory.ball | PhysicsCategory.triangleWall | PhysicsCategory.rectangleWall | PhysicsCategory.ballDup
        
        addChild(bossPushAttack)
        bossPushAttack.physicsBody?.velocity = force
    }
    
    func addLaserAttack(){
        bossLaserAttack = SKSpriteNode(imageNamed: "BossAttackLaser")
        bossLaserAttack.size = CGSize(width: 200, height: 100)
        bossLaserAttack.position = CGPoint(x: frame.width / 2, y: 670)
        bossLaserAttack.xScale = -1
        
        let body = SKPhysicsBody(rectangleOf: bossLaserAttack.size)
        body.isDynamic = true
        body.affectedByGravity = false
        bossLaserAttack.physicsBody = body
        
        let differenceX = boss.position.x - ball.position.x
        let differenceY = boss.position.y - ball.position.y
        let direction = CGVector(dx: differenceX, dy: differenceY)

        let length = sqrt(differenceX * differenceX + differenceY * differenceY)
        if length == 0 { return }

        let normalized = CGVector(dx: direction.dx / length, dy: direction.dy / length)
        let force = CGVector(dx: normalized.dx * -500, dy: normalized.dy * -500)
        let angle = atan2(force.dy, force.dx)
        bossLaserAttack.zRotation = angle

        bossLaserAttack.name = "laserAttack"
        bossLaserAttack.physicsBody?.categoryBitMask = PhysicsCategory.bossAttack
        bossLaserAttack.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.triangleWall | PhysicsCategory.rectangleWall | PhysicsCategory.ballDup
        bossLaserAttack.physicsBody?.contactTestBitMask = PhysicsCategory.ball | PhysicsCategory.triangleWall | PhysicsCategory.rectangleWall | PhysicsCategory.ballDup
        
        addChild(bossLaserAttack)
        bossLaserAttack.physicsBody?.velocity = force
    }
    
    func addCeiling(){
        let size = CGSize(width: 600, height: 10)
        let ceiling = SKSpriteNode(color: .clear, size: size)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        ceiling.physicsBody = body
        ceiling.position = CGPoint(x: 300, y: 780)
        addChild(ceiling)
    }
    
    func addTrianglesRight(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: 120))
        trianglePath.addLine(to: CGPoint(x: 0, y: 210))
        trianglePath.addLine(to: CGPoint(x: -90, y: 120))
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
        
        addChild(triangleWall)
    }
    
    func addTrianglesLeft(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: 135))
        trianglePath.addLine(to: CGPoint(x: 0, y: 210))
        trianglePath.addLine(to: CGPoint(x: 80, y: 135))
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
        
        addChild(triangleWall)
    }
    
    func addSides(at position: CGPoint){
        let size = CGSize(width: 85, height: 175)
        let sideRectangle = SKSpriteNode(color: .clear, size: size)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        sideRectangle.physicsBody = body
        sideRectangle.position = position
        sideRectangle.physicsBody?.categoryBitMask = PhysicsCategory.rectangleWall
        sideRectangle.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        sideRectangle.physicsBody?.contactTestBitMask = PhysicsCategory.none
        sideRectangle.name = "sideWall"
        addChild(sideRectangle)
    }
    
    func addLeftFlipper() {
        flipLeft = SKSpriteNode(imageNamed: "LeftFlipper")
        flipLeft.size = CGSize(width: 180, height: 180)
        flipLeft.anchorPoint = CGPoint(x: 0.18, y: 0.20)
        flipLeft.position = CGPoint(x: 66, y: 90)
        flipLeft.name = "flipLeft"

        let bodySize = CGSize(width: 100, height: 17)
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

        addChild(flipLeft)

        let pivot = SKShapeNode(circleOfRadius: 5)
        pivot.strokeColor = .clear
        pivot.name = "flipLeftPivot"
        pivot.position = flipLeft.position
        pivot.physicsBody = SKPhysicsBody(circleOfRadius: 1)
        pivot.physicsBody?.isDynamic = false
        addChild(pivot)

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
        flipLeft.physicsBody?.applyAngularImpulse(100.0)

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
        
        let bodySize = CGSize(width: 100, height: 17)
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
        
        addChild(flipRight)

        let pivot = SKShapeNode(circleOfRadius: 1)
        pivot.position = CGPoint(x: 324, y: 90)
        pivot.strokeColor = .clear
        pivot.name = "flipRightPivot"
        flipRight.position = pivot.position

        pivot.physicsBody = SKPhysicsBody(circleOfRadius: 1)
        pivot.physicsBody?.isDynamic = false
        addChild(pivot)

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
        flipRight.physicsBody?.applyAngularImpulse(-100)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.flipRight.physicsBody?.applyAngularImpulse(60.0)
        }
    }
}
