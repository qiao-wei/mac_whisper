import Cocoa
import FlutterMacOS
@preconcurrency import AVFoundation

/// Plugin for audio extraction using native macOS AVFoundation APIs
class AudioExtractorPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.macwhisper/audio_extractor",
            binaryMessenger: registrar.messenger
        )
        let instance = AudioExtractorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "extractAudio":
            guard let args = call.arguments as? [String: Any],
                  let videoPath = args["videoPath"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing videoPath or outputPath", details: nil))
                return
            }
            extractAudio(videoPath: videoPath, outputPath: outputPath, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func extractAudio(videoPath: String, outputPath: String, result: @escaping FlutterResult) {
        let videoURL = URL(fileURLWithPath: videoPath)
        
        // Ensure output path has .wav extension
        let wavPath = outputPath.hasSuffix(".wav") ? outputPath : outputPath.replacingOccurrences(of: "\\.[^.]+$", with: ".wav", options: .regularExpression)
        let outputURL = URL(fileURLWithPath: wavPath)
        
        // Remove existing output file
        try? FileManager.default.removeItem(at: outputURL)
        
        let asset = AVAsset(url: videoURL)
        
        // Get audio tracks
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            result(FlutterError(code: "NO_AUDIO", message: "No audio track found in video", details: nil))
            return
        }
        
        do {
            // Create asset reader
            let reader = try AVAssetReader(asset: asset)
            
            // Output settings for reading - decompress to 16kHz mono 16-bit PCM
            let readerOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            
            let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerOutputSettings)
            readerOutput.alwaysCopiesSampleData = false
            
            guard reader.canAdd(readerOutput) else {
                result(FlutterError(code: "READER_ERROR", message: "Cannot add reader output", details: nil))
                return
            }
            reader.add(readerOutput)
            
            guard reader.startReading() else {
                result(FlutterError(code: "READER_ERROR", message: reader.error?.localizedDescription ?? "Failed to start reading", details: nil))
                return
            }
            
            // Collect all audio data
            var audioData = Data()
            while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                    var length = 0
                    var dataPointer: UnsafeMutablePointer<Int8>?
                    CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
                    if let dataPointer = dataPointer {
                        audioData.append(Data(bytes: dataPointer, count: length))
                    }
                }
            }
            
            // Write WAV file with header
            let wavData = createWavFile(audioData: audioData, sampleRate: 16000, channels: 1, bitsPerSample: 16)
            try wavData.write(to: outputURL)
            
            result(wavPath)
            
        } catch {
            result(FlutterError(code: "AUDIO_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func createWavFile(audioData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        var wavData = Data()
        
        let byteRate = sampleRate * channels * (bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = audioData.count
        let fileSize = 36 + dataSize
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt subchunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })  // Subchunk1Size
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // AudioFormat (PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })
        
        // data subchunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        wavData.append(audioData)
        
        return wavData
    }
}
