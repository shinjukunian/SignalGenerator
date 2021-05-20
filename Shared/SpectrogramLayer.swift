//
//  SpectrogramLayer.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/20.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import Accelerate
import Combine

class SpectrogramLayer: CALayer {
    
    var rgbImageFormat: vImage_CGImageFormat = {
        guard let format = vImage_CGImageFormat(
                bitsPerComponent: 8,
                bitsPerPixel: 8 * 4,
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                renderingIntent: .defaultIntent) else {
            fatalError("Can't create image format.")
        }
        
        return format
    }()
    
    /// RGB vImage buffer that contains a vertical representation of the audio spectrogram.
    lazy var rgbImageBuffer: vImage_Buffer = {
        guard let buffer = try? vImage_Buffer(width: SpectrumAnalyzer.sampleCount,
                                              height: SpectrumAnalyzer.bufferCount,
                                              bitsPerPixel: rgbImageFormat.bitsPerPixel) else {
            fatalError("Unable to initialize image buffer.")
        }
        return buffer
    }()
    
    /// RGB vImage buffer that contains a horizontal representation of the audio spectrogram.
    lazy var rotatedImageBuffer: vImage_Buffer = {
        guard let buffer = try? vImage_Buffer(width: SpectrumAnalyzer.bufferCount,
                                              height: SpectrumAnalyzer.sampleCount,
                                              bitsPerPixel: rgbImageFormat.bitsPerPixel)  else {
            fatalError("Unable to initialize rotated image buffer.")
        }
        return buffer
    }()
    
    
    // Lookup tables for color transforms.
    static var redTable: [Pixel_8] = (0 ... 255).map {
        return brgValue(from: $0).red
    }
    
    static var greenTable: [Pixel_8] = (0 ... 255).map {
        return brgValue(from: $0).green
    }
    
    static var blueTable: [Pixel_8] = (0 ... 255).map {
        return brgValue(from: $0).blue
    }
    
    
    
    var frequencyDomainValues = [Float](repeating: 0,
                                        count: SpectrumAnalyzer.bufferCount * SpectrumAnalyzer.sampleCount)
     
    var subScription:AnyCancellable?
    
    init(analyzer:SpectrumAnalyzer) {
        super.init()
        contentsGravity = .resize
        self.subscribe(to: analyzer)
    }
    
    func subscribe(to analyzer:SpectrumAnalyzer){
        self.subScription=analyzer.frequencies.sink(receiveValue: {[weak self]v in
            self?.frequencyDomainValues=v
            self?.createAudioSpectrogram()
        })
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        rgbImageBuffer.free()
        rotatedImageBuffer.free()
    }
    
    
    var maxFloat: Float = {
        var maxValue = [Float(Int16.max)]
        vDSP.convert(amplitude: maxValue,
                     toDecibels: &maxValue,
                     zeroReference: Float(SpectrumAnalyzer.sampleCount))
        return maxValue[0] * 2
    }()

    
    
    func createAudioSpectrogram() {
        let maxFloats: [Float] = [255, maxFloat, maxFloat, maxFloat]
        let minFloats: [Float] = [255, 0, 0, 0]
        
        self.frequencyDomainValues.withUnsafeMutableBufferPointer {
            var planarImageBuffer = vImage_Buffer(data: $0.baseAddress!,
                                                  height: vImagePixelCount(SpectrumAnalyzer.bufferCount),
                                                  width: vImagePixelCount(SpectrumAnalyzer.sampleCount),
                                                  rowBytes: SpectrumAnalyzer.sampleCount * MemoryLayout<Float>.stride)
            
            vImageConvert_PlanarFToARGB8888(&planarImageBuffer,
                                            &planarImageBuffer, &planarImageBuffer, &planarImageBuffer,
                                            &rgbImageBuffer,
                                            maxFloats, minFloats,
                                            vImage_Flags(kvImageNoFlags))
        }
        
        vImageTableLookUp_ARGB8888(&rgbImageBuffer, &rgbImageBuffer,
                                   nil,
                                   &SpectrogramLayer.redTable,
                                   &SpectrogramLayer.greenTable,
                                   &SpectrogramLayer.blueTable,
                                   vImage_Flags(kvImageNoFlags))
        
        vImageRotate90_ARGB8888(&rgbImageBuffer,
                                &rotatedImageBuffer,
                                UInt8(kRotate90DegreesCounterClockwise),
                                [UInt8()],
                                vImage_Flags(kvImageNoFlags))
        
        if let image = try? rotatedImageBuffer.createCGImage(format: rgbImageFormat) {
            DispatchQueue.main.async {
                self.contents = image
            }
        }
    }
    
}
