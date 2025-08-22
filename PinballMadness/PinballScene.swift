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


extension SKNode {
    func spinForever(revDuration: TimeInterval = 1.0, key: String = "spin") {
        removeAction(forKey: key)
        let spin = SKAction.rotate(byAngle: .pi / 3, duration: revDuration)
        spin.timingMode = .linear
        spin.speed = 1.4
        
        let reverseSpin = SKAction.rotate(byAngle: -2 * .pi / 3, duration: revDuration)
        reverseSpin.timingMode = .linear
        reverseSpin.speed = 0.7

        run(.repeatForever(SKAction.sequence([spin, reverseSpin, spin])), withKey: key)
    }
    
    func stopSpinning(key: String = "spin") {
        removeAction(forKey: key)
    }
}

class PinballScene: SKScene, ObservableObject, SKPhysicsContactDelegate{
    var ball: SKSpriteNode!
    var pastBall: SKSpriteNode!
    var positionHistory: [(time: TimeInterval, pos: CGPoint, vel: CGVector?)] = []
    var hasUndoButton: Bool = false
    var activatedPunItem: Bool = false
    var currentTime: TimeInterval = 0
    var ballPastPosition: CGPoint = .zero
    var ballPastVelocity: CGVector = .zero
    var dupBall: SKSpriteNode!
    var ballSkin: String = "Pinball"
    
    var flipLeft: SKSpriteNode!
    var flipRight: SKSpriteNode!
    var leftPin: SKPhysicsJointPin?
    var rightPin: SKPhysicsJointPin?
    var leftPivot: SKNode?
    var rightPivot: SKNode?
    
    private var leftTouchDown = false
    private var rightTouchDown = false

    private let leftRest: CGFloat = -.pi/3
    private let leftPressedAngle: CGFloat =  .pi/3
    private let rightRest: CGFloat =  .pi/3
    private let rightPressedAngle: CGFloat = -.pi/3
    
    private var leftOwner: UITouch?
    private var rightOwner: UITouch?
    
    var fistLeft: SKSpriteNode!
    var fistRight: SKSpriteNode!
    var fistAttack: SKSpriteNode!
    var fistAttackTimer: Int = 20
    var fistAttackTimerLabel: SKLabelNode!
    var hitFistItem: Bool = false
    
    var wall: SKSpriteNode!
    
    var bumperLeft: SKSpriteNode!
    var bumperRight: SKSpriteNode!
    var bumperCenter: SKSpriteNode!
    
    var summonedOtherItems: Bool = false
    var jumpBoostAvailable: Bool = true
    var dupBallActive: Bool = false
    
    var activatedDupPower: Bool = false
    var activatedPunPower: Bool = false
    var activatedRotaPower: Bool = false
    var activatedBossPower: Bool = false
    
    var numberOfRotaChecksCollided: Int = 0
    var hitRotaItem: Bool = false
    let maxChecks: Int = 10
    var rotaItemCheck: SKSpriteNode!
    
    var timerLabel: SKLabelNode!
    var timerBackground: SKShapeNode!
    var timerValue: TimeInterval = 300
    var timerColor: String = "green"
    
    var timeSurvivedValue: TimeInterval = 0
    var countDownToStart: Int = 3
    var countDownToStartLabel: SKLabelNode!
    
    var timeLimitForRota: Int = 35
    var timeLimitForRotaLabel: SKLabelNode!
    var rotaUndoButton: SKSpriteNode!
    
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
            self.removeAction(forKey: "itemCleanup")
            self.summonedOtherItems = false
            if !self.isRotaActive() {
                self.spawnItem()
            }
            return
        }
        
        view.isMultipleTouchEnabled = true
        isSceneSetup = true
        pinballWorldNode.name = "headNode"
        
        addChild(pinballWorldNode)
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -10)
        backgroundColor = .clear
        
        addBackdrop()
        
        addCeiling()
        addSides(at: CGPoint(x: 42, y: 10))
        addSides(at: CGPoint(x: 359, y: 10))
        addTrianglesLeft(at: CGPoint(x: 0, y: 130))
        addTrianglesRight(at: CGPoint(x: 390, y: 130))
        
        addBall(position: CGPoint(x: 50, y: 500))
        
        addLeftFlipper()
        addRightFlipper()
        
        addWallBottomLeft()
        addWallTopLeft()
        
        addBumperLeft()
        addBumperRight()
        addBumperCenter()
        
        self.removeAction(forKey: "itemCleanup")
        self.summonedOtherItems = false
        spawnItem()
        
        timerBackground = SKShapeNode(rectOf: CGSize(width: 140, height: 60), cornerRadius: 10)
        timerBackground.name = "timeBackground"
        timerBackground.fillColor = SKColor.black.withAlphaComponent(1)
        timerBackground.strokeColor = .black
        timerBackground.zPosition = 1000
        timerBackground.position = CGPoint(x: size.width / 2, y: 850)
        pinballWorldNode.addChild(timerBackground)
        
        //countdown to start
        let tickAction = SKAction.run {
            self.countDownToStart -= 1
        }
        
        let waitAction = SKAction.wait(forDuration: 1.0)
        
        let sequence = SKAction.sequence([waitAction, tickAction])
        let repeatTemp = SKAction.repeat(sequence, count: 3)
    
        self.run(repeatTemp, withKey: "countdownLoop")
        
        addCountdown()
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
        static let itemRota: UInt32 = 0b10000000
        static let fistLauncher: UInt32 = 0b100000000
        static let fistAttackLeft: UInt32 = 0b1000000000
        static let fistAttackRight: UInt32 = 0b10000000000
        static let itemBoss: UInt32 = 0b100000000000
        static let loseBox: UInt32 = 0b1000000000000
        static let ballDup: UInt32 = 0b10000000000000
        static let itemRotaCheck: UInt32 = 0b1000000000000000
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
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
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
    
    func addCountdown(){
        countDownToStartLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        addCountdownAppearance(labelTarget : countDownToStartLabel, name: "countdown")
    }
    
    func addTimeLimitForRota(){
        timeLimitForRotaLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        addCountdownAppearance(labelTarget : timeLimitForRotaLabel, name: "timeLimitRota")
    }
    
    func addCountdownAppearance(labelTarget : SKLabelNode, name: String) {
        labelTarget.position = CGPoint(x: timerBackground.position.x, y: timerBackground.position.y - 13)
        labelTarget.fontSize = 48
        labelTarget.zPosition = 1001
        labelTarget.name = name
        if labelTarget.parent == nil { pinballWorldNode.addChild(labelTarget) }
    }
    
    func addTimeLimitForFist(){
        fistAttackTimerLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        addCountdownAppearance(labelTarget : fistAttackTimerLabel, name: "fistAttackTimeLimit")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            var handled = false
            
            // 1) Hit-test using PHYSICS bodies at the touch point
            physicsWorld.enumerateBodies(at: p) { body, stop in
                guard let node = body.node else { return }
                switch node.name {
                case "flipLeft", "flipLeftTap" where self.leftOwner == nil:
                    self.leftOwner = touch
                    self.leftTouchDown = true
                    self.flipLeft.physicsBody?.angularVelocity = 0
                    self.flipLeft.physicsBody?.applyAngularImpulse(420)
                case "flipRight", "flipRightTap" where self.rightOwner == nil:
                    self.rightOwner = touch
                    self.rightTouchDown = true
                    self.flipRight.physicsBody?.angularVelocity = 0
                    self.flipRight.physicsBody?.applyAngularImpulse(-420)
                    
                case "Pinball":
                    if self.jumpBoostAvailable {
                        self.jumpBoostAvailable = false
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
                        if sprite.action(forKey: "fistBusy") != nil {
                            handled = true; stop.pointee = true
                            break
                        }
                        sprite.run(SKAction.sequence([.wait(forDuration: 0.15)]), withKey: "fistBusy")
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
                        if sprite.action(forKey: "fistBusy") != nil {
                            handled = true; stop.pointee = true
                            break
                        }
                        sprite.run(SKAction.sequence([.wait(forDuration: 0.15)]), withKey: "fistBusy")
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
                    
                case "rotaUndoButton":
                    if let sprite = node as? SKSpriteNode {
                        self.ball.position = self.ballPastPosition
                        handled = true
                        stop.pointee = true
                        sprite.removeFromParent()
                        self.hasUndoButton = false
                        for node in self.pinballWorldNode.children {
                            if node.name == "PinballPast"{
                                node.removeFromParent()
                            }
                        }
                    }
                    
                default:
                    break
                }
            }
            
            if handled { continue }
        }
    }
    
    private func hitName(at p: CGPoint) -> String? {
        var found: String?
        physicsWorld.enumerateBodies(at: p) { body, stop in
            if let n = body.node?.name { found = n; stop.pointee = true }
        }
        return found
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        driveFlipper(flipLeft,  pressed: leftTouchDown,  pressedTarget: leftPressedAngle,  restTarget: leftRest)
        driveFlipper(flipRight, pressed: rightTouchDown, pressedTarget: rightPressedAngle, restTarget: rightRest)
        
        positionHistory.append((time: currentTime, pos: ball.position, vel: ball.physicsBody?.velocity))
        self.currentTime = currentTime
        
        while let first = positionHistory.first, currentTime - first.time > 5 {
            positionHistory.removeFirst()
        }
        
        if let past = positionHistory.first {
            ballPastPosition = past.pos
            if pastBall != nil {
                pastBall.position = ballPastPosition
            }
        }
        
        if countDownToStart == 0 && hitRotaItem == false && !hitFistItem {
            for node in self.pinballWorldNode.children {
                if node.name == "countdown" {
                    print("removed")
                    node.removeFromParent()
                }
            }
            for node in self.pinballWorldNode.children {
                if node.name == "timeLimitRota" {
                    print("removed")
                    node.removeFromParent()
                }
            }
            for node in self.pinballWorldNode.children {
                if node.name == "fistAttackTimeLimit" {
                    print("removed")
                    node.removeFromParent()
                }
            }
            timerLabel.isHidden = false
            ball.physicsBody?.isDynamic = true
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
        }
        else if countDownToStart != 0 && hitRotaItem == false && !hitFistItem {
            timerLabel.isHidden = true
            ball.physicsBody?.isDynamic = false
            if countDownToStart == 3 {
                countDownToStartLabel.fontColor = SKColor.red.withAlphaComponent(0.75)
            }
            else if countDownToStart == 2 {
                countDownToStartLabel.fontColor = SKColor.yellow.withAlphaComponent(0.75)
            }
            else if countDownToStart == 1 {
                countDownToStartLabel.fontColor = SKColor.green.withAlphaComponent(0.75)
            }
            countDownToStartLabel.text = String(countDownToStart)
        }
        else if countDownToStart == 0 && hitRotaItem == true && !hitFistItem {
            for node in self.pinballWorldNode.children {
                if node.name == "countdown" {
                    print("removed")
                    node.removeFromParent()
                }
            }
            timerLabel.isHidden = true
            if timeLimitForRota >= 30 {
                timeLimitForRotaLabel.fontColor = SKColor.green.withAlphaComponent(0.75)
            }
            else if timeLimitForRota >= 15 {
                timeLimitForRotaLabel.fontColor = SKColor.yellow.withAlphaComponent(0.75)
            }
            else if timeLimitForRota < 15 {
                timeLimitForRotaLabel.fontColor = SKColor.red.withAlphaComponent(0.75)
            }
            timeLimitForRotaLabel.text = String(timeLimitForRota)
            timeSurvivedValue += 1.0 / 60.0
            
        } else if countDownToStart == 0 && hitRotaItem == false && hitFistItem {
            timerLabel.isHidden = true
            if fistAttackTimer >= 15 {
                fistAttackTimerLabel.fontColor = SKColor.green.withAlphaComponent(0.75)
            }
            else if fistAttackTimer >= 10 {
                fistAttackTimerLabel.fontColor = SKColor.yellow.withAlphaComponent(0.75)
            }
            else if fistAttackTimer < 10 {
                fistAttackTimerLabel.fontColor = SKColor.red.withAlphaComponent(0.75)
            }
            fistAttackTimerLabel.text = String(fistAttackTimer)
            timeSurvivedValue += 1.0 / 60.0
        }
        
        if numberOfRotaChecksCollided == maxChecks {
            timeLimitForRota = 0
            endRotaPhase(didCompleteAllChecks: true)
        }
        else if hitRotaItem && timeLimitForRota == 0 {
            endRotaPhase(didCompleteAllChecks: false)
        }
        
        if ball.position.x < 0 || ball.position.x > 375 {
            for node in self.pinballWorldNode.children {
                if node.name == "Pinball" {
                    node.removeFromParent()
                }
            }
            addBall(position: CGPoint(x: 50, y: 500))
        }
        
        if activatedDupPower && activatedPunPower && activatedBossPower && activatedRotaPower {
            powerUpPublisher.send()
        }
        
        for node in self.pinballWorldNode.children {
            if node.name == "PinballDup" {
                dupBallActive = true
            }
        }
        
        guard let bodyBall = ball.physicsBody else { return }
        
        let speedBall = hypot(bodyBall.velocity.dx, bodyBall.velocity.dy)
        let maxSpeedBall: CGFloat = 1000
        
        if speedBall > maxSpeedBall {
            let scale = maxSpeedBall / speedBall
            bodyBall.velocity = CGVector(dx: bodyBall.velocity.dx * scale, dy: bodyBall.velocity.dy * scale)
        }
        
        //control speed for dup ball
        if dupBallActive == false { return }
        guard let bodyBallDup = dupBall.physicsBody else { return }
        
        if dupBall.position.x < 0 || dupBall.position.x > 375 {
            for node in self.pinballWorldNode.children {
                if node.name == "PinballDup" {
                    node.removeFromParent()
                }
            }
            addDupBall()
        }
        
        let speedDupBall = hypot(bodyBallDup.velocity.dx, bodyBallDup.velocity.dy)
        let maxSpeedDupBall: CGFloat = 800
        
        if speedDupBall > maxSpeedDupBall {
            let scale = maxSpeedDupBall / speedDupBall
            bodyBallDup.velocity = CGVector(dx: bodyBallDup.velocity.dx * scale, dy: bodyBallDup.velocity.dy * scale)
        }
        
    }
    
    private func shortestAngle(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var d = (b - a).truncatingRemainder(dividingBy: 2*CGFloat.pi)
        if d >= .pi { d -= 2*CGFloat.pi }
        if d < -.pi { d += 2*CGFloat.pi }
        return d
    }

    private func driveFlipper(_ node: SKSpriteNode?, pressed: Bool, pressedTarget: CGFloat, restTarget: CGFloat) {
        guard let body = node?.physicsBody, let node = node else { return }
        let target = pressed ? pressedTarget : restTarget

        // 🔧 Stronger gains & torque when returning to rest
        let Kp: CGFloat   = pressed ? 180 : 280
        let Kd: CGFloat   = pressed ? 20  : 35
        let maxT: CGFloat = pressed ? 900 : 1600

        let err = shortestAngle(node.zRotation, target)
        let torque = max(-maxT, min(maxT, Kp * err - Kd * body.angularVelocity))
        body.applyTorque(torque)
    }
    
    private func endRotaPhase(didCompleteAllChecks: Bool) {
        self.removeAction(forKey: "timeLimitForRotaLoop")
        for node in self.pinballWorldNode.children where node.name == "timeLimitRota" {
            node.removeFromParent()
        }
        
        if didCompleteAllChecks {
            addUndoButton()
        } else {
            for node in self.pinballWorldNode.children where node.name == "rotaItemCheck" {
                node.removeFromParent()
            }
        }
        
        hitRotaItem = false
        numberOfRotaChecksCollided = 0
        timeLimitForRota = -1
        timerLabel.isHidden = false

        self.removeAction(forKey: "itemCleanup")
        self.removeAction(forKey: "spawnDelay")
        self.summonedOtherItems = false
        self.spawnItem()
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
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0){
                    for node in self.pinballWorldNode.children {
                        if node.name == "PinballDup" {
                            self.timerValue += 60
                            node.removeFromParent()
                            self.dupBallActive = false
                            self.dupPublisher.send(false)
                        }
                    }
                }
                self.removeAction(forKey: "itemCleanup")
                self.summonedOtherItems = false
                self.spawnItem()
            }
        }
        else if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.itemPun {
            activatedPunPower = true
            hitFistItem = true
            DispatchQueue.main.async {
                otherNode.removeFromParent()
                if let jp = self.leftPin  { self.physicsWorld.remove(jp); self.leftPin  = nil }
                if let jp = self.rightPin { self.physicsWorld.remove(jp); self.rightPin = nil }

                self.leftPivot?.removeFromParent()
                self.leftPivot  = nil
                self.rightPivot?.removeFromParent()
                self.rightPivot = nil
                
                for node in self.pinballWorldNode.children where node.physicsBody?.categoryBitMask == PhysicsCategory.flipper {
                    node.removeAllChildren()
                    node.removeFromParent()
                }
                
                for node in self.pinballWorldNode.children {
                    if node.physicsBody?.categoryBitMask == PhysicsCategory.flipper {
                        node.removeFromParent()
                    }
                }
                
                self.addTimeLimitForFist()
                let tickAction = SKAction.run {
                    self.fistAttackTimer -= 1
                }
                
                let waitAction = SKAction.wait(forDuration: 1.0)
                
                let sequence = SKAction.sequence([waitAction, tickAction])
                let repeatTemp = SKAction.repeat(sequence, count: 20)
                
                self.run(repeatTemp, withKey: "timeLimitForPun")
                
                self.addFistsLeft()
                self.addFistsRight()
                DispatchQueue.main.asyncAfter(deadline: .now() + 20.0){
                    for node in self.pinballWorldNode.children {
                        if node.name == "fistLeft" || node.name == "fistRight"{
                            node.removeFromParent()
                        }
                    }
                    self.activatedPunItem = false
                    self.addLeftFlipper()
                    self.addRightFlipper()
                    self.hitFistItem = false
                    self.fistAttackTimer = 20
                    self.removeAction(forKey: "itemCleanup")
                }
                
                self.summonedOtherItems = false
                if !self.isRotaActive() {
                    self.spawnItem()
                }
            }
        }
        else if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.itemRota {
            DispatchQueue.main.async {
                self.activatedRotaPower = true
                self.timeLimitForRota = 35
                self.hitRotaItem = true
                
                self.removeAction(forKey: "itemCleanup")

                for node in self.pinballWorldNode.children {
                    if node.name == "bossItem" || node.name == "punItem" || node.name == "dupItem" || node.name == "rotaItem" {
                        node.removeFromParent()
                    }
                }
                self.summonedOtherItems = false
                
                otherNode.removeFromParent()
                let referenceForLimit = self.timeLimitForRota
                for _ in 1...self.maxChecks {
                    self.addItemRotaChecks()
                }
                self.addTimeLimitForRota()
                let tickAction = SKAction.run {
                    self.timeLimitForRota -= 1
                }
                
                let waitAction = SKAction.wait(forDuration: 1.0)
                
                let sequence = SKAction.sequence([waitAction, tickAction])
                let repeatTemp = SKAction.repeat(sequence, count: referenceForLimit)
                
                self.run(repeatTemp, withKey: "timeLimitForRotaLoop")
            }
        }
        else if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.itemBoss {
            activatedBossPower = true
            DispatchQueue.main.async {
                self.bossPublisher.send()
                otherNode.removeFromParent()
                
                self.summonedOtherItems = false
                self.spawnItem()
            }
        }
        else if otherNode.physicsBody?.categoryBitMask == PhysicsCategory.itemRotaCheck{
            DispatchQueue.main.async {
                self.numberOfRotaChecksCollided += 1
                otherNode.removeFromParent()
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
        ball.physicsBody?.allowsRotation = true
        ball.physicsBody?.linearDamping = 0.2
        ball.physicsBody?.angularDamping = 0.5
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.usesPreciseCollisionDetection = true
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.physicsBody?.collisionBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.ballDup | PhysicsCategory.ball | PhysicsCategory.itemRota | PhysicsCategory.itemRotaCheck
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.itemDupli | PhysicsCategory.itemPun | PhysicsCategory.ball | PhysicsCategory.itemRota | PhysicsCategory.fistAttackLeft | PhysicsCategory.fistLauncher | PhysicsCategory.fistAttackRight | PhysicsCategory.itemBoss | PhysicsCategory.loseBox | PhysicsCategory.itemRotaCheck
        
        pinballWorldNode.addChild(ball)
    }
    
    func addPastBall(){
        pastBall = SKSpriteNode(imageNamed: ballSkin)
        pastBall.name = "PinballPast"
        pastBall.size = CGSize(width: 55, height: 55)
        pastBall.alpha = 0.4
        pastBall.position = ballPastPosition
        
        pastBall.physicsBody = nil
        pinballWorldNode.addChild(pastBall)
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
        dupBall.physicsBody?.contactTestBitMask = PhysicsCategory.triangleWall | PhysicsCategory.flipper | PhysicsCategory.bumper | PhysicsCategory.rectangleWall | PhysicsCategory.itemDupli | PhysicsCategory.itemPun | PhysicsCategory.ball | PhysicsCategory.itemRota | PhysicsCategory.fistAttackLeft | PhysicsCategory.fistLauncher | PhysicsCategory.fistAttackRight | PhysicsCategory.itemBoss | PhysicsCategory.loseBox
        
        pinballWorldNode.addChild(dupBall)
    }
    
    func addCeiling(){
        let size = CGSize(width: 600, height: 10)
        let ceiling = SKSpriteNode(color: .clear, size: size)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        ceiling.physicsBody = body
        ceiling.position = CGPoint(x: 300, y: 830)
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
    
    private func makeFlipperBody(isLeft: Bool, size: CGSize) -> SKPhysicsBody {
        let W = size.width
        let H = size.height
        let s: CGFloat = isLeft ? 1 : -1
        

        let blade = SKPhysicsBody(
            rectangleOf: CGSize(width: W * 0.56, height: H * 0.16),
            center: CGPoint(x: s * W * 0.26, y: 0)
        )
        
        let tip = SKPhysicsBody(
            circleOfRadius: W * 0.09,
            center: CGPoint(x: s * W * 0.52, y: 0)
        )

        let root = SKPhysicsBody(
            circleOfRadius: W * 0.11,
            center: CGPoint(x: s * W * 0.04, y: 0)
        )

        let body = SKPhysicsBody(bodies: [blade, tip, root])
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.friction = 0.2
        body.restitution = 0.0
        body.angularDamping = 0.05
        body.density = 150
        body.categoryBitMask = PhysicsCategory.flipper
        body.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        body.contactTestBitMask = PhysicsCategory.none
        return body
    }
    
    private func makePivot(at localPos: CGPoint) -> SKNode {
        let pivot = SKNode()
        pivot.position = localPos
        pivot.physicsBody = SKPhysicsBody(circleOfRadius: 1)
        pivot.physicsBody?.isDynamic = false
        pinballWorldNode.addChild(pivot)
        return pivot
    }

    private func sceneAnchor(for localPos: CGPoint) -> CGPoint {
        return self.convert(localPos, from: pinballWorldNode)
    }
    
    func addLeftFlipper() {
        let rest: CGFloat = -.pi/3
        
        flipLeft = SKSpriteNode(imageNamed: "LeftFlipper")
        flipLeft.size = CGSize(width: 180, height: 180)
        flipLeft.anchorPoint = CGPoint(x: 0.18, y: 0.20)
        flipLeft.position = CGPoint(x: 66, y: 110)
        flipLeft.name = "flipLeft"
        
        flipLeft.zRotation = rest
        flipLeft.physicsBody = makeFlipperBody(isLeft: true, size: flipLeft.size)
        pinballWorldNode.addChild(flipLeft)
        
        let leftLocalPos = flipLeft.position
        leftPivot = makePivot(at: leftLocalPos)
        let leftAnchor = sceneAnchor(for: leftLocalPos)

        let leftPin = SKPhysicsJointPin.joint(withBodyA: leftPivot!.physicsBody!,
                                              bodyB: flipLeft.physicsBody!,
                                              anchor: leftAnchor)
        leftPin.shouldEnableLimits = true
        leftPin.lowerAngleLimit = 0
        leftPin.upperAngleLimit = (.pi/3 - (-.pi/3))
        leftPin.frictionTorque = 1.0
        physicsWorld.add(leftPin)
        self.leftPin = leftPin
        
        let tapProxy = SKSpriteNode(texture: flipLeft!.texture)
        tapProxy.name = "flipLeftTap"
        tapProxy.size = CGSize(width: 200, height: 180)
        tapProxy.anchorPoint = flipLeft.anchorPoint
        tapProxy.position = .zero
        tapProxy.zPosition = -1
        tapProxy.alpha = 0.001
        
        tapProxy.physicsBody = SKPhysicsBody(rectangleOf: tapProxy.size)
        tapProxy.physicsBody?.isDynamic = false
        tapProxy.physicsBody?.affectedByGravity = false
        tapProxy.physicsBody?.categoryBitMask = 0
        tapProxy.physicsBody?.collisionBitMask = 0
        tapProxy.physicsBody?.contactTestBitMask = 0
        
        flipLeft.addChild(tapProxy)
    }

    func applyLeftFlipperImpulse() {
        guard let b = flipLeft.physicsBody else { return }
        b.angularVelocity = 0
        b.applyAngularImpulse(230)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if t == leftOwner {
                leftOwner = nil
                leftTouchDown = false
                flipLeft.physicsBody?.angularVelocity = min(flipLeft.physicsBody?.angularVelocity ?? 0, 0)
                flipLeft.physicsBody?.applyAngularImpulse(-220)   // left goes back negative
            }
            if t == rightOwner {
                rightOwner = nil
                rightTouchDown = false
                flipRight.physicsBody?.angularVelocity = max(flipRight.physicsBody?.angularVelocity ?? 0, 0)
                flipRight.physicsBody?.applyAngularImpulse(220)   // right goes back positive
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    func addRightFlipper() {
        let rest: CGFloat = .pi/3
        
        flipRight = SKSpriteNode(imageNamed: "RightFlipper")
        flipRight.size = CGSize(width: 180, height: 180)
        flipRight.anchorPoint = CGPoint(x: 0.82, y: 0.20)
        flipRight.position = CGPoint(x: 324, y: 110)
        flipRight.name = "flipRight"
        

        flipRight.zRotation = rest
        flipRight.physicsBody = makeFlipperBody(isLeft: false, size: flipRight.size)
        pinballWorldNode.addChild(flipRight)
        
        let rightLocalPos = flipRight.position
        rightPivot = makePivot(at: rightLocalPos)
        let rightAnchor = sceneAnchor(for: rightLocalPos)

        let rightPin = SKPhysicsJointPin.joint(withBodyA: rightPivot!.physicsBody!,
                                               bodyB: flipRight.physicsBody!,
                                               anchor: rightAnchor)
        rightPin.shouldEnableLimits = true
        rightPin.lowerAngleLimit = (-.pi/3 - .pi/3)
        rightPin.upperAngleLimit = 0
        rightPin.frictionTorque = 1.0
        physicsWorld.add(rightPin)
        self.rightPin = rightPin
        
        let tapProxy = SKSpriteNode(texture: flipRight!.texture)
        tapProxy.name = "flipRightTap"
        tapProxy.size = CGSize(width: 200, height: 180)
        tapProxy.anchorPoint = flipRight.anchorPoint
        tapProxy.position = .zero
        tapProxy.zPosition = -1
        tapProxy.alpha = 0.001
        
        tapProxy.physicsBody = SKPhysicsBody(rectangleOf: tapProxy.size)
        tapProxy.physicsBody?.isDynamic = false
        tapProxy.physicsBody?.affectedByGravity = false
        tapProxy.physicsBody?.categoryBitMask = 0
        tapProxy.physicsBody?.collisionBitMask = 0
        tapProxy.physicsBody?.contactTestBitMask = 0
        
        flipRight.addChild(tapProxy)
    }
    
    func applyRightFlipperImpulse() {
        guard let b = flipRight.physicsBody else { return }
        b.angularVelocity = 0
        b.applyAngularImpulse(-230)
    }
    
    func addFistsLeft(){
        fistLeft = SKSpriteNode(imageNamed: "PistonUncompressed")
        fistLeft.size = CGSize(width: 350, height: 350)
        fistLeft.position = CGPoint(x: 35, y: 75)
        fistLeft.name = "fistLeft"
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 300, height: 300))
        fistLeft.physicsBody = body
        fistLeft.physicsBody?.isDynamic = false
        
        fistLeft.physicsBody?.categoryBitMask = PhysicsCategory.fistLauncher
        fistLeft.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        fistLeft.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(fistLeft)
    }
    
    func addFistsRight(){
        fistRight = SKSpriteNode(imageNamed: "PistonUncompressed")
        fistRight.size = CGSize(width: 350, height: 350)
        fistRight.position = CGPoint(x: 355, y: 75)
        fistRight.name = "fistRight"
        fistRight.xScale = -1.0
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 300, height: 300))
        fistRight.physicsBody = body
        fistRight.physicsBody?.isDynamic = false
        
        fistRight.physicsBody?.categoryBitMask = PhysicsCategory.fistLauncher
        fistRight.physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.ballDup
        fistRight.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(fistRight)
    }
    
    func addFistProjectile(isRight: Bool){
        fistAttack = SKSpriteNode(imageNamed: "PistonProjectile")
        fistAttack.size = CGSize(width: 300, height: 300)
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
        trianglePath.move(to: CGPoint(x: 0, y: 0))
        trianglePath.addLine(to: CGPoint(x: 0, y: 90))
        trianglePath.addLine(to: CGPoint(x: 86, y: 0))
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
    
    func addTrianglesLeftInverse(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: 0))
        trianglePath.addLine(to: CGPoint(x: 0, y: 82))
        trianglePath.addLine(to: CGPoint(x: 80, y: 0))
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
        trianglePath.move(to: CGPoint(x: 0, y: 0))
        trianglePath.addLine(to: CGPoint(x: 0, y: 90))
        trianglePath.addLine(to: CGPoint(x: -86, y: 0))
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
    
    func addTrianglesRightInverse(at position: CGPoint){
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 0, y: 0))
        trianglePath.addLine(to: CGPoint(x: 0, y: 82))
        trianglePath.addLine(to: CGPoint(x: -80, y: 0))
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
        bumperLeft.position = CGPoint(x: 35, y: 790)
        
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: -39, y: 34))
        trianglePath.addLine(to: CGPoint(x: -39, y: -42))
        trianglePath.addLine(to: CGPoint(x: 35, y: 34))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
        triangleWall.position = bumperLeft.position
        triangleWall.zPosition = 99999
        
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
        bumperRight.position = CGPoint(x: 355, y: 790)
        bumperRight.name = "bumperRight"
        
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: 35, y: 35))
        trianglePath.addLine(to: CGPoint(x: 35, y: -42))
        trianglePath.addLine(to: CGPoint(x: -31, y: 35))
        trianglePath.closeSubpath()
        
        let triangleWall = SKShapeNode(path: trianglePath)
        triangleWall.strokeColor = .clear
        triangleWall.fillColor = .clear
        triangleWall.position = bumperRight.position
        triangleWall.zPosition = 99999
        
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
        bumperCenter.position = CGPoint(x: 195, y: 510)
        
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
        wall.position =  CGPoint(x: wall.size.width / 2, y: 610)
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
        wall.position = CGPoint(x: wall.size.width / 2, y: 410)
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
        print("added dup")
        let delay = 10 * Double.random(in: 1...3)
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
                    } while position.distance(to: self.ball.position) < 100
                    dupItem.position = position
                    dupItem.physicsBody = SKPhysicsBody(rectangleOf: dupItem.size)
                    dupItem.physicsBody!.isDynamic = false
                    dupItem.physicsBody?.affectedByGravity = false
                    
                    dupItem.physicsBody?.categoryBitMask = PhysicsCategory.itemDupli
                    dupItem.physicsBody?.collisionBitMask = PhysicsCategory.ball
                    dupItem.physicsBody?.contactTestBitMask = PhysicsCategory.none
                    
                    if(!self.summonedOtherItems){
                        self.summonedOtherItems = true
                        dupItem.spinForever()
                        self.pinballWorldNode.addChild(dupItem)
                        self.scheduleItemCleanup(after: 5.0)
                    }
                }
            ]))
        }
    }
    
    func addItemPun(){
        print("added pun")
        let delay = 10 * Double.random(in: 1...3)
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
                    } while position.distance(to: self.ball.position) < 100
                    
                    punItem.position = position
                    
                    punItem.physicsBody = SKPhysicsBody(rectangleOf: punItem.size)
                    punItem.physicsBody!.isDynamic = false
                    punItem.physicsBody?.affectedByGravity = false
                    
                    punItem.physicsBody?.categoryBitMask = PhysicsCategory.itemPun
                    punItem.physicsBody?.collisionBitMask = PhysicsCategory.ball
                    punItem.physicsBody?.contactTestBitMask = PhysicsCategory.none
                    
                    if(!self.summonedOtherItems){
                        self.summonedOtherItems = true
                        self.activatedPunItem = true
                        punItem.spinForever()
                        self.pinballWorldNode.addChild(punItem)
                        self.scheduleItemCleanup(after: 5.0)
                    }
                }
            ]))
        }
    }
    
    func addItemRota(){
        print("added rota")
        let delay = 10 * Double.random(in: 1...3)
        if(!summonedOtherItems){
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    let rotaItem = SKSpriteNode(imageNamed: "Rota_Item")
                    rotaItem.name = "rotaItem"
                    rotaItem.size = CGSize(width: 100, height: 100)
                    var position: CGPoint
                    repeat {
                        let randomX: CGFloat = CGFloat.random(in: 0...190)
                        let randomY: CGFloat = CGFloat.random(in: 220...422)
                        position = CGPoint(x: randomX, y: randomY)
                    } while position.distance(to: self.ball.position) < 100
                    rotaItem.position = position
                    rotaItem.physicsBody = SKPhysicsBody(rectangleOf: rotaItem.size)
                    rotaItem.physicsBody!.isDynamic = false
                    rotaItem.physicsBody?.affectedByGravity = false
                    
                    rotaItem.physicsBody?.categoryBitMask = PhysicsCategory.itemRota
                    rotaItem.physicsBody?.collisionBitMask = PhysicsCategory.ball
                    rotaItem.physicsBody?.contactTestBitMask = PhysicsCategory.none
                    
                    if(!self.summonedOtherItems){
                        self.summonedOtherItems = true
                        rotaItem.spinForever()
                        self.pinballWorldNode.addChild(rotaItem)
                        self.scheduleItemCleanup(after: 5.0)
                    }
                }
            ]))
        }
    }
    
    func addItemRotaChecks(){
        rotaItemCheck = SKSpriteNode(imageNamed: "RotaButtonCheck")
        rotaItemCheck.name = "rotaItemCheck"
        rotaItemCheck.size = CGSize(width: 150, height: 150)
        var achievedMinDistanceFromEachOther: Bool = true
        var position: CGPoint
        var attempts = 0
        repeat {
            attempts += 1
            achievedMinDistanceFromEachOther = true
            let randomX: CGFloat = CGFloat.random(in: 0...280)
            let randomY: CGFloat = CGFloat.random(in: 220...780)
            position = CGPoint(x: randomX, y: randomY)
            for node in self.pinballWorldNode.children {
                if node.name == "rotaItemCheck" {
                    if position.distance(to: node.position) < 150 {
                        achievedMinDistanceFromEachOther = false
                        break;
                    }
                }
            }
        } while (position.distance(to: self.ball.position) < 200 || !achievedMinDistanceFromEachOther) && attempts < 40
        rotaItemCheck.position = position
        rotaItemCheck.physicsBody = SKPhysicsBody(circleOfRadius: 25)
        rotaItemCheck.physicsBody!.isDynamic = false
        rotaItemCheck.physicsBody?.affectedByGravity = false
        
        rotaItemCheck.physicsBody?.categoryBitMask = PhysicsCategory.itemRotaCheck
        rotaItemCheck.physicsBody?.collisionBitMask = PhysicsCategory.ball
        rotaItemCheck.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        pinballWorldNode.addChild(rotaItemCheck)
    }
    
    func addUndoButton(){
        rotaUndoButton = SKSpriteNode(imageNamed: "RotaButton")
        rotaUndoButton.name = "rotaUndoButton"
        rotaUndoButton.size = CGSize(width: 120, height: 120)
        rotaUndoButton.position = CGPoint(x: 80, y: 890)
        let body = SKPhysicsBody(rectangleOf: rotaUndoButton.size)
        rotaUndoButton.physicsBody = body
        rotaUndoButton.physicsBody?.isDynamic = false
        rotaUndoButton.physicsBody?.affectedByGravity = false
        hasUndoButton = true
        pinballWorldNode.addChild(rotaUndoButton)
        addPastBall()
    }
    
    func addBossItem(){
        print("added boss")
        let delay = 10 * Double.random(in: 1...3)
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
                    } while position.distance(to: self.ball.position) < 100
                    bossItem.position = position
                    bossItem.physicsBody = SKPhysicsBody(rectangleOf: bossItem.size)
                    bossItem.physicsBody!.isDynamic = false
                    bossItem.physicsBody?.affectedByGravity = false
                    
                    bossItem.physicsBody?.categoryBitMask = PhysicsCategory.itemBoss
                    bossItem.physicsBody?.collisionBitMask = PhysicsCategory.ball
                    bossItem.physicsBody?.contactTestBitMask = PhysicsCategory.none
                    
                    if(!self.summonedOtherItems){
                        self.summonedOtherItems = true
                        bossItem.spinForever()
                        self.pinballWorldNode.addChild(bossItem)
                        self.scheduleItemCleanup(after: 5.0)
                    }
                }
            ]))
        }
    }
    
    func spawnItem() {
        guard !isRotaActive() else { return }
        let random = Int.random(in: 0...3)
        if random == 0 {
            if !hitFistItem {
                self.addItemPun()
            }
            else {
                if !self.dupBallActive {
                    self.addItemDup()
                }
                else {
                    self.addBossItem()
                }
            }
        } else if random == 1 {
            if !self.dupBallActive {
                self.addItemDup()
            }
            else {
                let split = Int.random(in: 0...2)
                if split == 0 {
                    if !hitFistItem {
                        self.addItemPun()
                    }
                    else {
                        if !self.dupBallActive {
                            self.addItemDup()
                        }
                        else {
                            self.addBossItem()
                        }
                    }
                }
                else if split == 1 {
                    self.addItemRota()
                }
                else {
                    self.addBossItem()
                }
            }
        } else if random == 2 {
            if !hasUndoButton && !hitFistItem{
                self.addItemRota()
            }
            else {
                if !hitFistItem {
                    self.addItemPun()
                }
                else {
                    if !self.dupBallActive {
                        self.addItemDup()
                    }
                    else {
                        if !hasUndoButton {
                            self.addItemRota()
                        }
                        else {
                            self.addBossItem()
                        }
                    }
                }
            }
        }
        else {
            self.addBossItem()
        }
    }
    
    func scheduleItemCleanup(after seconds: TimeInterval = 5.0) {
        self.removeAction(forKey: "itemCleanup")

        let wait = SKAction.wait(forDuration: seconds)
        let cleanup = SKAction.run { [weak self] in
            guard let self = self, self.summonedOtherItems else { return }
            for node in self.pinballWorldNode.children {
                if node.name == "bossItem" || node.name == "rotaItem" || node.name == "punItem" || node.name == "dupItem" {
                    node.removeFromParent()
                }
            }
            self.summonedOtherItems = false
            if !self.isRotaActive() {
                self.spawnItem()
            }
        }

        self.run(SKAction.sequence([wait, cleanup]), withKey: "itemCleanup")
    }
    
    private func isRotaActive() -> Bool {
        return hitRotaItem && timeLimitForRota > 0 && numberOfRotaChecksCollided < maxChecks
    }
}
