//
//  SignalGenerator.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/19.
//

import Foundation
import SwiftUI
import AVFoundation

let twoPi = 2 * Float.pi

class SignalGenerator:ObservableObject{
    
    struct FrequencyGenerator{
        let frequency:Float
    }
    
    enum WaveForm:String, Identifiable, CaseIterable, CustomStringConvertible{
    
        typealias WaveformFunction = ((Float)->Float)
        
        case sine
        case triangle
        case square
        
        var id: String {
            return self.rawValue
        }
        
        var description: String{
            switch self {
            case .sine:
                return NSLocalizedString("Sine", comment: "")
            case .square:
                return NSLocalizedString("Square", comment: "")
            case .triangle:
                return NSLocalizedString("Triangle", comment: "")
            }
        }
        
        
        var function:WaveformFunction{
            switch self {
            case .sine:
                return {f in sin(f)}
            case .square:
                return {phase in
                    if phase <= Float.pi {
                        return 1.0
                    } else {
                        return -1.0
                    }
                }
            case .triangle:
                return {phase in
                    var value = (2.0 * (phase * (1.0 / twoPi))) - 1.0
                    if value < 0.0 {
                        value = -value
                    }
                    return 2.0 * (value - 0.5)
                }
            }
        }
    }
    
    
    
    @Published var amplitude:Float = 0.5{
        didSet{
            engine.mainMixerNode.outputVolume = amplitude
        }
    }
    
    @Published var isRunning:Bool=false{
        didSet{
            if isRunning == true{
                self.start()
            }
            else{
                self.stop()
            }
        }
    }
    
    let engine:AVAudioEngine
    
    @Published var waveForm:WaveForm = .sine{
        didSet{
            self.nodes.forEach({$0.waveFormFunction = waveForm.function})
        }
    }
    
    let maxNodes=4
    
    @Published var canAttachNodes:Bool=true
    
    @Published var nodes:[AudioNode] = [AudioNode]()
    
    init() {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set the audio session category, mode, and options.
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
        } catch {
            print("Failed to set audio session category.")
        }
        #endif
        
        self.engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let output = engine.outputNode
        let outputFormat = output.inputFormat(forBus: 0)
        engine.connect(mainMixer, to: output, format: outputFormat)
        mainMixer.outputVolume = 0.5
        self.attachNode()
    }
    
    
    func attachNode(){
        let output = engine.outputNode
        let outputFormat = output.inputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate)
        
        let inputFormat = AVAudioFormat(commonFormat: outputFormat.commonFormat,
                                        sampleRate: outputFormat.sampleRate,
                                        channels: 1,
                                        interleaved: outputFormat.isInterleaved)
        
         

        let mainMixer = engine.mainMixerNode
        
        let node=AudioNode(sampleRate: sampleRate)
        self.nodes.append(node)

        engine.attach(node.audioNode)
        engine.connect(node.audioNode, to: mainMixer, format: inputFormat)
        self.canAttachNodes = self.nodes.count < self.maxNodes
    }
    
    func remove(node:AudioNode){
        guard let idx=self.nodes.firstIndex(where: {$0 == node}) else{
            return
        }
        engine.detach(self.nodes[idx].audioNode)
        self.nodes.remove(at: idx)
        self.canAttachNodes = self.nodes.count < self.maxNodes
    }
    
    func start(){
        DispatchQueue.global(qos: .background).async {
            do {
                
                try self.engine.start()
                
            } catch {
                print("Could not start engine: \(error)")
            }
        }
    }
    
    func stop(){
        engine.stop()
    }
}

