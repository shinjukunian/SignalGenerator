//
//  SpectrogramLayer+Utility.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/20.
//

import Foundation
import Accelerate
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: Utility functions
extension SpectrogramLayer {
    
    /// Returns the RGB values from a blue -> red -> green color map for a specified value.
    ///
    /// `value` controls hue and brightness. Values near zero return dark blue, `127` returns red, and
    ///  `255` returns full-brightness green.
    #if os(iOS)
    typealias Color = UIColor
    #else
    typealias Color = NSColor
    #endif
    
    static func brgValue(from value: Pixel_8) -> (red: Pixel_8,
                                                  green: Pixel_8,
                                                  blue: Pixel_8) {
        let normalizedValue = CGFloat(value) / 255
        
        // Define `hue` that's blue at `0.0` to red at `1.0`.
        let hue = 0.6666 - (0.6666 * normalizedValue)
        let brightness = sqrt(normalizedValue)

        let color = Color(hue: hue,
                          saturation: 1,
                          brightness: brightness,
                          alpha: 1)
        
        var red = CGFloat()
        var green = CGFloat()
        var blue = CGFloat()
        
        color.getRed(&red,
                     green: &green,
                     blue: &blue,
                     alpha: nil)
        
        return (Pixel_8(green * 255),
                Pixel_8(red * 255),
                Pixel_8(blue * 255))
    }
}
