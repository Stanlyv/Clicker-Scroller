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
            // Leaving the foreground parks the idle loop (and saves on the way
            // out) so a watch on the wrist isn't ticking a timer it can't show.
            game.setActive(phase == .active)
        }
    }
}
