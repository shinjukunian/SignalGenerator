/*
See LICENSE folder for this sample’s licensing information.

Abstract:
MelSpectrogram extension for AVFoundation support.
*/

import AVFoundation

// MARK: AVCaptureAudioDataOutputSampleBufferDelegate and AVFoundation Support

extension MelSpectrogram: AVCaptureAudioDataOutputSampleBufferDelegate {
 
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {

        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
  
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout.stride(ofValue: audioBufferList),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer)
        
        guard let data = audioBufferList.mBuffers.mData else {
            return
        }

        if self.rawAudioData.count < MelSpectrogram.sampleCount * 2 {
            let actualSampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
            
            let ptr = data.bindMemory(to: Int16.self, capacity: actualSampleCount)
            let buf = UnsafeBufferPointer(start: ptr, count: actualSampleCount)

            rawAudioData.append(contentsOf: Array(buf))
        }

        dispatchSemaphore.wait()
        
        while self.rawAudioData.count >= MelSpectrogram.sampleCount {
            let dataToProcess = Array(self.rawAudioData[0 ..< MelSpectrogram.sampleCount])
            self.rawAudioData.removeFirst(MelSpectrogram.hopCount)
            self.processData(values: dataToProcess)
        }
     
        createAudioSpectrogram()
        
        dispatchSemaphore.signal()
    }
    
    func configureCaptureSession() {
          // Also note that:
          //
          // When running in iOS, you must add a "Privacy - Microphone Usage
          // Description" entry.
          //
          // When running in macOS, you must add a "Privacy - Microphone Usage
          // Description" entry to `Info.plist`, and check "audio input" and
          // "camera access" under the "Resource Access" category of "Hardened
          // Runtime".
          switch AVCaptureDevice.authorizationStatus(for: .audio) {
              case .authorized:
                      break
              case .notDetermined:
                  sessionQueue.suspend()
                  AVCaptureDevice.requestAccess(for: .audio,
                                                completionHandler: { granted in
                      if !granted {
                          fatalError("App requires microphone access.")
                      } else {
                          self.configureCaptureSession()
                          self.sessionQueue.resume()
                      }
                  })
                  return
              default:
                  // Users can add authorization in "Settings > Privacy > Microphone"
                  // on an iOS device, or "System Preferences > Security & Privacy >
                  // Microphone" on a macOS device.
                  fatalError("App requires microphone access.")
          }
          
          captureSession.beginConfiguration()
          
          #if os(macOS)
          // Note than in macOS, you can change the sample rate, for example to
          // `AVSampleRateKey: 22050`. This reduces the Nyquist frequency and
          // increases the resolution at lower frequencies.
          audioOutput.audioSettings = [
              AVFormatIDKey: kAudioFormatLinearPCM,
              AVLinearPCMIsFloatKey: false,
              AVLinearPCMBitDepthKey: 16,
              AVNumberOfChannelsKey: 1]
          #endif
          
          if captureSession.canAddOutput(audioOutput) {
              captureSession.addOutput(audioOutput)
          } else {
              fatalError("Can't add `audioOutput`.")
          }

          guard
              let microphone = AVCaptureDevice.default(.builtInMicrophone,
                                                       for: .audio,
                                                       position: .unspecified),
              let microphoneInput = try? AVCaptureDeviceInput(device: microphone) else {
                  fatalError("Can't create microphone.")
          }
          
          if captureSession.canAddInput(microphoneInput) {
              captureSession.addInput(microphoneInput)
          }
          
          captureSession.commitConfiguration()
      }
      
      /// Starts the audio spectrogram.
      func startRunning() {
          sessionQueue.async {
              if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                  self.captureSession.startRunning()
              }
          }
      }
  }
