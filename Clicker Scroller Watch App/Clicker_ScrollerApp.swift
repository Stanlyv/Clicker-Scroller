//
//  Clicker_ScrollerApp.swift
//  Clicker Scroller Watch App
//
//  Created by Станіслав Стреляний on 14.06.2026.
//

import SwiftUI

@main
struct Clicker_Scroller_Watch_AppApp: App {
    @StateObject private var game = GameState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
        }
        .onChange(of: scenePhase) { _, phase in
            // Persist whenever we leave the foreground so offline earnings and
            // progress survive being backgrounded.
            if phase != .active { game.save() }
        }
    }
}
