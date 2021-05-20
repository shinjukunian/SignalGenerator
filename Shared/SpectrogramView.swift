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
    
    func makeNSView(context: Context) -> NSView {
        
        let view=NSView(frame: .zero)
        let layer=AudioSpectrogram()
        view.layer=layer
        view.wantsLayer = true
        layer.startRunning()
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        
    }
    
    typealias NSViewType = NSView
}

struct MelSpectrogramView:NSViewRepresentable{
    
    
    func makeNSView(context: Context) -> NSView {
        
        let view=NSView(frame: .zero)
        
        let layer=MelSpectrogram()
        view.layer=layer
        view.wantsLayer = true
        layer.startRunning()
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        
    }
    
    typealias NSViewType = NSView
}

#else

struct SpectrogramView:UIViewRepresentable{
    
    typealias UIViewType = UIView
    
   
    
    func makeUIView(context: Context) -> UIView {
        
        let view=SpectrogramUIView()
        let layer=AudioSpectrogram()
        view.layer.addSublayer(layer)
        layer.frame=view.bounds
        layer.startRunning()
        return view
    }
    
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.setNeedsLayout()
    }
    
}

struct MelSpectrogramView:UIViewRepresentable{
    
    typealias UIViewType = UIView
    
   
    
    func makeUIView(context: Context) -> UIView {
        
        let view=SpectrogramUIView()
        let layer=MelSpectrogram()
        view.layer.addSublayer(layer)
        layer.frame=view.bounds
        layer.startRunning()
        return view
    }
    
    
    func updateUIView(_ uiView: UIView, context: Context) {
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
