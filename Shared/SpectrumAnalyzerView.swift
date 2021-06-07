//
//  SpectrumAnalyzerView.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/20.
//

import SwiftUI

struct SpectrumAnalyzerView: View {
    
    enum Output: String, Identifiable, CaseIterable, CustomStringConvertible{
        case spectrogram
        case mel
        case realtime
        
        var id: String {return rawValue}
        
        var description: String{
            switch self {
            case .spectrogram:
               return NSLocalizedString("Spectrogram", comment: "")
            case .mel:
                return NSLocalizedString("Mel Spectrum", comment: "")
            case .realtime:
                return NSLocalizedString("Spectrum", comment: "")
            }
            
        }
    }
    
    @State var mode:Output = .realtime
    
    @StateObject var source=AudioSource()
    
    var body: some View {
        VStack{
            Picker(selection: $mode, label: Text(""), content: {
                Text(verbatim: Output.realtime.description).tag(Output.realtime)
                Text(verbatim: Output.spectrogram.description).tag(Output.spectrogram)
                Text(verbatim: Output.mel.description).tag(Output.mel)
                
            })
            .pickerStyle(SegmentedPickerStyle())
            .fixedSize()
            
            switch mode{
            case .mel:
                MelSpectrogramView(source: source.samples).clipShape(RoundedRectangle(cornerRadius: 6))
            case .spectrogram:
                SpectrogramView(source: source.samples).clipShape(RoundedRectangle(cornerRadius: 6))
                
            case .realtime:
                RealTimeSpectrogram(audioSource: source.samples)
//                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            
        }.onAppear(perform: {
            self.source.startRunning()
        }).onDisappear{
            
        }
        
    }
}

struct SpectrumAnalyzerView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumAnalyzerView()
    }
}
