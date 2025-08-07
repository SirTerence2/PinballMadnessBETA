//
//  ContentView.swift
//  PinballTrue
//
//  Created by Muhammad Mahmood on 6/23/25.
//

import SwiftUI
import SpriteKit
import Combine

struct ContentView: View {
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
    
    @State private var pinballScene: PinballScene? = PinballScene(size: UIScreen.main.bounds.size)
    @State private var startupScene: StartupScene? = StartupScene(size: UIScreen.main.bounds.size)
    @State private var bossScene: BossScene? = nil
    @State private var achievementScene: AchievementScene? = AchievementScene(size: UIScreen.main.bounds.size)
    @State private var skinsScene: SkinsScene? = SkinsScene(size: UIScreen.main.bounds.size)
    
    @State private var firstAchievementAchieved: Bool = true
    @State private var secondAchievementAchieved: Bool = true
    @State private var thirdAchievementAchieved: Bool = true
    @State private var fourthAchievementAchieved: Bool = true
    @State private var fifthAchievementAchieved: Bool = true
    @State private var numberOfAchievementsAchieved: Int = 0
    
    @State private var playTime: TimeInterval = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var playTimerLabel: String = "00:00"
    @State private var ballCancellable: AnyCancellable?
    @State private var bossFightCount: Int = 0
    
    
    var body: some View {
        GeometryReader { geo in
            let geoSize = geo.size
            let geoWidth = geoSize.width
            let geoHeight = geoSize.height
            
            let star = Image("Star")
                .resizable()
                .frame(width: geoWidth * 0.25, height: geoWidth * 0.25)
            
            let settings = Image("SettingsPage")
                .resizable()
                .frame(width: geoWidth, height: geoHeight)
            
            let exit = Image("Exit_button")
                .resizable()
                .frame(width: geoWidth * 0.44, height: geoHeight * 0.2)
            
            let skinBox = Image("BallSelectionFrame")
                .resizable()
                .frame(width: geoWidth * 0.51, height: geoHeight * 0.24)
            ZStack {
                ZStack {
                    if screenDirection == "startup"{
                        if let scene = startupScene {
                            ZStack {
                                SpriteView(scene: scene)
                                    .id(startupSceneID)
                                    .ignoresSafeArea()
                                if firstAchievementAchieved {
                                    star.position(x: geoWidth * 0.26, y: geoHeight * 0.27)
                                }
                                if secondAchievementAchieved {
                                    star.position(x: geoWidth * 0.72, y: geoHeight * 0.27)
                                }
                                if thirdAchievementAchieved {
                                    star.position(x: geoWidth * 0.84, y: geoHeight * 0.40)
                                }
                                if fourthAchievementAchieved {
                                    star.position(x: geoWidth * 0.5, y: geoHeight * 0.40)
                                }
                                if fifthAchievementAchieved {
                                    star.position(x: geoWidth * 0.15, y: geoHeight * 0.40)
                                }
                                
                                Button {
                                    startGame(geoSize: geoSize)
                                } label: {
                                    Image("Start_Button")
                                        .resizable()
                                        .frame(width: geoWidth * 0.4, height: geoWidth * 0.4)
                                }
                                .position(x: geoWidth * 0.5, y: geoHeight * 0.95)
                                
                                Button {
                                    isSetting = true
                                    
                                } label: {
                                    Image("Settings_Button")
                                        .resizable()
                                        .frame(width: geoWidth * 0.4, height: geoWidth * 0.4)
                                }
                                .position(x: geoWidth * 0.5, y: geoHeight * 0.70)
                                
                                Button {
                                    startupScene?.isPaused = true
                                    skinsSceneID = UUID()
                                    screenDirection = "skins"
                                } label: {
                                    Image("Skins_Button")
                                        .resizable()
                                        .frame(width: geoWidth * 0.25, height: geoWidth * 0.25)
                                }
                                .position(x: geoWidth * 0.13, y: geoHeight * 0.83)
                                
                                Button {
                                    startupScene?.isPaused = true
                                    achievementSceneID = UUID()
                                    screenDirection = "achievement"
                                } label: {
                                    Image("Achievements_Button")
                                        .resizable()
                                        .frame(width: geoWidth * 0.35, height: geoHeight * 0.20)
                                }
                                .position(x: geoWidth * 0.82, y: geoHeight * 0.83)
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
                                    .position(x: geoWidth / 2, y: geoHeight * 0.95)
                                }
                            }
                        }
                    }
                    else if screenDirection == "pinball"{
                        if let scene = pinballScene {
                            ZStack {
                                SpriteView(scene: scene)
                                    .id(pinballSceneID)
                                    .ignoresSafeArea()
                                    .onReceive(scene.flipPublisher) {
                                        isFlippedItemInEffect.toggle()
                                    }
                                    .onReceive(scene.bossPublisher) {
                                        pinballScene?.isPaused = true
                                        let newBossScene = BossScene(size: geoSize, ballSkin: ballDesign, dupBallThere: isDupBallThere)
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
                                    Image("Settings_Button")
                                        .resizable()
                                        .frame(width: geoWidth * 0.2, height: geoWidth * 0.2)
                                }
                                .offset(x: geoWidth * 0.3, y: isFlippedItemInEffect ? geoHeight * 0.55 : -1 * geoHeight * 0.55)
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
                            .onAppear {
                                //checks to see if the ball is there
                                ballCancellable = scene.dupPublisher
                                    .sink { value in
                                        isDupBallThere = value
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
                                    .position(x: geoWidth * 0.51, y: geoHeight * 0.95)
                                }
                            }
                            if playerLost {
                                ZStack {
                                    VStack{
                                        ZStack{
                                            Image("GameOverScene")
                                                .resizable()
                                                .frame(width: geoWidth, height: geoHeight * 1.2)
                                                .offset(y: -1 * geoHeight * 0.08)
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
                                                    .font(.largeTitle)
                                                    .foregroundColor(.red)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(Color.black)
                                                    )
                                                    .offset(y: geoHeight * 0.2)
                                            }
                                        }
                                        
                                    }
                                    HStack{
                                        Button {
                                            startGame(geoSize: geoSize)
                                        } label: {
                                            Image("Replay_Button")
                                                .resizable()
                                                .frame(width: geoWidth * 0.44, height: geoHeight *  0.2)
                                        }
                                        Button {
                                            playerLost = false
                                            startupSceneID = UUID()
                                            screenDirection = "startup"
                                        } label: {
                                            exit
                                                .offset(x: geoWidth * 0.03)
                                        }
                                    }
                                    .position(x: geoWidth * 0.5, y: geoHeight * 0.96)
                                }
                            }
                        }
                    }
                    else if screenDirection == "boss", let scene = bossScene {
                        ZStack{
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
                                    resumePinballScene(geoSize: geoSize, playerWon: true, scene: scene)
                                }
                                .onReceive(scene.losePublisher) {
                                    isDupBallThere = scene.dupBallThere
                                    resumePinballScene(geoSize: geoSize, playerWon: false, scene: scene)
                                }
                                .onReceive(scene.neverRecievedDamagePublisher) {
                                    if !fifthAchievementAchieved {
                                        fifthAchievementAchieved = true
                                        numberOfAchievementsAchieved += 1
                                    }
                                }
                        }
                    }
                    else if screenDirection == "achievement", let scene = achievementScene {
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
                                            .frame(width: geoWidth * 0.95, height: geoHeight * 0.71)
                                        Image(image)
                                            .resizable()
                                            .frame(width: geoWidth * 1.03, height: geoHeight * 0.95)
                                    }
                                    .frame(height: geoHeight * 0.07)
                                }
                            }
                            .position(x: geoWidth * 0.52, y: geoHeight * 0.41)
                            Button {
                                achievementSceneID = UUID()
                                screenDirection = "startup"
                                startupScene?.isPaused = false
                            } label: {
                                exit
                            }
                            .position(x: geoWidth * 0.52, y: geoHeight * 0.82)
                        }
                    }
                    else if screenDirection == "skins", let scene = skinsScene {
                        ZStack{
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
                                            .frame(width: geoWidth * 0.38, height: geoHeight * 0.18)
                                            .offset(x: -1 * geoWidth * 0.02, y: -1 * geoHeight * 0.01)
                                    )
                            }
                            .position(x: geoWidth * 0.31, y: geoHeight * 0.23)
                            
                            Button {
                                ballDesign = "PinballNuclear"
                            } label: {
                                skinBox
                                    .overlay(
                                        Image("PinballNuclear")
                                            .resizable()
                                            .frame(width: geoWidth * 0.38, height: geoHeight * 0.18)
                                            .offset(x: -1 * geoWidth * 0.031, y: -1 * geoHeight * 0.006)
                                    )
                            }
                            .position(x: geoWidth * 0.77, y: geoHeight * 0.23)
                            
                            if numberOfAchievementsAchieved >= 3 {
                                Button {
                                    ballDesign = "PinballSharkSkin"
                                } label: {
                                    skinBox
                                        .overlay(
                                            Image("PinballSharkSkin")
                                                .resizable()
                                                .frame(width: geoWidth * 0.38, height: geoHeight * 0.18)
                                                .offset(x: -1 * geoWidth * 0.031, y: -1 * geoHeight * 0.014)
                                        )
                                }
                                .position(x: geoWidth * 0.31, y: geoHeight * 0.44)
                            }
                            else {
                                skinBox
                                    .overlay(
                                        Image("NotAchievedGraphic")
                                            .resizable()
                                            .frame(width: geoWidth * 0.38, height: geoHeight * 0.18)
                                            .offset(x: -6, y: 4)
                                    )
                                    .position(x: geoWidth * 0.31, y: geoHeight * 0.44)
                            }
                            
                            if numberOfAchievementsAchieved >= 5 {
                                Button {
                                    ballDesign = "SpecialPinball"
                                } label: {
                                    skinBox
                                        .overlay(
                                            Image("SpecialPinball")
                                                .resizable()
                                                .frame(width: geoWidth * 0.38, height: geoHeight * 0.18)
                                                .offset(x: -1 * geoWidth * 0.031, y: -1 * geoHeight * 0.007)
                                        )
                                }
                                .position(x: geoWidth * 0.77, y: geoHeight * 0.44)
                            }
                            else {
                                skinBox
                                    .overlay(
                                        Image("NotAchievedGraphic")
                                            .resizable()
                                            .frame(width: geoWidth * 0.46, height:  geoHeight * 0.21)
                                            .offset(x: -1 * geoWidth * 0.02, y: geoHeight * 0.005)
                                    )
                                    .position(x: geoWidth * 0.77, y: geoHeight * 0.44)
                            }
                            HStack{
                                Image("Selected_Skin_Text")
                                    .resizable()
                                    .frame(width: geoWidth * 0.77, height: geoHeight * 0.36)
                                Image(ballDesign)
                                    .resizable()
                                    .frame(width: geoWidth * 0.38, height: geoHeight * 0.18)
                                    .offset(x: -1 * geoWidth * 0.05)
                            }
                            .position(x: geoWidth * 0.49, y: geoHeight * 0.66)
                        }
                        Button {
                            startupScene?.isPaused = false
                            screenDirection = "startup"
                        } label: {
                            exit
                        }
                        .position(x: geoWidth * 0.5, y: geoHeight * 0.86)
                    }
                }
            }
        }
    }
    
    func resumePinballScene(geoSize: CGSize, playerWon: Bool, scene: SKScene) {
        playTime += bossScene!.timeSurvivedValue
        scene.removeAllChildren()
        scene.removeAllActions()
        bossScene = nil
        bossSceneID = UUID()
        
        if let scene = pinballScene {
            scene.isPaused = false
            scene.physicsWorld.speed = 1.0
            screenDirection = "pinball"
            scene.ballSkin = ballDesign
            scene.physicsWorld.gravity = CGVector(dx: 0, dy: -3)
            if isDupBallThere {
                scene.addDupBall()
            }
            scene.jumpBoostAvailable = true
            if !playerWon {
                scene.timerValue -= 120
            }
            else {
                scene.timerValue += 120
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                scene.physicsWorld.gravity = CGVector(dx: 0, dy: -10)
            }
        } else {
            pinballScene?.ballSkin = ballDesign
            pinballScene = PinballScene(size: geoSize)
            pinballSceneID = UUID()
            screenDirection = "pinball"
        }
    }
    
    func startGame(geoSize: CGSize){
        playerLost = false
        pinballScene?.timeSurvivedValue = 0
        bossScene?.timeSurvivedValue = 0
        playTime = 0
        bossScene?.removeAllChildren()
        pinballScene?.removeAllChildren()
        pinballScene = PinballScene(size: geoSize)
        
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
