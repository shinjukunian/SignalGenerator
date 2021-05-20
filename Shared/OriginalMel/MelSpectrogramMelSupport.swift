/*
See LICENSE folder for this sample’s licensing information.

Abstract:
MelSpectrogram extension for mel scale support.
*/

import Accelerate

extension MelSpectrogram {
    
    /// Populates the specified `filterBank` with a matrix of overlapping triangular windows.
    ///
    /// For each frequency in `melFilterBankFrequencies`, the function creates a row in `filterBank`
    /// that contains a triangular window starting at the previous frequency, having a response of `1` at the
    /// frequency, and ending at the next frequency.
    static func makeFilterBank(withFrequencyRange frequencyRange: ClosedRange<Float>,
                               sampleCount: Int,
                               filterBankCount: Int) -> UnsafeMutableBufferPointer<Float> {
        
        /// The `melFilterBankFrequencies` array contains `filterBankCount` elements
        /// that are indices of the `frequencyDomainBuffer`. The indices represent evenly spaced
        /// monotonically incrementing mel frequencies; that is, they're roughly logarithmically spaced as
        /// frequency in hertz.
        let melFilterBankFrequencies: [Int] = MelSpectrogram.populateMelFilterBankFrequencies(withFrequencyRange: frequencyRange,
                                                                                              filterBankCount: filterBankCount)
        
        let capacity = sampleCount * filterBankCount
        let filterBank = UnsafeMutableBufferPointer<Float>.allocate(capacity: capacity)
        filterBank.initialize(repeating: 0)
        
        var baseValue: Float = 1
        var endValue: Float = 0
        
        for i in 0 ..< melFilterBankFrequencies.count {
            
            let row = i * MelSpectrogram.sampleCount
            
            let startFrequency = melFilterBankFrequencies[ max(0, i - 1) ]
            let centerFrequency = melFilterBankFrequencies[ i ]
            let endFrequency = (i + 1) < melFilterBankFrequencies.count ?
                melFilterBankFrequencies[ i + 1 ] : sampleCount - 1
            
            let attackWidth = centerFrequency - startFrequency + 1
            let decayWidth = endFrequency - centerFrequency + 1
            
            // Create the attack phase of the triangle.
            if attackWidth > 0 {
                vDSP_vgen(&endValue,
                          &baseValue,
                          filterBank.baseAddress!.advanced(by: row + startFrequency),
                          1,
                          vDSP_Length(attackWidth))
            }
            
            // Create the decay phase of the triangle.
            if decayWidth > 0 {
                vDSP_vgen(&baseValue,
                          &endValue,
                          filterBank.baseAddress!.advanced(by: row + centerFrequency),
                          1,
                          vDSP_Length(decayWidth))
            }
        }
        
        return filterBank
    }

    /// Populates the specified `melFilterBankFrequencies` with a monotonically increasing series
    /// of indices into `frequencyDomainBuffer` that represent evenly spaced mels.
    static func populateMelFilterBankFrequencies(withFrequencyRange frequencyRange: ClosedRange<Float>,
                                                 filterBankCount: Int) -> [Int] {
        
        func frequencyToMel(_ frequency: Float) -> Float {
            return 2595 * log10(1 + (frequency / 700))
        }

        func melToFrequency(_ mel: Float) -> Float {
            return 700 * (pow(10, mel / 2595) - 1)
        }
        
        let minMel = frequencyToMel(frequencyRange.lowerBound)
        let maxMel = frequencyToMel(frequencyRange.upperBound)
        let bankWidth = (maxMel - minMel) / Float(filterBankCount - 1)

        let melFilterBankFrequencies: [Int] = stride(from: minMel, to: maxMel, by: bankWidth).map {
            let mel = Float($0)
            let frequency = melToFrequency(mel)

            return Int((frequency / frequencyRange.upperBound) * Float(MelSpectrogram.sampleCount))
        }
        
        return melFilterBankFrequencies
    }
}
