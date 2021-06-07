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
    
    let source:AudioSource.Publisher
    
    func makeNSView(context: Context) -> NSView {
        
        let view=NSView(frame: .zero)
        let layer=AudioSpectrogram(audioSource: source)
        view.layer=layer
        view.wantsLayer = true
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        
    }
    
    typealias NSViewType = NSView
}

struct MelSpectrogramView:NSViewRepresentable{
    
    let source:AudioSource.Publisher
    
    func makeNSView(context: Context) -> NSView {
        
        let view=NSView(frame: .zero)
        
        let layer=MelSpectrogram(audioSource: source)
        view.layer=layer
        view.wantsLayer = true
        
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        
    }
    
    typealias NSViewType = NSView
}

#else

struct SpectrogramView:UIViewRepresentable{
    
    typealias UIViewType = UIView
    
    let source:AudioSource.Publisher
    
    func makeUIView(context: Context) -> UIView {
        
        let view=SpectrogramUIView()
        let layer=AudioSpectrogram(audioSource: source)
        view.layer.addSublayer(layer)
        layer.frame=view.bounds
        
        return view
    }
    
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.setNeedsLayout()
    }
    
}

struct MelSpectrogramView:UIViewRepresentable{
    
    typealias UIViewType = UIView
    
    let source:AudioSource.Publisher
    
    func makeUIView(context: Context) -> UIView {
        
        let view=SpectrogramUIView()
        let layer=MelSpectrogram(audioSource: source)
        view.layer.addSublayer(layer)
        layer.frame=view.bounds
        
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
