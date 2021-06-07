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
        
        let deltaX = Double(rect.width) / Double(samples.count)
        let scaleY = Double(max - min) / Double(rect.height)
        
        guard scaleY.isNormal, deltaX.isNormal, samples.count > 0 else{return Path()}
        
        let subtracted=vDSP.add(-min, samples)
        let scaled=vDSP.divide(subtracted, scaleY)
        
        return Path({ path in
            guard let first=scaled.first else {return}
            
            path.move(to: CGPoint(x: 0, y: first))
                      
            scaled.dropFirst().enumerated().forEach({(idx, sample) in
                path.addLine(to: CGPoint(x: deltaX * Double(idx), y: sample))
            })
            
        })
    }
    
}

