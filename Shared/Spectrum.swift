//
//  Spectrum.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/06/07.
//

import Foundation
import SwiftUI
import Accelerate

struct Spectrum:Shape{
    
    let samples:[Double]
    let autoScale:Bool
    init(samples:[Double], autoScale:Bool = true) {
        let filterLength=2
        let filter = [Double](repeating: 1 / Double(filterLength),
                             count: Int(filterLength))
        self.samples=vDSP.downsample(samples, decimationFactor: 2, filter: filter)
        self.autoScale=autoScale
    }
    
    func path(in rect: CGRect) -> Path {
        let max:Double
        let min:Double
        
        if autoScale{
            max=vDSP.maximum(samples)
            min=vDSP.minimum(samples)
        }
        else{
            max=Double(Int16.max)
            min=Double(Int16.min)
        }
        
        let deltaX = rect.width / CGFloat(samples.count)
        let scaleY = CGFloat(max - min) / rect.height
        
        guard scaleY.isNormal, deltaX.isNormal else{return Path()}
        
        return Path({ path in
            guard let first=samples.first else {return}
            
            path.move(to: CGPoint(x: 0, y:  CGFloat(first-min) /  scaleY))
            samples.dropFirst().enumerated().forEach({(idx, sample) in
                path.addLine(to: CGPoint(x: deltaX * CGFloat(idx), y: CGFloat(sample-min) / scaleY))
            })
            
        })
    }
    
}

