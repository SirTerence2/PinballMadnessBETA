//
//  ContentView.swift
//  PinballTrue
//
//  Created by Muhammad Mahmood on 6/23/25.
//

import SwiftUI
import SpriteKit
import UIKit
import Combine
import AVFAudio


func makeStartupScene() -> StartupScene {
    let scene = StartupScene(size: CGSize(width: 390, height: 844))
    scene.scaleMode = .resizeFill
    return scene
}

func makeSkinsScene() -> SkinsScene {
    let scene = SkinsScene(size: CGSize(width: 390, height: 844))
    scene.scaleMode = .resizeFill
    return scene
}

func makeAchievementsScene() -> AchievementScene {
    let scene = AchievementScene(size: CGSize(width: 390, height: 844))
    scene.scaleMode = .resizeFill
    return scene
}

private enum DefaultsKey {
    static let selectedSkin = "selectedSkin"
    static let achievementsCount = "achievementsCount"
    static let achievementsCSV = "achievementsCSV"
}

enum Achievement: String, CaseIterable {
    case allPowersActivated
    case fiveBossWins
    case survive3min
    case survive6min
    case noDamage
}

final class SFX: ObservableObject {
    static let shared = SFX()

    private var players: [String: AVAudioPlayer] = [:]
    private var music: AVAudioPlayer?
    private var currentTrack: String?

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func play(_ filename: String, volume: Float = 1, loops: Int = 0) {
        let ns = filename as NSString
        let name = ns.deletingPathExtension
        let ext  = ns.pathExtension.isEmpty ? "wav" : ns.pathExtension
        let key  = "\(name).\(ext)"

        if players[key] == nil,
           let url = Bundle.main.url(forResource: name, withExtension: ext),
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.prepareToPlay()
            players[key] = p
        }
        guard let p = players[key] else { return }
        p.currentTime = 0
        p.volume = volume
        p.numberOfLoops = loops
        p.play()
    }

    func stop(_ filename: String) {
        let ns = filename as NSString
        players["\(ns.deletingPathExtension).\(ns.pathExtension.isEmpty ? "wav" : ns.pathExtension)"]?.stop()
    }

    func switchMusic(to filename: String, volume: Float = 0.35, crossfade: TimeInterval = 1.0) {
        if currentTrack == filename, music?.isPlaying == true { return }

        let ns = filename as NSString
        let name = ns.deletingPathExtension
        let ext  = ns.pathExtension.isEmpty ? "mp3" : ns.pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Missing music: \(name).\(ext)"); return
        }

        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.numberOfLoops = -1
        newPlayer.volume = 0
        newPlayer.prepareToPlay()
        newPlayer.play()
        newPlayer.setVolume(volume, fadeDuration: crossfade)

        let old = music
        old?.setVolume(0, fadeDuration: crossfade)
        DispatchQueue.main.asyncAfter(deadline: .now() + crossfade + 0.1) {
            old?.stop()
        }

        music = newPlayer
        currentTrack = filename
    }

    func pauseMusic() { music?.pause() }
    func resumeMusic() { music?.play() }
    func setMusicVolume(_ v: Float) { music?.volume = v }
}

struct ContentView: View {
    private var isPad: Bool {UIDevice.current.userInterfaceIdiom == .pad }
    private let baseSize = CGSize(width: 390, height: 844)
    
    @State private var pinballSceneID = UUID()
    @State private var startupSceneID = UUID()
    @State private var settingSceneID = UUID()
    @State private var bossSceneID = UUID()
    @State private var achievementSceneID = UUID()
    @State private var skinsSceneID = UUID()
    
    @State private var isDupBallThere = false
    
    @State private var screenDirection: String = "startup"
    @State private var isSetting: Bool = false;
    @State private var playerLost: Bool = false;
    
    @AppStorage(DefaultsKey.selectedSkin) private var ballDesign: String = "Pinball"
    
    let timer = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()
    
    @State private var pinballScene: PinballScene? = PinballScene(size: CGSize(width: 390, height: 944))
    @State private var startupScene: StartupScene? = makeStartupScene()
    
    @State private var bossScene: BossScene? = nil
    @State private var achievementScene: AchievementScene? = makeAchievementsScene()
    @State private var skinsScene: SkinsScene? = makeSkinsScene()
    
    @State internal var firstAchievementAchieved: Bool = false
    @State internal var secondAchievementAchieved: Bool = false
    @State internal var thirdAchievementAchieved: Bool = false
    @State internal var fourthAchievementAchieved: Bool = false
    @State internal var fifthAchievementAchieved: Bool = false
    var numberOfAchievementsAchieved: Int { unlocked.count }
    
    @State private var playTime: TimeInterval = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var playTimerLabel: String = "00:00"
    @State private var ballCancellable: AnyCancellable?
    @State private var bossFightCount: Int = 0
    @StateObject private var sfx = SFX.shared
    
    @State private var positionHistory: [(time: TimeInterval, pos: CGPoint, vel: CGVector?)] = []
    
    @AppStorage(DefaultsKey.achievementsCSV) private var achievementsCSV: String = ""
    
    @Environment(\.scenePhase) private var scenePhase
    
    var unlocked: Set<Achievement> {
        get {
            let parts = achievementsCSV.split(separator: ",").map { String($0) }
            return Set(parts.compactMap(Achievement.init(rawValue:)))
        }
        set {
            achievementsCSV = newValue.map(\.rawValue).joined(separator: ",")
        }
    }
    
    func isUnlocked(_ a: Achievement) -> Bool { unlocked.contains(a) }
    
    var achievementsCount: Int { unlocked.count }
    
    func csvByAdding(_ a: Achievement, to csv: String) -> String {
        var set = Set(
            csv.split(separator: ",").compactMap { Achievement(rawValue: String($0)) }
        )
        let inserted = set.insert(a).inserted
        return inserted ? set.map(\.rawValue).joined(separator: ",") : csv
    }
    
    private func applyPauseStateForCurrentScreen() {
        switch screenDirection {
        case "pinball":
            pinballScene?.isPaused = isSetting || playerLost
        case "boss":
            bossScene?.isPaused = isSetting
        case "startup":
            startupScene?.isPaused = isSetting
        default:
            break
        }
    }
    
    private func trackForScreen(_ screenDirection: String) -> String? {
        switch screenDirection {
        case "startup", "skins", "achievement":
            return "StartupScreenMusic.mp3"
        case "pinball":
            return "PinballScreenMusic.mp3"
        case "boss":
            return "BossMusic.mp3"
        default:
            return nil
        }
    }
    
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
        
        let background = Image("BckgroundImageGeneral")
            .resizable()
        
        let backgroundPinball = Image("Background_metal")
            .resizable()
            .scaledToFill()
        
        GeometryReader { geo in
            ZStack{
                if screenDirection != "pinball" && screenDirection != "boss" {
                    background
                        .frame(width: geo.size.width, height: geo.size.height * 2.25/2)
                        .ignoresSafeArea()
                        .scaledToFit()
                }
                else {
                    backgroundPinball
                        .ignoresSafeArea()
                }
                
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
                                    sfx.play("ButtonPressed.wav")
                                    isSetting = false
                                    pinballScene?.isPaused = false
                                } label: {
                                    exit
                                }
                                .position(x: 200, y: 830)
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
                                    ZStack{
                                        VStack{
                                            settings
                                        }
                                        Button {
                                            sfx.play("ButtonPressed.wav")
                                            isSetting = false
                                            bossScene?.isPaused = false
                                        } label: {
                                            exit
                                        }
                                        .position(x: 200, y: 830)
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
                        //SettingChanged.wav
                        GeometryReader { geometry in
                            SpriteView(scene: scene)
                                .id(achievementSceneID)
                                .ignoresSafeArea()
                            Button {
                                sfx.play("SettingChanged.wav")
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
                                sfx.play("SettingChanged.wav")
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
                                    sfx.play("SettingChanged.wav")
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
                                    sfx.play("SettingChanged.wav")
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
                            sfx.play("ButtonPressed.wav")
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
        .onAppear {
            if let t = trackForScreen(screenDirection) {
                SFX.shared.switchMusic(to: t, volume: 0.35, crossfade: 0.8)
            }
        }

        .onChange(of: screenDirection) { newScreen in
            if let t = trackForScreen(newScreen) {
                SFX.shared.switchMusic(to: t, volume: 0.35, crossfade: 1.2)
            }
        }
        .onAppear { applyPauseStateForCurrentScreen() }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                applyPauseStateForCurrentScreen()
            case .inactive, .background:
                pinballScene?.isPaused = true
                bossScene?.isPaused = true
                startupScene?.isPaused = true
            @unknown default: break
            }
        }
        .onChange(of: isSetting) { _ in
            applyPauseStateForCurrentScreen()
        }
        .onChange(of: screenDirection) { _ in
            applyPauseStateForCurrentScreen()
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
                            .offset(y: -60)
                            .onAppear {
                                sfx.play("LoseSound.mp3")
                                playTime += pinballScene!.timeSurvivedValue
                                minutes = Int(playTime) / 60
                                seconds = Int(playTime) % 60
                                if !thirdAchievementAchieved {
                                    //180
                                    thirdAchievementAchieved = playTime >= 180
                                    if thirdAchievementAchieved {
                                        sfx.play("AchievementUnlocked.wav")
                                        achievementsCSV = csvByAdding(.survive3min, to: achievementsCSV)
                                    }
                                }
                                print(playTime)
                                if !fourthAchievementAchieved {
                                    //360
                                    fourthAchievementAchieved = playTime >= 360
                                    if fourthAchievementAchieved {
                                        sfx.play("AchievementUnlocked.wav")
                                        achievementsCSV = csvByAdding(.survive6min, to: achievementsCSV)
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
                        sfx.play("ButtonPressed.wav")
                        startGame()
                    } label: {
                        Image("Replay_Button")
                            .resizable()
                            .frame(width: 170, height: 170)
                    }
                    Button {
                        sfx.play("ButtonPressed.wav")
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
                .onAppear() {
                    if unlocked.contains(.allPowersActivated) {
                        firstAchievementAchieved = true
                    }
                    if unlocked.contains(.fiveBossWins) {
                        secondAchievementAchieved = true
                    }
                    if unlocked.contains(.survive3min) {
                        thirdAchievementAchieved = true
                    }
                    if unlocked.contains(.survive6min) {
                        fourthAchievementAchieved = true
                    }
                    if unlocked.contains(.noDamage) {
                        fifthAchievementAchieved = true
                    }
                }
            if unlocked.contains(.allPowersActivated) {
                //firstAchievementAchieved = true
                star.position(x: 100, y: isPad ? 260 : 235)
            }
            if unlocked.contains(.fiveBossWins) {
                //secondAchievementAchieved = true
                star.position(x: 280, y: isPad ? 260 : 235)
            }
            if unlocked.contains(.survive3min) {
                //thirdAchievementAchieved = true
                star.position(x: 325, y: isPad ? 360 : 345)
            }
            if unlocked.contains(.survive6min) {
                //fourthAchievementAchieved = true
                star.position(x:195, y: isPad ? 360 : 345)
            }
            if unlocked.contains(.noDamage) {
                //fifthAchievementAchieved = true
                star.position(x: 61, y: isPad ? 360 : 345)
            }
            Button {
                sfx.play("ButtonPressed.wav")
                startGame()
            } label: {
                Image("Start_Button")
                    .resizable()
                    .frame(width: 156, height: 156)
            }
            .position(x: 195, y: 780)
            
            Button {
                sfx.play("ButtonPressed.wav")
                isSetting = true
            } label: {
                Image("Settings_Button")
                    .resizable()
                    .frame(width: 156, height: 156)
            }
            .position(x: 195, y: 590)
            
            Button {
                sfx.play("ButtonPressed.wav")
                startupScene?.isPaused = true
                skinsSceneID = UUID()
                screenDirection = "skins"
            } label: {
                Image("Skins_Button")
                    .resizable()
                    .frame(width: 98, height: 98)
            }
            .position(x: 52, y: 770)
            
            if !firstAchievementAchieved && !secondAchievementAchieved && !thirdAchievementAchieved && !fourthAchievementAchieved && !fifthAchievementAchieved {
                Button {
                    sfx.play("ButtonPressed.wav")
                    startupScene?.isPaused = true
                    achievementSceneID = UUID()
                    screenDirection = "achievement"
                } label: {
                    Image("Achievements_Button")
                        .resizable()
                        .frame(width: 120, height: 120)
                }
                .position(x: 330, y: 670)
            }
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
                    sfx.play("ButtonPressed.wav")
                    isSetting = false
                } label: {
                    exit
                }
                .position(x: 195, y: 830)
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
                .onReceive(scene.bossPublisher) {
                    positionHistory = pinballScene?.positionHistory ?? []
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
                        sfx.play("AchievementUnlocked.wav")
                        achievementsCSV = csvByAdding(.allPowersActivated, to: achievementsCSV)
                    }
                }
            Button {
                sfx.play("ButtonPressed.wav")
                pinballScene?.isPaused = true
                isSetting = true
                
            } label: {
                settingsButton
            }
            .position(x: 320, y: 20)
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
        ZStack{
            SpriteView(scene: scene)
                .id(bossSceneID)
                .ignoresSafeArea()
                .onAppear(){
                    sfx.play("TeleportationFromPinballToBoss.wav")
                }
                .onReceive(scene.victoryPublisher){
                    bossFightCount += 1
                    if !secondAchievementAchieved{
                        secondAchievementAchieved = bossFightCount >= 5
                        if secondAchievementAchieved {
                            sfx.play("AchievementUnlocked.wav")
                            achievementsCSV = csvByAdding(.fiveBossWins, to: achievementsCSV)
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
                        sfx.play("AchievementUnlocked.wav")
                        achievementsCSV = csvByAdding(.noDamage, to: achievementsCSV)
                    }
                }
            Button {
                sfx.play("ButtonPressed.wav")
                bossScene?.isPaused = true
                isSetting = true
                
            } label: {
                settingsButton
            }
            .position(x: 195, y: isPad ? 0 : 4)
            
            if isSetting {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
            }
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
                sfx.play("ButtonPressed.wav")
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
            scene.flipRight.physicsBody?.angularVelocity = 0
            scene.flipRight.physicsBody?.velocity = .zero
            scene.flipRight.physicsBody?.isResting = true
            scene.flipRight.zRotation = .pi/3
            scene.positionHistory = positionHistory
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
                scene.timerValue -= 150
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
        
        pinballScene?.ballSkin = ballDesign
        pinballScene?.activatedDupPower = false
        pinballScene?.activatedRotaPower = false
        pinballScene?.activatedPunPower = false
        pinballScene?.activatedBossPower = false
        pinballSceneID = UUID()
        screenDirection = "pinball"
    }
}

#Preview {
    ContentView()
}
