//
//  RealTimeSpectrogram.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/06/07.
//

import SwiftUI
import Combine
import Accelerate

struct RealTimeSpectrogram: View {
    
    class RealTimeBuffer:ObservableObject{
        
        fileprivate static let bufferSize=1024
        @Published var buffer:[Double]=Array<Double>.init(repeating: 0, count: RealTimeBuffer.bufferSize)
        
        var cancelables=Set<AnyCancellable>()
        
        init(audioSource:AnyPublisher<Int16,Never>) {
            audioSource
                .buffer(size: RealTimeBuffer.bufferSize, prefetch: .byRequest, whenFull: .dropOldest)
                .collect(RealTimeBuffer.bufferSize)
                .throttle(for: 0.05, scheduler: RunLoop.main, latest: true)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: {[unowned self] samples in
                    guard samples.count == RealTimeBuffer.bufferSize else{return}
                    vDSP.convertElements(of: samples,
                                         to: &self.buffer)
                    
                })
                .store(in: &cancelables)
        }
    }
    
    @ObservedObject var buffer:RealTimeBuffer

    @State var autoScale:Bool = false
    
    init(audioSource:AnyPublisher<Int16,Never>) {
        self.buffer=RealTimeBuffer(audioSource: audioSource)
    }
    
    var body: some View {
        
        Spectrum(samples: buffer.buffer, autoScale: autoScale)
            .stroke(Color.red)
            .background(Rectangle().fill(Color.black))
            .overlay(toggle, alignment: .bottomTrailing)
        
        
    }
    
    var toggle:some View{
        let t=Toggle(isOn: $autoScale,
               label: {
                Text("Autoscale").foregroundColor(.white)
               })
        .fixedSize()
        
        #if os(macOS)
            return t.controlSize(.mini)
        #else
        return t
        #endif
    }
}




struct RealTimeSpectrogram_Previews: PreviewProvider {
    
    static var previews: some View {
        let source = AudioSource()
        RealTimeSpectrogram(audioSource: source.samples)
            .onAppear{
                source.startRunning()
            }
        
    }
}
