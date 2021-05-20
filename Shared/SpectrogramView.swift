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
    
    @ObservedObject var spectrumAnalyzer:SpectrumAnalyzer
    
    @Binding var isRunning:Bool
    
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

#else

struct SpectrogramView:UIViewRepresentable{
    
    typealias UIViewType = UIView
    
    @ObservedObject var spectrumAnalyzer:SpectrumAnalyzer
    
    @Binding var isRunning:Bool
    
    func makeUIView(context: Context) -> UIView {
        let view=SpectrogramUIView()
        let layer=SpectrogramLayer(analyzer: spectrumAnalyzer)
        view.layer.addSublayer(layer)
        layer.frame=view.bounds
        return view
    }
    
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if isRunning != spectrumAnalyzer.isRunning{
            spectrumAnalyzer.isRunning=isRunning
        }
        uiView.setNeedsLayout()
    }
    
}


fileprivate class SpectrogramUIView:UIView{
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.sublayers?.forEach({$0.frame=self.bounds})
    }
}


#endif
