/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Class that generates a spectrogram from an audio signal.
*/
import AVFoundation
import Accelerate


public class MelSpectrogram: CALayer {
    
    // MARK: Initialization
    
    override init() {
        super.init()
        
        contentsGravity = .resize
        
        // Set the `magnificationFilter` to `.nearest` to render the mel
        // spectrogram as discrete bands.
        magnificationFilter = .nearest
        
        configureCaptureSession()
        audioOutput.setSampleBufferDelegate(self,
                                            queue: captureQueue)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    // MARK: Properties
    /// The number of audio samples per frame.
    static let sampleCount = 1024
    
    /// Determines the overlap between frames.
    static let hopCount = sampleCount / 2
    
    /// Number of displayed buffers — the width of the spectrogram.
    static let bufferCount = 768
    
    /// The number of mel filter banks  — the height of the spectrogram.
    static let filterBankCount = 40
    
    let captureSession = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    let captureQueue = DispatchQueue(label: "captureQueue",
                                     qos: .userInitiated,
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)
    let sessionQueue = DispatchQueue(label: "sessionQueue",
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)

    /// Temporary buffers that the FFT operation uses for storing interim results.
    static var fftRealBuffer = [Float](repeating: 0, count: sampleCount / 2)
    static var fftImagBuffer = [Float](repeating: 0, count: sampleCount / 2)

    /// The forward fast Fourier transform object.
    static let fft: FFTSetup = {
        let log2n = vDSP_Length(log2(Float(sampleCount)))
        
        guard let fft = vDSP_create_fftsetup(log2n,
                                             FFTRadix(kFFTRadix2)) else {
            fatalError("Unable to create FFT.")
        }
        
        return fft
    }()

    /// The window sequence used to reduce spectral leakage.
    static let hanningWindow = vDSP.window(ofType: Float.self,
                                           usingSequence: .hanningDenormalized,
                                           count: sampleCount,
                                           isHalfWindow: false)

    let dispatchSemaphore = DispatchSemaphore(value: 1)
    
    /// A buffer that contains the raw audio data from AVFoundation.
    var rawAudioData = [Int16]()
    
    /// An array that contains the entire spectrogram.
    var melSpectrumValues = [Float](repeating: 0,
                                    count: bufferCount * filterBankCount)

    /// The vImage `CGImage` format that describes the output image.
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
    
    /// The RGB vImage buffer that contains a vertical representation of the audio spectrogram.
    lazy var rgbImageBuffer: vImage_Buffer = {
        guard let buffer = try? vImage_Buffer(width: MelSpectrogram.filterBankCount,
                                              height: MelSpectrogram.bufferCount,
                                              bitsPerPixel: rgbImageFormat.bitsPerPixel) else {
            fatalError("Unable to initialize image buffer.")
        }
        return buffer
    }()
    
    /// The RGB vImage buffer that contains a horizontal representation of the audio spectrogram.
    lazy var rotatedImageBuffer: vImage_Buffer = {
        guard let buffer = try? vImage_Buffer(width: MelSpectrogram.bufferCount,
                                              height: MelSpectrogram.filterBankCount,
                                              bitsPerPixel: rgbImageFormat.bitsPerPixel)  else {
            fatalError("Unable to initialize rotated image buffer.")
        }
        return buffer
    }()
    
    deinit {
        rgbImageBuffer.free()
        rotatedImageBuffer.free()
    }
    
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
    
    /// A reusable array that contains the current frame of time domain audio data as single-precision
    /// values.
    var timeDomainBuffer = [Float](repeating: 0,
                                   count: sampleCount)
    
    /// A resuable array that contains the frequency domain representation of the current frame of
    /// audio data.
    var frequencyDomainBuffer = [Float](repeating: 0,
                                        count: sampleCount)
    
    /// A matrix of `filterBankCount` rows and `sampleCount` that contains the triangular overlapping
    /// windows for each mel frequency.
    let filterBank = MelSpectrogram.makeFilterBank(withFrequencyRange: 20 ... 20_000,
                                                   sampleCount: MelSpectrogram.sampleCount,
                                                   filterBankCount: MelSpectrogram.filterBankCount)
    
    static let signalCount = 1
    /// A buffer that contains the matrix multiply result of the current frame of frequency domain values in
    /// `frequencyDomainBuffer` multiplied by the `filterBank` matrix.
    let sgemmResult = UnsafeMutableBufferPointer<Float>.allocate(capacity: MelSpectrogram.signalCount * Int(MelSpectrogram.filterBankCount))
    
    /// Process a frame of raw audio data:
    ///
    /// 1. Convert the `Int16` time-domain audio values to `Float`.
    /// 2. Perform a forward DFT on the time-domain values.
    /// 3. Multiply the `frequencyDomainBuffer` vector by the `filterBank` matrix
    /// to generate `sgemmResult` product.
    /// 4. Convert the matrix multiply results to decibels.
    ///
    /// The matrix multiply effectively creates a  vector of `filterBankCount` elements that summarises
    /// the `sampleCount` frequency-domain values.  For example, given a vector of four frequency-domain
    /// values:
    /// ```
    ///  [ 1, 2, 3, 4 ]
    /// ```
    /// And a filter bank of three filters with the following values:
    /// ```
    ///  [ 0.5, 0.5, 0.0, 0.0,
    ///    0.0, 0.5, 0.5, 0.0,
    ///    0.0, 0.0, 0.5, 0.5 ]
    /// ```
    /// The result contains three values of:
    /// ```
    ///  [ ( 1 * 0.5 + 2 * 0.5) = 1.5,
    ///     (2 * 0.5 + 3 * 0.5) = 2.5,
    ///     (3 * 0.5 + 4 * 0.5) = 3.5 ]
    /// ```
    func processData(values: [Int16]) {
 
        vDSP.convertElements(of: values,
                             to: &timeDomainBuffer)

        MelSpectrogram.performForwardDFT(timeDomainValues: &timeDomainBuffer,
                                         frequencyDomainValues: &frequencyDomainBuffer,
                                         temporaryRealBuffer: &realParts,
                                         temporaryImaginaryBuffer: &imaginaryParts)
        
        vDSP.absolute(frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        frequencyDomainBuffer.withUnsafeBufferPointer { frequencyDomainValuesPtr in
            cblas_sgemm(CblasRowMajor,
                        CblasTrans, CblasTrans,
                        Int32(MelSpectrogram.signalCount),
                        Int32(MelSpectrogram.filterBankCount),
                        Int32(MelSpectrogram.sampleCount),
                        1,
                        frequencyDomainValuesPtr.baseAddress, Int32(MelSpectrogram.signalCount),
                        filterBank.baseAddress, Int32(MelSpectrogram.sampleCount),
                        0,
                        sgemmResult.baseAddress, Int32(MelSpectrogram.filterBankCount))
        }
        
        vDSP_vdbcon(sgemmResult.baseAddress!, 1,
                    [20_000],
                    sgemmResult.baseAddress!, 1,
                    vDSP_Length(sgemmResult.count),
                    0)
 
        // Scroll the values in `melSpectrumValues` by removing the first
        // `filterBankCount` values and appending the `filterBankCount` elements
        // in `sgemmResult`.
        if melSpectrumValues.count > MelSpectrogram.filterBankCount {
            melSpectrumValues.removeFirst(MelSpectrogram.filterBankCount)
        }
        melSpectrumValues.append(contentsOf: sgemmResult)
    }
    
    /// The real parts of the time- and frequency-domain representations (the code performs DFT in-place)
    /// of the current frame of audio.
    var realParts = [Float](repeating: 0,
                            count: sampleCount / 2)
    
    /// The imaginary parts of the time- and frequency-domain representations (the code performs DFT
    /// in-place) of the current frame of audio.
    var imaginaryParts = [Float](repeating: 0,
                                 count: sampleCount / 2)
    
    /// Performs a forward Fourier transform on interleaved `timeDomainValues` writing the result to
    /// interleaved `frequencyDomainValues`.
    static func performForwardDFT(timeDomainValues: inout [Float],
                                  frequencyDomainValues: inout [Float],
                                  temporaryRealBuffer: inout [Float],
                                  temporaryImaginaryBuffer: inout [Float]) {
        
        vDSP.multiply(timeDomainValues,
                      hanningWindow,
                      result: &timeDomainValues)
        
        // Populate split real and imaginary arrays with the interleaved values
        // in `timeDomainValues`.
        temporaryRealBuffer.withUnsafeMutableBufferPointer { realPtr in
            temporaryImaginaryBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                   imagp: imagPtr.baseAddress!)
                
                timeDomainValues.withUnsafeBytes {
                    vDSP_ctoz($0.bindMemory(to: DSPComplex.self).baseAddress!, 2,
                              &splitComplex, 1,
                              vDSP_Length(MelSpectrogram.sampleCount / 2))
                }
            }
        }
        
        // Perform forward transform.
        temporaryRealBuffer.withUnsafeMutableBufferPointer { realPtr in
            temporaryImaginaryBuffer.withUnsafeMutableBufferPointer { imagPtr in
                fftRealBuffer.withUnsafeMutableBufferPointer { realBufferPtr in
                    fftImagBuffer.withUnsafeMutableBufferPointer { imagBufferPtr in
                        var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                           imagp: imagPtr.baseAddress!)
                        
                        var bufferSplitComplex = DSPSplitComplex(realp: realBufferPtr.baseAddress!,
                                                                 imagp: imagBufferPtr.baseAddress!)
                        
                        let log2n = vDSP_Length(log2(Float(sampleCount)))
                        
                        vDSP_fft_zript(fft,
                                       &splitComplex, 1,
                                       &bufferSplitComplex,
                                       log2n,
                                       FFTDirection(kFFTDirection_Forward))
                    }
                }
            }
        }
        
        // Populate interleaved `frequencyDomainValues` with the split values
        // from the real and imaginary arrays.
        temporaryRealBuffer.withUnsafeMutableBufferPointer { realPtr in
            temporaryImaginaryBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                   imagp: imagPtr.baseAddress!)
                
                frequencyDomainValues.withUnsafeMutableBytes { ptr in
                    vDSP_ztoc(&splitComplex, 1,
                              ptr.bindMemory(to: DSPComplex.self).baseAddress!, 2,
                              vDSP_Length(MelSpectrogram.sampleCount / 2))
                }
            }
        }
    }
    
    /// Creates an audio spectrogram `CGImage` from `melSpectrumValues` and renders it
    /// to the `spectrogramLayer` layer.
    func createAudioSpectrogram() {
        let maxFloat = sqrt(Float(MelSpectrogram.sampleCount))

        let maxFloats: [Float] = [255, maxFloat, maxFloat, maxFloat]
        let minFloats: [Float] = [255, 0, 0, 0]
        
        melSpectrumValues.withUnsafeMutableBufferPointer {
            var planarImageBuffer = vImage_Buffer(data: $0.baseAddress!,
                                                  height: vImagePixelCount(MelSpectrogram.bufferCount),
                                                  width: vImagePixelCount(MelSpectrogram.filterBankCount),
                                                  rowBytes: MelSpectrogram.filterBankCount * MemoryLayout<Float>.stride)
            
            vImageConvert_PlanarFToARGB8888(&planarImageBuffer,
                                            &planarImageBuffer, &planarImageBuffer, &planarImageBuffer,
                                            &rgbImageBuffer,
                                            maxFloats, minFloats,
                                            vImage_Flags(kvImageNoFlags))
        }

        vImageTableLookUp_ARGB8888(&rgbImageBuffer, &rgbImageBuffer,
                                   nil,
                                   &MelSpectrogram.redTable,
                                   &MelSpectrogram.greenTable,
                                   &MelSpectrogram.blueTable,
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

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

// MARK: Utility functions
extension MelSpectrogram {
    
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
