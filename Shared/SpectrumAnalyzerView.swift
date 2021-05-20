//
//  SpectrumAnalyzerView.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/20.
//

import SwiftUI

struct SpectrumAnalyzerView: View {
    
    @StateObject var spectrumAnalyzer=SpectrumAnalyzer()
    
    @State var isRunning=false
    
    var body: some View {
        VStack{
            SpectrogramView(spectrumAnalyzer: spectrumAnalyzer, isRunning: $isRunning)
                .environmentObject(spectrumAnalyzer)
        }.onAppear(perform: {
            isRunning=true
        }).onDisappear{
            isRunning=false
        }
        
    }
}

struct SpectrumAnalyzerView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumAnalyzerView()
    }
}
