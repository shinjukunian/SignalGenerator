//
//  SpectrogramView.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/20.
//

import Foundation
import SwiftUI

#if os(macOS)

struct SpectrogramView:NSViewRepresentable{
    
    @StateObject var spectrumAnalyzer=SpectrumAnalyzer()
    
    @State var isRunning:Bool = true
    
    func makeNSView(context: Context) -> NSView {
        let view=NSView(frame: .zero)
        let layer=SpectrogramLayer(analyzer: spectrumAnalyzer)
        view.layer=layer
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isRunning != spectrumAnalyzer.isRunning{
            spectrumAnalyzer.isRunning=isRunning
        }
    }
    
    typealias NSViewType = NSView
}

#endif
