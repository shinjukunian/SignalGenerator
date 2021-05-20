//
//  SpectrumAnalyzer.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/20.
//

import Foundation
import AVFoundation
import Accelerate
import Combine

//https://developer.apple.com/documentation/accelerate/visualizing_sound_as_an_audio_spectrogram

class SpectrumAnalyzer:NSObject, ObservableObject{
   
    private let freqValues = PassthroughSubject<[Float],Never>()
    
    lazy var frequencies = freqValues.eraseToAnyPublisher()
    
    static let sampleCount = 1024
    
    /// Number of displayed buffers — the width of the spectrogram.
    static let bufferCount = 768
    
    /// Determines the overlap between frames.
    static let hopCount = 512
    
    let captureSession = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    let captureQueue = DispatchQueue(label: "captureQueue",
                                     qos: .userInitiated,
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)
    let sessionQueue = DispatchQueue(label: "sessionQueue",
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)
    
    let forwardDCT = vDSP.DCT(count: sampleCount,
                              transformType: .II)!
    
    /// The window sequence used to reduce spectral leakage.
    let hanningWindow = vDSP.window(ofType: Float.self,
                                    usingSequence: .hanningDenormalized,
                                    count: sampleCount,
                                    isHalfWindow: false)
    
    let dispatchSemaphore = DispatchSemaphore(value: 1)
    
    /// The highest frequency that the app can represent.
    ///
    /// The first call of `AudioSpectrogram.captureOutput(_:didOutput:from:)` calculates
    /// this value.
    var nyquistFrequency: Float?
    
    /// A buffer that contains the raw audio data from AVFoundation.
    var rawAudioData = [Int16]()
    
    /// Raw frequency domain values.
    var frequencyDomainValues = [Float](repeating: 0,
                                        count: bufferCount * sampleCount)
        
    /// A reusable array that contains the current frame of time domain audio data as single-precision
    /// values.
    var timeDomainBuffer = [Float](repeating: 0,
                                   count: sampleCount)
    
    /// A resuable array that contains the frequency domain representation of the current frame of
    /// audio data.
    var frequencyDomainBuffer = [Float](repeating: 0,
                                        count: sampleCount)
    
    @Published var isRunning:Bool = false{
        didSet{
            if isRunning{
                print("Start")
                startRunning()
            }
            else{
                stopRunning()
            }
        }
    }
    
    override init() {
        super.init()
        self.configureCaptureSession()
        audioOutput.setSampleBufferDelegate(self,
                                            queue: captureQueue)
    }
    
    func startRunning() {
        sessionQueue.async {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopRunning(){
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    
    func processData(values: [Int16]) {
        dispatchSemaphore.wait()
        
        vDSP.convertElements(of: values,
                             to: &timeDomainBuffer)
        
        vDSP.multiply(timeDomainBuffer,
                      hanningWindow,
                      result: &timeDomainBuffer)
        
        forwardDCT.transform(timeDomainBuffer,
                             result: &frequencyDomainBuffer)
        
        vDSP.absolute(frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        vDSP.convert(amplitude: frequencyDomainBuffer,
                     toDecibels: &frequencyDomainBuffer,
                     zeroReference: Float(SpectrumAnalyzer.sampleCount))
        
        if frequencyDomainValues.count > SpectrumAnalyzer.sampleCount {
            frequencyDomainValues.removeFirst(SpectrumAnalyzer.sampleCount)
        }
        
        frequencyDomainValues.append(contentsOf: frequencyDomainBuffer)

        dispatchSemaphore.signal()
        
        self.freqValues.send(frequencyDomainValues)
    }
    
}
