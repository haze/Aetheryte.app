//
//  ContentView.swift
//  Aetheryte
//
//  Created by Haze Booth on 8/5/25.
//

import SwiftUI

struct ContentView: View {
	@State var player: Player? = nil
	@State var errorMessage: String? = nil
	
    var body: some View {
		if let player = player {
			PlayerView(player: player)
		} else if let errorMessage = errorMessage {
			VStack {
				Text(errorMessage)
			}
		} else {
			ProgressView()
				.task {
					do {
						player = try Player.init()
					} catch {
						errorMessage = error.localizedDescription
					}
				}
		}
    }
}

#Preview {
    ContentView()
}
