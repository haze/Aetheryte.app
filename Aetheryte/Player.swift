//
//  Player.swift
//  Aetheryte
//
//  Created by Haze Booth on 8/5/25.
//

import SwiftUI
import AVKit

enum WhirDelay: String, Identifiable, CaseIterable {
	case inGame = "in game"
	case infrequent = "infrequent"
	
	var id: Self { self }
	
	var delayRange: ClosedRange<Int> {
		switch self {
		case .inGame:
			0...2001
		case .infrequent:
			2001...8001
		}
	}
}

@Observable
class Player {
	// Audio constants
	nonisolated private static let audioGainMultiplier: Float = 0.125
	nonisolated private static let centsPerOctave: Float = 1200
	nonisolated private static let humPlaybackRate: Float = 0.63
	nonisolated private static let whirRateRange: ClosedRange<Float> = 0.794...1.0
	nonisolated private static let whirGainRange: ClosedRange<Float> = 0.6...1.0
	var playing: Bool = false
	
	var humVolume: Float = 1.0 {
		didSet {
			humPlayerNode.volume = humVolume
		}
	}
	
	var whirVolume: Float = 1.0 {
		didSet {
			whirPlayerNode.volume = whirVolume
		}
	}
	
	var mainVolume: Float = 1.0 {
		didSet {
			// Convert linear slider value to logarithmic audio gain
			let clampedVolume = max(0.0, min(1.0, mainVolume))
			let audioGain = sqrt(clampedVolume) * Self.audioGainMultiplier
			audioEngine.mainMixerNode.outputVolume = audioGain
		}
	}
	
	var playHum: Bool = true {
		didSet {
			if playing {
				if !playHum {
					humPlayerNode.pause()
				} else if playing && humSchedulingStarted {
					humPlayerNode.play()
					scheduleHum()
				}
			}
		}
	}
	var playWhirs: Bool = true {
		didSet {
			if playing {
				if !playWhirs {
					whirPlayerNode.pause()
				} else if playing && whirSchedulingStarted {
					whirPlayerNode.play()
					Task.detached {
						await self.scheduleWhir()
					}
				}
			}
		}
	}
	
	var whirDelay: WhirDelay = .inGame
	
	nonisolated let audioEngine: AVAudioEngine
	
	nonisolated let humPlayerNode: AVAudioPlayerNode
	nonisolated let humTimePitchNode: AVAudioUnitTimePitch
	
	nonisolated let whirPlayerNode: AVAudioPlayerNode
	nonisolated let whirTimePitchNode: AVAudioUnitTimePitch
	
	nonisolated let hum: AVAudioFile
	nonisolated let whirs: [AVAudioFile]
	
	private var humSchedulingStarted = false
	private var whirSchedulingStarted = false
	
	init() throws {
		hum = try AVAudioFile(forReading: Bundle.main.url(forResource: "hum", withExtension: "wav")!)
		
		whirs = try ["whir1", "whir2", "whir3", "whir4", "whir5"]
			.map { resource in
				try AVAudioFile(forReading: Bundle.main.url(forResource: resource, withExtension: "wav")!)}
		
		audioEngine = AVAudioEngine()
		
		humPlayerNode = AVAudioPlayerNode()
		humTimePitchNode = AVAudioUnitTimePitch()
		whirPlayerNode = AVAudioPlayerNode()
		whirTimePitchNode = AVAudioUnitTimePitch()
		
		humTimePitchNode.rate = Self.humPlaybackRate
		humTimePitchNode.pitch = Self.centsPerOctave * log2(Self.humPlaybackRate)
		
		whirTimePitchNode.rate = 1.0
		whirTimePitchNode.pitch = 0.0
		
		mainVolume = 0.5
		
		audioEngine.attach(humPlayerNode)
		audioEngine.attach(humTimePitchNode)
		
		audioEngine.connect(humPlayerNode,
							to: humTimePitchNode,
							format: hum.processingFormat)
		audioEngine.connect(humTimePitchNode,
							to: audioEngine.mainMixerNode,
							format: hum.processingFormat)
		
		audioEngine.attach(whirPlayerNode)
		audioEngine.attach(whirTimePitchNode)
		
		audioEngine.connect(whirPlayerNode,
							to: whirTimePitchNode,
							format: audioEngine.outputNode.outputFormat(forBus: 0))
		audioEngine.connect(whirTimePitchNode,
							to: audioEngine.mainMixerNode,
							format: audioEngine.outputNode.outputFormat(forBus: 0))
		
		audioEngine.prepare()
		
		// Configure audio session for background playback (iOS only)
		#if os(iOS)
		do {
			let audioSession = AVAudioSession.sharedInstance()
			try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
			try audioSession.setActive(true)
		} catch {
			print("Failed to configure audio session: \(error)")
		}
		#endif
	}
	
	func scheduleHum() {
		guard playHum && playing else { return }
		
		humPlayerNode.scheduleFile(hum, at: nil, completionCallbackType: .dataConsumed) { _ in
			Task.detached {
				await self.scheduleHum()
			}
		}
	}
	
	func startHumMonitoring() {
		// Install tap on TimePitch output to monitor when audio actually finishes
		let format = humTimePitchNode.outputFormat(forBus: 0)
		humTimePitchNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
			// This fires while audio is playing through the TimePitch node
		}
		humSchedulingStarted = true
		scheduleHum()
	}
	
	nonisolated func scheduleWhir() async {
		guard let randomWhir = whirs.randomElement(),
			  await MainActor.run(body: { playWhirs && playing }) else { return }
		
		let whirPlaybackRate = Float.random(in: Self.whirRateRange)
		whirTimePitchNode.rate = whirPlaybackRate
		whirTimePitchNode.pitch = Self.centsPerOctave * log2(whirPlaybackRate)
		
		let whirGain = Float.random(in: Self.whirGainRange)
		whirPlayerNode.volume = whirGain
		
		whirPlayerNode.scheduleFile(randomWhir, at: nil, completionCallbackType: .dataConsumed) { _ in
			Task.detached {
				let nextWhirDelay = await Int.random(in: self.whirDelay.delayRange)
				try? await Task.sleep(for: .milliseconds(nextWhirDelay))
				await self.scheduleWhir()
			}
		}
	}
	
	func startWhirMonitoring() {
		// Install tap on TimePitch output to monitor when audio actually finishes  
		let format = whirTimePitchNode.outputFormat(forBus: 0)
		whirTimePitchNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
			// This fires while audio is playing through the TimePitch node
		}
		whirSchedulingStarted = true
		Task.detached {
			await self.scheduleWhir()
		}
	}
	
	func play() async {
		playing = true
		do {
			try audioEngine.start()
			humPlayerNode.play()
			whirPlayerNode.play()
		} catch {
			print("Failed to start audio engine: \(error)")
			playing = false
			return
		}
		
		startHumMonitoring()
		startWhirMonitoring()
	}
	
	func pause() {
		playing = false
		humSchedulingStarted = false
		whirSchedulingStarted = false
		humTimePitchNode.removeTap(onBus: 0)
		whirTimePitchNode.removeTap(onBus: 0)
		humPlayerNode.pause()
		whirPlayerNode.pause()
		audioEngine.stop()
	}
	
	func toggle() async {
		playing = !playing
		if playing {
			await play()
		} else {
			pause()
		}
	}
}
