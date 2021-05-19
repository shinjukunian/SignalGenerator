//
//  AudioNode.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/19.
//

import Foundation
import AVFoundation


class AudioNode:ObservableObject, Identifiable, Equatable, Hashable{
    
    @Published var frequency:Float = 440
    
    var amplitude:Float = 0.5
    var currentPhase:Float=0
    var waveFormFunction = SignalGenerator.WaveForm.sine.function
    
    var audioNode:AVAudioNode! //unavoidable due to the initializer
    
    init(sampleRate:Float) {
        self.audioNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = (twoPi / sampleRate) * self.frequency
            //let phaseIncrement2 = (twoPi / sampleRate) * self.frequency2
            
            for frame in 0..<Int(frameCount) {
                
                let value = self.waveFormFunction(self.currentPhase) * self.amplitude
                
                self.currentPhase += phaseIncrement
                //currentPhase2 += phaseIncrement2
                self.currentPhase=self.clamp(phase: self.currentPhase)
                //currentPhase2=self.clamp(phase: currentPhase2)
                
                // Set the same value on all channels (due to the inputFormat we have only 1 channel though).
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = value
                }
            }
            return noErr
        }
        
    }
    
//    func makeNode(sampleRate:Float)->AVAudioNode{
//        
//        
//        return srcNode
//    }
    
    func clamp(phase:Float)->Float{
        var currentPhase=phase
        if currentPhase >= twoPi {
            currentPhase -= twoPi
        }
        if currentPhase < 0.0 {
            currentPhase += twoPi
        }
        return currentPhase
    }
    
    static func == (lhs: AudioNode, rhs: AudioNode) -> Bool {
        return lhs.frequency == rhs.frequency &&
            lhs.amplitude == rhs.amplitude &&
            lhs.audioNode == rhs.audioNode
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.frequency)
        hasher.combine(self.audioNode)
    }
}
