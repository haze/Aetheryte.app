//
//  PlayerView.swift
//  Aetheryte
//
//  Created by Haze Booth on 8/5/25.
//

import SwiftUI

struct PlayerView: View {
	var player: Player
	var volumeImage: String {
		switch player.mainVolume {
		case 0.0..<0.33:
			"speaker.wave.1.fill"
		case 0.33..<0.67:
			"speaker.wave.2.fill"
		case 0.67...1.0:
			"speaker.wave.3.fill"
		default:
			"speaker.wave.3.fill"
		}
	}
	
	var body: some View {
		VStack(spacing: 24) {
			Image("Aetheryte Icon")
				.resizable()
				.frame(width: 50, height: 50)
			
			VStack(spacing: 24) {
				Picker("Whir Delay", selection: Binding(get: { player.whirDelay }, set: { player.whirDelay = $0 })) {
					ForEach(WhirDelay.allCases) { whirDelay in
						Text(whirDelay.rawValue.capitalized)
							.tag(whirDelay)
					}
				}
				.pickerStyle(.segmented)
				
				HStack(spacing: 24) {
					Toggle(isOn: Binding(get: { player.playHum }, set: { player.playHum = $0 })) {
						Text("Play hum?")
					}
					
					Toggle(isOn: Binding(get: { player.playWhirs }, set: { player.playWhirs = $0 })) {
						Text("Play whirs?")
					}
				}
			}
			
			HStack {
				Image(systemName: volumeImage)
				Slider(value: Binding(get: { player.mainVolume }, set: { player.mainVolume = $0 }))
					.frame(maxWidth: 500)
			}
			
			Button {
				Task.detached(priority: .userInitiated) {
					await player.toggle()
				}
			} label: {
				Image(systemName: player.playing ? "pause.fill" : "play.fill")
					.resizable()
					.padding()
			}
			.frame(width: 100, height: 100)
		}
		.padding()
	}
}
