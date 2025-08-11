//
//  ContentView.swift
//  PinballTrue
//
//  Created by Muhammad Mahmood on 6/23/25.
//

import SwiftUI
import SpriteKit
import Combine


func makeStartupScene() -> StartupScene {
    let scene = StartupScene(size: CGSize(width: 390, height: 944))
    scene.scaleMode = .aspectFit
    return scene
}

func makeSkinsScene() -> SkinsScene {
    let scene = SkinsScene(size: CGSize(width: 390, height: 944))
    scene.scaleMode = .aspectFit
    return scene
}

func makeAchievementsScene() -> AchievementScene {
    let scene = AchievementScene(size: CGSize(width: 390, height: 944))
    scene.scaleMode = .aspectFit
    return scene
}
struct ContentView: View {
    private let baseSize = CGSize(width: 390, height: 844)
    
    @State private var pinballSceneID = UUID()
    @State private var startupSceneID = UUID()
    @State private var settingSceneID = UUID()
    @State private var bossSceneID = UUID()
    @State private var achievementSceneID = UUID()
    @State private var skinsSceneID = UUID()
    
    @State private var isFlippedItemInEffect = false
    @State private var isDupBallThere = false
    
    @State private var screenDirection: String = "startup"
    @State private var isSetting: Bool = false;
    @State private var playerLost: Bool = false;
    
    @State private var ballDesign: String = "Pinball"
    @State private var currentBallSkinIndex: Int = 0
    
    let timer = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()
    
    @State private var pinballScene: PinballScene? = PinballScene(size: CGSize(width: 390, height: 944))
    @State private var startupScene: StartupScene? = makeStartupScene()
    
    @State private var bossScene: BossScene? = nil
    @State private var achievementScene: AchievementScene? = makeAchievementsScene()
    @State private var skinsScene: SkinsScene? = makeSkinsScene()
    
    @State private var firstAchievementAchieved: Bool = false
    @State private var secondAchievementAchieved: Bool = false
    @State private var thirdAchievementAchieved: Bool = false
    @State private var fourthAchievementAchieved: Bool = false
    @State private var fifthAchievementAchieved: Bool = false
    @State private var numberOfAchievementsAchieved: Int = 0
    
    @State private var playTime: TimeInterval = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var playTimerLabel: String = "00:00"
    @State private var ballCancellable: AnyCancellable?
    @State private var bossFightCount: Int = 0
    
    
    var body: some View {
        let star = Image("Star")
            .resizable()
            .frame(width: 100, height: 100)
        
        let settings = Image("SettingsPage")
            .resizable()
        
        let exit = Image("Exit_button")
            .resizable()
            .frame(width: 172, height: 169)
        
        let skinBox = Image("BallSelectionFrame")
            .resizable()
            .frame(width: 200, height: 200)
        
        let settingsButton = Image("Settings_Button")
            .resizable()
            .frame(width: 65, height: 65)
        
        let background = Image("BossStage")
            .resizable()
            .scaledToFill()
        
        GeometryReader { geo in
            ZStack{
                background
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()

                // Compute a uniform scale to preserve aspect ratio
                let scale = min(
                    geo.size.width  / baseSize.width,
                    geo.size.height / baseSize.height
                )
                ZStack {
                    if screenDirection == "startup"{
                        if let scene = startupScene {
                            ZStack {
                                GeometryReader { geometry in
                                    startupScreenView(geometry: geometry, scene: scene, star: star, settings: settings, background: background, exit: exit)
                                }
                            }
                        }
                    }
                    else if screenDirection == "pinball"{
                        if let scene = pinballScene {
                            GeometryReader { geometry in
                                pinballScreenView(geometry: geometry, scene: scene, settings: settings, background: background, exit: exit, settingsButton: settingsButton)
                            }
                        }
                        if isSetting {
                            ZStack{
                                VStack{
                                    settings
                                }
                                Button {
                                    isSetting = false
                                    pinballScene?.isPaused = false
                                } label: {
                                    exit
                                }
                                .position(x: 200, y: 740)
                            }
                        }
                        if playerLost {
                            gameOverScreenView(exit: exit)
                        }
                    }
                    else if screenDirection == "boss", let scene = bossScene {
                        ZStack{
                            GeometryReader { geometry in
                                BossScreenView(geometry: geometry, scene: scene, settings: settings, background: background, exit: exit, settingsButton: settingsButton)
                                if isSetting {
                                    GeometryReader { geo in
                                        ZStack{
                                            VStack{
                                                settings
                                                    .frame(width: geo.size.width, height: geo.size.height)
                                            }
                                            Button {
                                                isSetting = false
                                                pinballScene?.isPaused = false
                                            } label: {
                                                exit
                                            }
                                            .position(x: 200, y: 740)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else if screenDirection == "achievement", let scene = achievementScene {
                        GeometryReader { geometry in
                            AchievementScreenView(geometry: geometry, scene: scene, settings: settings, background: background, exit: exit, settingsButton: settingsButton)
                            
                        }
                    }
                    else if screenDirection == "skins", let scene = skinsScene {
                        GeometryReader { geometry in
                            SpriteView(scene: scene)
                                .id(achievementSceneID)
                                .ignoresSafeArea()
                            Button {
                                ballDesign = "Pinball"
                            } label: {
                                skinBox
                                    .overlay(
                                        Image("Pinball")
                                            .resizable()
                                            .frame(width: 150, height: 150)
                                            .offset(x: -8, y: -12)
                                    )
                            }
                            .position(x: 115, y: 245)
                            
                            Button {
                                ballDesign = "PinballNuclear"
                            } label: {
                                skinBox
                                    .overlay(
                                        Image("PinballNuclear")
                                            .resizable()
                                            .frame(width: 150, height: 150)
                                            .offset(x: -12, y: -5)
                                    )
                            }
                            .position(x: 295, y: 245)
                            
                            if numberOfAchievementsAchieved >= 3 {
                                Button {
                                    ballDesign = "PinballSharkSkin"
                                } label: {
                                    skinBox
                                        .overlay(
                                            Image("PinballSharkSkin")
                                                .resizable()
                                                .frame(width: 150, height: 150)
                                                .offset(x: -12, y: -12)
                                        )
                                }
                                .position(x: 115, y: 420)
                            }
                            else {
                                skinBox
                                    .overlay(
                                        Image("NotAchievedGraphic")
                                            .resizable()
                                            .frame(width: 180, height: 180)
                                            .offset(x: -6, y: 4)
                                    )
                                    .position(x: 115, y: 420)
                            }
                            
                            if numberOfAchievementsAchieved >= 5 {
                                Button {
                                    ballDesign = "SpecialPinball"
                                } label: {
                                    skinBox
                                        .overlay(
                                            Image("SpecialPinball")
                                                .resizable()
                                                .frame(width: 150, height: 150)
                                                .offset(x: -12, y: -6)
                                        )
                                }
                                .position(x: 295, y: 420)
                            }
                            else {
                                skinBox
                                    .overlay(
                                        Image("NotAchievedGraphic")
                                            .resizable()
                                            .frame(width: 180, height:  180)
                                            .offset(x: -6, y: 4)
                                    )
                                    .position(x: 295, y: 420)
                            }
                            HStack{
                                Image("Selected_Skin_Text")
                                    .resizable()
                                    .frame(width: 300, height: 300)
                                Image(ballDesign)
                                    .resizable()
                                    .frame(width: 150, height: 150)
                                    .offset(x: -20)
                            }
                            .position(x: 190, y: 590)
                        }
                        Button {
                            startupScene?.isPaused = false
                            screenDirection = "startup"
                        } label: {
                            exit
                        }
                        .position(x: 195, y: 725)
                    }
                }
                .frame(width: baseSize.width, height: baseSize.height)
                .scaleEffect(scale)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
    
    @ViewBuilder
    func gameOverScreenView(exit: some View) -> some View {
        GeometryReader { geo in
            ZStack {
                VStack{
                    ZStack{
                        Image("GameOverScene")
                            .resizable()
                            .frame(width: 390, height: 1000)
                            .offset(y: -68)
                            .onAppear {
                                playTime += pinballScene!.timeSurvivedValue
                                minutes = Int(playTime) / 30
                                seconds = Int(playTime) % 30
                                if !thirdAchievementAchieved {
                                    thirdAchievementAchieved = playTime >= 180
                                    if thirdAchievementAchieved {
                                        numberOfAchievementsAchieved += 1
                                    }
                                }
                                print(playTime)
                                if !fourthAchievementAchieved {
                                    fourthAchievementAchieved = playTime >= 360
                                    if fourthAchievementAchieved {
                                        numberOfAchievementsAchieved += 1
                                    }
                                }
                                playTimerLabel = String(format: "%02d:%02d", minutes, seconds)
                            }
                        VStack{
                            Text("Time Survived: " + "\n" +  "\t\t  " + playTimerLabel)
                                .font(.system(size: 34 * geo.size.width / 390))
                                .foregroundColor(.red)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black)
                                )
                                .offset(y: 210)
                        }
                    }
                    
                }
                HStack{
                    Button {
                        startGame()
                    } label: {
                        Image("Replay_Button")
                            .resizable()
                            .frame(width: 170, height: 170)
                    }
                    Button {
                        playerLost = false
                        startupScene?.isPaused = false
                        screenDirection = "startup"
                    } label: {
                        exit
                            .offset(x: 5)
                    }
                }
                .position(x: 195, y: 810)
            }
        }
    }
    
    @ViewBuilder
    func startupScreenView(geometry: GeometryProxy, scene: StartupScene, star: some View, settings: some View, background: some View, exit: some View) -> some View {
        ZStack {
            SpriteView(scene: scene)
                .id(startupSceneID)
                .ignoresSafeArea()
            if firstAchievementAchieved {
                star.position(x: 98, y: 235)
            }
            if secondAchievementAchieved {
                star.position(x: 278, y: 235)
            }
            if thirdAchievementAchieved {
                star.position(x: 325, y: 340)
            }
            if fourthAchievementAchieved {
                star.position(x: 193, y: 340)
            }
            if fifthAchievementAchieved {
                star.position(x: 58, y: 340)
            }
            
            Button {
                startGame()
            } label: {
                Image("Start_Button")
                    .resizable()
                    .frame(width: 156, height: 156)
            }
            .position(x: 195, y: 770)
            
            Button {
                isSetting = true
                
            } label: {
                Image("Settings_Button")
                    .resizable()
                    .frame(width: 156, height: 156)
            }
            .position(x: 195, y: 580)
            
            Button {
                startupScene?.isPaused = true
                skinsSceneID = UUID()
                screenDirection = "skins"
            } label: {
                Image("Skins_Button")
                    .resizable()
                    .frame(width: 98, height: 98)
            }
            .position(x: 52, y: 700)
            
            Button {
                startupScene?.isPaused = true
                achievementSceneID = UUID()
                screenDirection = "achievement"
            } label: {
                Image("Achievements_Button")
                    .resizable()
                    .frame(width: 120, height: 120)
            }
            .position(x: 330, y: 650)
            if isSetting {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        if isSetting {
            ZStack{
                VStack{
                    settings
                }
                Button {
                    isSetting = false
                } label: {
                    exit
                }
                .position(x: 195, y: 800)
            }
        }
    }
    
    @ViewBuilder
    func pinballScreenView(geometry: GeometryProxy, scene: PinballScene, settings: some View, background: some View, exit: some View, settingsButton: some View) -> some View {
        ZStack {
            SpriteView(scene: scene)
                .id(pinballSceneID)
                .ignoresSafeArea()
                .onReceive(scene.dupPublisher) { value in
                    isDupBallThere = value
                }
                .onReceive(scene.flipPublisher) {
                    isFlippedItemInEffect.toggle()
                }
                .onReceive(scene.bossPublisher) {
                    pinballScene?.isPaused = true
                    let newBossScene = BossScene(size: CGSize(width: 390, height: 844), ballSkin: ballDesign, dupBallThere: isDupBallThere)
                    bossScene = newBossScene
                    bossSceneID = UUID()
                    screenDirection = "boss"
                }
                .onReceive(scene.losePublisher) {
                    pinballScene?.isPaused = true
                    playerLost = true
                }
                .onReceive(scene.powerUpPublisher) {
                    if !firstAchievementAchieved {
                        firstAchievementAchieved = true
                        numberOfAchievementsAchieved += 1
                    }
                }
            Button {
                //transport to setting scene
                pinballScene?.isPaused = true
                isSetting = true
                
            } label: {
                settingsButton
            }
            .position(x: 320, y: isFlippedItemInEffect ? 785 : 20)
            if isSetting {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
            }
            if playerLost {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
    
    @ViewBuilder
    func BossScreenView(geometry: GeometryProxy, scene: BossScene, settings: some View, background: some View, exit: some View, settingsButton: some View) -> some View {
        SpriteView(scene: scene)
            .id(bossSceneID)
            .ignoresSafeArea()
            .onReceive(scene.victoryPublisher){
                bossFightCount += 1
                if !secondAchievementAchieved{
                    secondAchievementAchieved = bossFightCount >= 5
                    if secondAchievementAchieved {
                        numberOfAchievementsAchieved += 1
                    }
                }
                isDupBallThere = scene.dupBallThere
                print(isDupBallThere)
                resumePinballScene(playerWon: true, scene: scene)
            }
            .onReceive(scene.losePublisher) {
                isDupBallThere = scene.dupBallThere
                print(isDupBallThere)
                resumePinballScene(playerWon: false, scene: scene)
            }
            .onReceive(scene.neverRecievedDamagePublisher) {
                if !fifthAchievementAchieved {
                    fifthAchievementAchieved = true
                    numberOfAchievementsAchieved += 1
                }
            }
        //Button {
            //transport to setting scene
            //bossScene?.isPaused = true
            //isSetting = true
            
        //} label: {
          //  settingsButton
        //}
        //.position(x: 293, y: 0)
        if isSetting {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(1)
        }
    }
    
    @ViewBuilder
    func AchievementScreenView(geometry: GeometryProxy, scene: AchievementScene, settings: some View, background: some View, exit: some View, settingsButton: some View) -> some View {
        ZStack {
            SpriteView(scene: scene)
                .id(achievementSceneID)
                .ignoresSafeArea()
            let unachievedAchievements: [(String, String)] = [
                (!firstAchievementAchieved, "AchievementOne"),
                (!secondAchievementAchieved, "AchievementTwo"),
                (!thirdAchievementAchieved, "AchievementThree"),
                (!fourthAchievementAchieved, "AchievementFour"),
                (!fifthAchievementAchieved, "AchievementFive"),
            ].compactMap { (condition, name) in
                condition ? ("AchievementBackground", name) : nil
            }
            
            VStack(spacing: unachievedAchievements.count > 1 ? 40 : 0) {
                ForEach(0..<unachievedAchievements.count, id: \.self) { i in
                    let background = unachievedAchievements[i].0
                    let image = unachievedAchievements[i].1
                    
                    ZStack {
                        Image(background)
                            .resizable()
                            .frame(width: 340, height: 600)
                        Image(image)
                            .resizable()
                            .frame(width: 370, height: 800)
                    }
                    .frame(height: 60)
                }
            }
            .position(x: 195, y: 400)
            Button {
                achievementSceneID = UUID()
                screenDirection = "startup"
                startupScene?.isPaused = false
            } label: {
                exit
            }
            .position(x: 200, y: 740)
        }
    }
    
    func resumePinballScene(playerWon: Bool, scene: SKScene) {
        playTime += bossScene!.timeSurvivedValue
        scene.removeAllChildren()
        scene.removeAllActions()
        bossScene = nil
        bossSceneID = UUID()
        
        if let scene = pinballScene {
            scene.isPaused = false
            scene.physicsWorld.speed = 1.0
            scene.flipLeft.physicsBody?.angularVelocity = 0
            scene.flipLeft.physicsBody?.velocity = .zero
            scene.flipLeft.physicsBody?.isResting = true
            scene.flipLeft.zRotation = -.pi/3
            scene.leftPressed = false
            scene.flipRight.physicsBody?.angularVelocity = 0
            scene.flipRight.physicsBody?.velocity = .zero
            scene.flipRight.physicsBody?.isResting = true
            scene.flipRight.zRotation = .pi/3
            scene.rightPressed = false
            screenDirection = "pinball"
            scene.ballSkin = ballDesign
            if !isDupBallThere {
                for node in scene.pinballWorldNode.children {
                    if node.name == "PinballDup" {
                        scene.dupBallActive = false
                        node.removeFromParent()
                    }
                }
            }
            scene.physicsWorld.gravity = CGVector(dx: 0, dy: -3)
            scene.jumpBoostAvailable = true
            if !playerWon {
                scene.timerValue -= 75
            }
            else {
                scene.timerValue += 75
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                scene.physicsWorld.gravity = CGVector(dx: 0, dy: -10)
            }
        } else {
            pinballScene?.ballSkin = ballDesign
            pinballScene = PinballScene(size: CGSize(width: 390, height: 844))
            pinballSceneID = UUID()
            screenDirection = "pinball"
        }
    }
    
    func startGame(){
        playerLost = false
        startupScene?.isPaused = true
        pinballScene?.timeSurvivedValue = 0
        bossScene?.timeSurvivedValue = 0
        playTime = 0
        bossScene?.removeAllChildren()
        pinballScene?.removeAllChildren()
        pinballScene = PinballScene(size: CGSize(width: 390, height: 944))
        pinballScene?.scaleMode = .aspectFit
        
        pinballScene?.ballSkin = ballDesign
        pinballScene?.activatedDupPower = false
        pinballScene?.activatedFlipPower = false
        pinballScene?.activatedPunPower = false
        pinballScene?.activatedBossPower = false
        pinballSceneID = UUID()
        screenDirection = "pinball"
    }
}

#Preview {
    ContentView()
}
