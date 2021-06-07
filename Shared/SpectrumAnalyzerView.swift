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
        
        var id: String {return rawValue}
        
        var description: String{
            switch self {
            case .spectrogram:
               return NSLocalizedString("Spectrogram", comment: "")
            case .mel:
                return NSLocalizedString("Mel Spectrum", comment: "")
            }
        }
    }
    
    @State var mode:Output = .spectrogram
    
    var body: some View {
        VStack{
            Picker(selection: $mode, label: Text(""), content: {
                Text(verbatim: Output.spectrogram.description).tag(Output.spectrogram)
                Text(verbatim: Output.mel.description).tag(Output.mel)
            })
            .pickerStyle(SegmentedPickerStyle())
            .fixedSize()
            
            switch mode{
            case .mel:
                MelSpectrogramView().clipShape(RoundedRectangle(cornerRadius: 6))
            case .spectrogram:
                SpectrogramView().clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            
            
        
            
        }.onAppear(perform: {
            
        }).onDisappear{
            
        }
        
    }
}

struct SpectrumAnalyzerView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumAnalyzerView()
    }
}
