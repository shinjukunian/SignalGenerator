//
//  FFTView.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/06/08.
//

import SwiftUI
import Combine
import Accelerate

struct FFTView: View {
    
    class FFTBuffer:ObservableObject{
        
        fileprivate static let bufferSize=1024
        
        @Published var output:[Double]=Array<Double>.init(repeating: 0, count: FFTBuffer.bufferSize)
        
        var timeDomainBuffer = [Float](repeating: 0,
                                       count: bufferSize)
        
        
        var frequencyDomainBuffer = [Float](repeating: 0,
                                            count: bufferSize)
        
        let forwardDCT = vDSP.DCT(count: bufferSize,
                                  transformType: .II)!
        
        /// The window sequence used to reduce spectral leakage.
        let hanningWindow = vDSP.window(ofType: Float.self,
                                        usingSequence: .hanningDenormalized,
                                        count: bufferSize,
                                        isHalfWindow: false)
        
        let dispatchSemaphore = DispatchSemaphore(value: 1)
        
        
        var cancelables=Set<AnyCancellable>()
        
        init(audioSource:AudioSource.Publisher) {
            audioSource
                .buffer(size: FFTBuffer.bufferSize, prefetch: .byRequest, whenFull: .dropOldest)
                .collect(FFTBuffer.bufferSize)
                .throttle(for: 0.05, scheduler: RunLoop.main, latest: true)
                .sink(receiveValue: {[unowned self] samples in
                    guard samples.count == FFTBuffer.bufferSize else{return}
                    fft(buffer: samples)
                    
                })
                .store(in: &cancelables)
        }
        
        
        func fft(buffer:[Int16]){
            dispatchSemaphore.wait()
            
            vDSP.convertElements(of: buffer,
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
                         zeroReference: Float(AudioSpectrogram.sampleCount))
            vDSP.multiply(-1, frequencyDomainBuffer, result: &frequencyDomainBuffer)
            dispatchSemaphore.signal()
            
            DispatchQueue.main.async {
                vDSP.convertElements(of: self.frequencyDomainBuffer, to: &self.output)
            }
            
        }
        
        
        
        
    }
    
    @ObservedObject var buffer:FFTBuffer

    @State var autoScale:Bool = false
    
    init(audioSource:AudioSource.Publisher) {
        self.buffer=FFTBuffer(audioSource: audioSource)
    }
    
    
    var body: some View {
        Spectrum(samples: buffer.output, autoScale: true)
            .stroke(Color.red)
            .background(Rectangle().fill(Color.black))
            
    }
}

struct FFTView_Previews: PreviewProvider {
    static var previews: some View {
        let source = AudioSource()
        FFTView(audioSource: source.samples)
            .onAppear{
                source.startRunning()
            }
    }
}
