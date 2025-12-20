import Cocoa
import FlutterMacOS
@preconcurrency import AVFoundation
import CoreText

/// Plugin for merging subtitles into video using native macOS AVFoundation APIs
class SubtitleMergerPlugin: NSObject, FlutterPlugin {
    // Keep strong reference to export session to prevent deallocation during async export
    private var currentExportSession: AVAssetExportSession?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.macwhisper/subtitle_merger",
            binaryMessenger: registrar.messenger
        )
        let instance = SubtitleMergerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "mergeSubtitles":
            guard let args = call.arguments as? [String: Any],
                  let videoPath = args["videoPath"] as? String,
                  let outputPath = args["outputPath"] as? String,
                  let subtitles = args["subtitles"] as? [[String: Any]],
                  let fontConfig = args["fontConfig"] as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }
            mergeSubtitles(videoPath: videoPath, outputPath: outputPath, subtitles: subtitles, fontConfig: fontConfig, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func mergeSubtitles(videoPath: String, outputPath: String, subtitles: [[String: Any]], fontConfig: [String: Any], result: @escaping FlutterResult) {
        let videoURL = URL(fileURLWithPath: videoPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Remove existing output file
        try? FileManager.default.removeItem(at: outputURL)
        
        let asset = AVAsset(url: videoURL)
        
        // Get video and audio tracks
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            result(FlutterError(code: "NO_VIDEO", message: "No video track found", details: nil))
            return
        }
        
        let audioTrack = asset.tracks(withMediaType: .audio).first
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            result(FlutterError(code: "COMPOSITION_ERROR", message: "Failed to create video track", details: nil))
            return
        }
        
        do {
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: asset.duration),
                of: videoTrack,
                at: .zero
            )
        } catch {
            result(FlutterError(code: "VIDEO_INSERT_ERROR", message: error.localizedDescription, details: nil))
            return
        }
        
        // Add audio track if present
        if let audioTrack = audioTrack {
            if let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? compositionAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: asset.duration),
                    of: audioTrack,
                    at: .zero
                )
            }
        }
        
        // Get video size and apply transform
        let videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let renderSize = CGSize(width: abs(videoSize.width), height: abs(videoSize.height))
        
        // Parse font config
        let fontFamily = fontConfig["fontFamily"] as? String ?? "System Default"
        let baseFontSize = fontConfig["fontSize"] as? Double ?? 24.0
        let isBold = fontConfig["isBold"] as? Bool ?? false
        let fontColorValue = fontConfig["fontColor"] as? Int ?? 0xFFFFFFFF
        let positionIndex = fontConfig["position"] as? Int ?? 2 // 0=top, 1=center, 2=bottom
        let marginPercent = fontConfig["marginPercent"] as? Double ?? 5.0
        
        // Scale font size relative to video height
        // In Flutter preview, the video is typically displayed at ~400px height
        // So we scale the font size proportionally to the actual video height
        let previewHeight: CGFloat = 400.0
        let scaleFactor = renderSize.height / previewHeight
        let scaledFontSize = CGFloat(baseFontSize) * scaleFactor
        
        // Convert color
        let alpha = CGFloat((fontColorValue >> 24) & 0xFF) / 255.0
        let red = CGFloat((fontColorValue >> 16) & 0xFF) / 255.0
        let green = CGFloat((fontColorValue >> 8) & 0xFF) / 255.0
        let blue = CGFloat(fontColorValue & 0xFF) / 255.0
        let fontColor = CGColor(red: red, green: green, blue: blue, alpha: alpha)
        
        // Create parent layer for animation
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)
        
        // Create subtitle layers with animations
        let subtitleParentLayer = CALayer()
        subtitleParentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(subtitleParentLayer)
        
        // Calculate margin in pixels from percentage
        let marginPixels = renderSize.height * CGFloat(marginPercent / 100.0)
        
        // Create font with scaled size
        var font: NSFont
        if fontFamily == "System Default" {
            font = isBold ? NSFont.boldSystemFont(ofSize: scaledFontSize) : NSFont.systemFont(ofSize: scaledFontSize)
        } else {
            if isBold {
                font = NSFont(name: "\(fontFamily) Bold", size: scaledFontSize) ?? NSFont.boldSystemFont(ofSize: scaledFontSize)
            } else {
                font = NSFont(name: fontFamily, size: scaledFontSize) ?? NSFont.systemFont(ofSize: scaledFontSize)
            }
        }
        
        // Add each subtitle as an animated text layer
        for subtitle in subtitles {
            guard let text = subtitle["text"] as? String,
                  let startTime = subtitle["startTime"] as? Double,
                  let endTime = subtitle["endTime"] as? Double else {
                continue
            }
            
            // Calculate text size first to determine container dimensions
            let maxWidth = renderSize.width - 80 * scaleFactor
            let textSize = (text as NSString).boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).size
            
            // Padding similar to Flutter preview (horizontal: 16, vertical: 1)
            let horizontalPadding: CGFloat = 16 * scaleFactor
            let verticalPadding: CGFloat = 1 * scaleFactor
            
            // Calculate line height and dimensions
            let singleLineHeight = font.ascender + abs(font.descender) + font.leading
            let numberOfLines = max(1, Int(ceil(textSize.height / singleLineHeight)))
            let contentHeight = max(textSize.height, singleLineHeight * CGFloat(numberOfLines))
            
            let containerWidth = textSize.width + horizontalPadding * 2
            let containerHeight = contentHeight + verticalPadding * 1
            
            // Calculate Y position based on position setting
            // CALayer uses bottom-left origin (y=0 is bottom)
            let yPosition: CGFloat
            switch positionIndex {
            case 0: // top
                yPosition = renderSize.height - marginPixels - containerHeight
            case 1: // center
                yPosition = (renderSize.height - containerHeight) / 2
            default: // bottom
                yPosition = marginPixels
            }
            
            // Create container layer for background
            let textContainerLayer = CALayer()
            textContainerLayer.frame = CGRect(
                x: (renderSize.width - containerWidth) / 2,
                y: yPosition,
                width: containerWidth,
                height: containerHeight
            )
            textContainerLayer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.54)
            textContainerLayer.cornerRadius = 4.0 * scaleFactor // Match Flutter preview radius
            
            // Create text layer
            let textLayer = CATextLayer()
            textLayer.string = text
            textLayer.font = font
            textLayer.fontSize = scaledFontSize
            textLayer.foregroundColor = fontColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = 2.0
            textLayer.isWrapped = true
            
            // Center text in container - account for contentHeight vs textSize.height difference
            let textY = verticalPadding + (contentHeight - textSize.height) / 2
            textLayer.frame = CGRect(
                x: horizontalPadding,
                y: textY,
                width: textSize.width,
                height: textSize.height
            )
            
            // Create opacity animation to show/hide subtitle
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            let videoDuration = CMTimeGetSeconds(asset.duration)
            
            // Calculate keyframes - handle edge cases for early/late subtitles
            let startNormalized = startTime / videoDuration
            let endNormalized = endTime / videoDuration
            
            // Build keyframes dynamically to avoid duplicate/near-duplicate values
            var keyTimes: [NSNumber] = []
            var values: [Float] = []
            
            // If subtitle starts after the beginning, add initial invisible state
            if startNormalized > 0.002 {
                keyTimes.append(0.0)
                keyTimes.append(NSNumber(value: startNormalized - 0.001))
                values.append(0.0)
                values.append(0.0)
            } else {
                // Subtitle starts at or near beginning - start visible
                keyTimes.append(0.0)
                values.append(1.0)
            }
            
            // Visible during subtitle display
            keyTimes.append(NSNumber(value: max(0.001, startNormalized)))
            values.append(1.0)
            keyTimes.append(NSNumber(value: min(0.999, endNormalized)))
            values.append(1.0)
            
            // If subtitle ends before the end, add final invisible state
            if endNormalized < 0.998 {
                keyTimes.append(NSNumber(value: endNormalized + 0.001))
                keyTimes.append(1.0)
                values.append(0.0)
                values.append(0.0)
            } else {
                // Subtitle ends at or near the end - stay visible
                keyTimes.append(1.0)
                values.append(1.0)
            }
            
            animation.keyTimes = keyTimes
            animation.values = values
            animation.duration = videoDuration
            animation.beginTime = AVCoreAnimationBeginTimeAtZero
            animation.isRemovedOnCompletion = false
            animation.fillMode = .both
            
            // Apply animation to container layer
            textContainerLayer.add(animation, forKey: "opacity")
            textContainerLayer.opacity = 0
            
            // Add layers
            textContainerLayer.addSublayer(textLayer)
            subtitleParentLayer.addSublayer(textContainerLayer)
        }
        
        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        
        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        
        // Apply video transform to handle rotation
        layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // Export
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            result(FlutterError(code: "EXPORT_ERROR", message: "Failed to create export session", details: nil))
            return
        }
        
        // Store in instance property to prevent deallocation
        self.currentExportSession = exportSession
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        exportSession.exportAsynchronously { [self] in
            DispatchQueue.main.async { [self] in
                let status = self.currentExportSession?.status ?? .unknown
                let error = self.currentExportSession?.error
                
                // Clear the reference after completion
                defer { self.currentExportSession = nil }
                
                switch status {
                case .completed:
                    result(outputPath)
                case .failed:
                    result(FlutterError(code: "EXPORT_FAILED", message: error?.localizedDescription ?? "Unknown error", details: nil))
                case .cancelled:
                    result(FlutterError(code: "EXPORT_CANCELLED", message: "Export was cancelled", details: nil))
                default:
                    result(FlutterError(code: "EXPORT_UNKNOWN", message: "Unknown export status", details: nil))
                }
            }
        }
    }
}
