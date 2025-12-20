import Cocoa
import FlutterMacOS
@preconcurrency import AVFoundation
import CoreText

/// Plugin for merging subtitles into video using native macOS AVFoundation APIs
class SubtitleMergerPlugin: NSObject, FlutterPlugin {
    // Keep strong reference to export session to prevent deallocation during async export
    private var currentExportSession: AVAssetExportSession?
    private var channel: FlutterMethodChannel?
    private var progressTimer: Timer?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.macwhisper/subtitle_merger",
            binaryMessenger: registrar.messenger
        )
        let instance = SubtitleMergerPlugin()
        instance.channel = channel
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
        // Background settings
        let bgColorValue = fontConfig["bgColor"] as? Int ?? 0xFF000000
        let bgPadding = fontConfig["bgPadding"] as? Double ?? 4.0
        let bgCornerRadius = fontConfig["bgCornerRadius"] as? Double ?? 4.0
        let bgOpacity = fontConfig["bgOpacity"] as? Double ?? 0.54

        // Convert background color (ARGB format)
        let bgRed = CGFloat((bgColorValue >> 16) & 0xFF) / 255.0
        let bgGreen = CGFloat((bgColorValue >> 8) & 0xFF) / 255.0
        let bgBlue = CGFloat(bgColorValue & 0xFF) / 255.0
        
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

            // Apply line height multiplier to match Flutter's default behavior (1.2x)
            let lineHeightMultiplier: CGFloat = 1.2
            let adjustedTextHeight = textSize.height * lineHeightMultiplier

            // Padding - use settings from config
            let horizontalPadding: CGFloat = 16 * scaleFactor
            let verticalPadding: CGFloat = CGFloat(bgPadding) * scaleFactor

            let containerWidth = textSize.width + horizontalPadding * 2
            let containerHeight = adjustedTextHeight + verticalPadding * 2

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
            textContainerLayer.backgroundColor = CGColor(red: bgRed, green: bgGreen, blue: bgBlue, alpha: CGFloat(bgOpacity))
            textContainerLayer.cornerRadius = CGFloat(bgCornerRadius) * scaleFactor
            
            // Create text layer
            let textLayer = CATextLayer()
            textLayer.string = text
            textLayer.font = font
            textLayer.fontSize = scaledFontSize
            textLayer.foregroundColor = fontColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = 2.0
            textLayer.isWrapped = true
            
            // Position text in container - center vertically in the adjusted height
            let textY = verticalPadding + (adjustedTextHeight - textSize.height) / 2
            textLayer.frame = CGRect(
                x: horizontalPadding,
                y: textY,
                width: textSize.width,
                height: textSize.height
            )
            
            // Create opacity animation to show/hide subtitle
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            let videoDuration = CMTimeGetSeconds(asset.duration)

            // Add 100ms delay before showing subtitle
            let adjustedStartTime = startTime + 0.1

            // Calculate normalized times
            let startNormalized = adjustedStartTime / videoDuration
            let endNormalized = endTime / videoDuration

            // Simple keyframes: invisible before start, visible during, invisible after
            animation.keyTimes = [0.0, NSNumber(value: startNormalized), NSNumber(value: endNormalized), 1.0]
            animation.values = [0.0, 1.0, 0.0, 0.0]
            animation.duration = videoDuration
            animation.beginTime = AVCoreAnimationBeginTimeAtZero
            animation.isRemovedOnCompletion = false
            animation.fillMode = .forwards
            animation.calculationMode = .discrete
            
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
            // Stop progress timer
            self.progressTimer?.invalidate()
            self.progressTimer = nil

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

        // Start progress monitoring
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.currentExportSession else { return }
            let progress = Double(session.progress)
            DispatchQueue.main.async {
                self.channel?.invokeMethod("onProgress", arguments: ["progress": progress])
            }
        }
    }
}
