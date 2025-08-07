//
//  TransparentSpriteView.swift
//  PinballTrue
//
//  Created by Muhammad Mahmood on 6/30/25.
//
import SwiftUI
import SpriteKit

struct TransparentSpriteView: UIViewRepresentable {
    let scene: SKScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.presentScene(scene)

        view.allowsTransparency = true
        view.backgroundColor = .clear
        scene.backgroundColor = .clear

        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // No-op
    }
}
