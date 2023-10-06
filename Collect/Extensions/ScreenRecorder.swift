//
//  ScreenCaptureKit-Recording-example
//
//  Created by Tom Lokhorst on 2023-01-18.
//

import AVFoundation
import CoreGraphics
import ScreenCaptureKit
import SwiftUI
struct ScreenRecorder {
    private let videoSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.VideoSampleBufferQueue")

    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let streamOutput: StreamOutput
    private var stream: SCStream

    init(url: URL, displayID: CGDirectDisplayID, cropRect: CGRect?) async throws {

        // Create AVAssetWriter for a QuickTime movie file
        self.assetWriter = try AVAssetWriter(url: url, fileType: .mov)


        // MARK: AVAssetWriter setup

        // Get size and pixel scale factor for display
        // Used to compute the highest possible qualitiy
        let displaySize = CGDisplayBounds(displayID).size

        // The number of physical pixels that represent a logic point on screen, currently 2 for MacBook Pro retina displays
        let displayScaleFactor: Int
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            displayScaleFactor = mode.pixelWidth / mode.width
        } else {
            displayScaleFactor = 1
        }

        print("displayScaleFactor \(displayScaleFactor.description)")

        // AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
        // Downsize to fit a larger display back into in 4K
        let videoSize = downsizedVideoSize(source: cropRect?.size ?? displaySize, scaleFactor: displayScaleFactor)

//        var outputSettings = AVCaptureVideoDataOutput().recommendedVideoSettings(forVideoCodecType: .h264, assetWriterOutputFileType: .mov, outputFileURL: url)

        // This preset is the maximum H.264 preset, at the time of writing this code
        // Make this as large as possible, size will be reduced to screen size by computed videoSize
        guard let assistant = AVOutputSettingsAssistant(preset: .hevc7680x4320) else {
            throw RecordingError("Can't create AVOutputSettingsAssistant with .preset3840x2160")
        }
        assistant.sourceVideoFormat = try CMVideoFormatDescription(videoCodecType: .h264, width: videoSize.width/2, height: videoSize.height/2)

        guard var outputSettings = assistant.videoSettings else {
            throw RecordingError("AVOutputSettingsAssistant has no videoSettings")
        }

        print(outputSettings)
        // set resolution
        outputSettings[AVVideoWidthKey] = videoSize.width
        outputSettings[AVVideoHeightKey] = videoSize.height
//        outputSettings[AVVideoWidthKey] = videoSize.width
//        outputSettings[AVVideoHeightKey] = videoSize.height]

        // Create AVAssetWriter input for video, based on the output settings from the Assistant
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        videoInput.expectsMediaDataInRealTime = true
        videoInput.naturalSize = cropRect?.size ?? displaySize
        print(cropRect?.size ?? displaySize)
        streamOutput = StreamOutput(videoInput: videoInput)

        // Adding videoInput to assetWriter
        guard assetWriter.canAdd(videoInput) else {
            throw RecordingError("Can't add input to asset writer")
        }
        assetWriter.add(videoInput)

        guard assetWriter.startWriting() else {
            if let error = assetWriter.error {
                throw error
            }
            throw RecordingError("Couldn't start writing to AVAssetWriter")
        }

        // MARK: SCStream setup

        // Create a filter for the specified display
        let sharableContent = try await SCShareableContent.current
        guard let display = sharableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw RecordingError("Can't find display with ID \(displayID) in sharable content")
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let configuration = SCStreamConfiguration()
//        configuration.queueDepth = 5
//        configuration.queueDepth = 6


        // Make sure to take displayScaleFactor into account
        // otherwise, image is scaled up and gets blurry
        if let cropRect = cropRect {
            // ScreenCaptureKit uses top-left of screen as origin
            configuration.sourceRect = cropRect

            let width = (Int(cropRect.width) * displayScaleFactor)
            let height = (Int(cropRect.height) * displayScaleFactor)

            configuration.width = width / 2
            configuration.height = height / 2
//            configuration.captureResolution = .best

            configuration.destinationRect = CGRect(origin: .zero, size: CGSize(width: width, height: height))

//            configuration.width = (Int(cropRect.width) * displayScaleFactor)
//            configuration.height = (Int(cropRect.height) * displayScaleFactor)

//            configuration.destinationRect = cropRect
//            configuration.destinationRect = CGRect(
//                x: (Int(cropRect.minX) * displayScaleFactor),
//                y: (Int(cropRect.minY) * displayScaleFactor),
//                width: (Int(cropRect.width) * displayScaleFactor),
//                height: (Int(cropRect.height) * displayScaleFactor)
//            )
        } else {
            configuration.width = (Int(displaySize.width) * displayScaleFactor)
            configuration.height = (Int(displaySize.height) * displayScaleFactor)
        }

        // Set the capture interval at 60 fps.
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)

//        // Set color space and matrix to sRGB
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.colorMatrix = CGDisplayStream.yCbCrMatrix_ITU_R_709_2
//        configuration.captureResolution = .best
        configuration.showsCursor = true
//        configuration.destinationRect = cropRect ?? CGRect(origin: .zero, size: displaySize)
//        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
//        configuration.scalesToFit = true


        // Create SCStream and add local StreamOutput object to receive samples
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
    }

    func start() async throws {

        // Start capturing, wait for stream to start
        try await stream.startCapture()

        // Start the AVAssetWriter session at source time .zero, sample buffers will need to be re-timed
        assetWriter.startSession(atSourceTime: .zero)
        streamOutput.sessionStarted = true
    }

    func stop() async throws {

        // Stop capturing, wait for stream to stop
        try await stream.stopCapture()

        // Repeat the last frame and add it at the current time
        // In case no changes happend on screen, and the last frame is from long ago
        // This ensures the recording is of the expected length
        if let originalBuffer = streamOutput.lastSampleBuffer {
            let additionalTime = CMTime(seconds: ProcessInfo.processInfo.systemUptime, preferredTimescale: 100) - streamOutput.firstSampleTime
            let timing = CMSampleTimingInfo(duration: originalBuffer.duration, presentationTimeStamp: additionalTime, decodeTimeStamp: originalBuffer.decodeTimeStamp)
            let additionalSampleBuffer = try CMSampleBuffer(copying: originalBuffer, withNewTiming: [timing])
            videoInput.append(additionalSampleBuffer)
            streamOutput.lastSampleBuffer = additionalSampleBuffer
        }

        // Stop the AVAssetWriter session at time of the repeated frame
        assetWriter.endSession(atSourceTime: streamOutput.lastSampleBuffer?.presentationTimeStamp ?? .zero)

        // Finish writing
        videoInput.markAsFinished()
        await assetWriter.finishWriting()
    }

    private class StreamOutput: NSObject, SCStreamOutput {
        let videoInput: AVAssetWriterInput
        var sessionStarted = false
        var firstSampleTime: CMTime = .zero
        var lastSampleBuffer: CMSampleBuffer?

        init(videoInput: AVAssetWriterInput) {
            self.videoInput = videoInput
        }

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {

            // Return early if session hasn't started yet
            guard sessionStarted else { return }

            // Return early if the sample buffer is invalid
            guard sampleBuffer.isValid else { return }

            // Retrieve the array of metadata attachments from the sample buffer
            guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachments = attachmentsArray.first
            else { return }

            // Validate the status of the frame. If it isn't `.complete`, return
            guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
                  let status = SCFrameStatus(rawValue: statusRawValue),
                  status == .complete
            else { return }


            switch type {
            case .screen:
                if videoInput.isReadyForMoreMediaData {
                    // Save the timestamp of the current sample, all future samples will be offset by this
                    if firstSampleTime == .zero {
                        firstSampleTime = sampleBuffer.presentationTimeStamp
                    }

                    // Offset the time of the sample buffer, relative to the first sample
                    let lastSampleTime = sampleBuffer.presentationTimeStamp - firstSampleTime

                    // Always save the last sample buffer.
                    // This is used to "fill up" empty space at the end of the recording.
                    //
                    // Note that this permanently captures one of the sample buffers
                    // from the ScreenCaptureKit queue.
                    // Make sure reserve enough in SCStreamConfiguration.queueDepth
                    lastSampleBuffer = sampleBuffer

                    // Create a new CMSampleBuffer by copying the original, and applying the new presentationTimeStamp
                    let timing = CMSampleTimingInfo(duration: sampleBuffer.duration, presentationTimeStamp: lastSampleTime, decodeTimeStamp: sampleBuffer.decodeTimeStamp)
                    if let retimedSampleBuffer = try? CMSampleBuffer(copying: sampleBuffer, withNewTiming: [timing]) {
                        videoInput.append(retimedSampleBuffer)
                    } else {
                        print("Couldn't copy CMSampleBuffer, dropping frame")
                    }
                } else {
                    print("AVAssetWriterInput isn't ready, dropping frame")
                }

            case .audio:
                break

            @unknown default:
                break
            }
        }
    }
}


// AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
private func downsizedVideoSize(source: CGSize, scaleFactor: Int) -> (width: Int, height: Int) {
//    7680x4320
//    let maxSize = CGSize(width: 4096, height: 2304)
    let maxSize = CGSize(width: 7680, height: 4320)

    let w = source.width * Double(scaleFactor)
    let h = source.height * Double(scaleFactor)
    let r = max(w / maxSize.width, h / maxSize.height)

    return r > 1
        ? (width: Int(w / r), height: Int(h / r))
        : (width: Int(w), height: Int(h))
}

struct RecordingError: Error, CustomDebugStringConvertible {
    var debugDescription: String
    init(_ debugDescription: String) { self.debugDescription = debugDescription }
}




//class ScreenShotter: ObservableObject {
//
//    /// The supported capture types.
//    enum CaptureType {
//        case display
//        case window
//    }
//
//    @Published var isAudioCaptureEnabled: Bool = false
//    @Published var captureType: CaptureType = .display
//    @Published var selectedDisplay: SCDisplay?
//    @Published var selectedWindow: SCWindow?
//    @Published var isAppExcluded = true
//    private var scaleFactor: Int { Int(NSScreen.main?.backingScaleFactor ?? 2) }
//
//    func capture(displayID: CGDirectDisplayID) async {
//        guard let filter = try? await getContentFilter(displayID: displayID) else { return }
//        let configuration = getConfig()
//        try? await SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration: configuration)
//    }
//
//    func getContentFilter(displayID: CGDirectDisplayID) async throws -> SCContentFilter {
//        // Create a filter for the specified display
//        let sharableContent = try await SCShareableContent.current
//        guard let display = sharableContent.displays.first(where: { $0.displayID == displayID }) else {
//            throw RecordingError("Can't find display with ID \(displayID) in sharable content")
//        }
//        return SCContentFilter(display: display, excludingWindows: [])
//    }
//
//    func getConfig() -> SCStreamConfiguration {
//        let streamConfig = SCStreamConfiguration()
//
//        // Configure audio capture.
//        streamConfig.capturesAudio = isAudioCaptureEnabled
//
//        // Configure the display content width and height.
//        if captureType == .display, let display = selectedDisplay {
//            streamConfig.width = display.width * scaleFactor
//            streamConfig.height = display.height * scaleFactor
//        }
//
//        // Configure the window content width and height.
//        if captureType == .window, let window = selectedWindow {
//            streamConfig.width = Int(window.frame.width) * 2
//            streamConfig.height = Int(window.frame.height) * 2
//        }
//
//        // Set the capture interval at 60 fps.
//        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
//
//        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
//        // the memory footprint of WindowServer.
//        streamConfig.queueDepth = 5
//
//        return streamConfig
//    }
//}
//
//
