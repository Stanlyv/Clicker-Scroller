//
//  ContentView.swift
//  Clicker Scroller Watch App
//
//  Root view. GameView is shown directly (no NavigationStack around it) so the
//  crown is never claimed by navigation; the Workshop is presented as a sheet.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // NavigationStack hosts the top status-bar toolbar (the badge next to
        // the clock). The Workshop is still a sheet, so nothing here competes
        // with the gear for the Digital Crown's focus.
        NavigationStack {
            GameView()
        }
        .tint(Theme.brass)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameState())
}
