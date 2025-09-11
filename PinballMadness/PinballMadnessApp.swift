//
//  PinballMadnessApp.swift
//  PinballMadness
//
//  Created by Muhammad Mahmood on 7/25/25.
//

import GoogleMobileAds
import SwiftUI

@main
struct PinballMadnessApp: App {
    init() {
        MobileAds.shared.start()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

