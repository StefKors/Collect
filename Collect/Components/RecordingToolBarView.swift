//
//  RecordingToolBarView.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import SwiftUI
import SwiftData
import ScreenCaptureKit
import Cocoa
import AVKit
import AVFoundation

struct RecordingToolBarView: View {
    @Binding var area: CGRect
    @State private var recorder: ScreenRecorder?
    @State private var url: URL?

    var canRecord: Bool {
        get async {
            do {
                // If the app doesn't have Screen Recording permission, this call generates an exception.
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return true
            } catch {
                return false
            }
        }
    }

    var body: some View {
        HStack {
                Button("start", action: start)
                Button("stop", action: stop)
            Button("quit", action: quit)
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func createRecorder() async {
        // Create a screen recording
        do {

            // Check for screen recording permission, make sure your terminal has screen recording permission
            guard await canRecord, CGPreflightScreenCaptureAccess() else {
                throw RecordingError("No screen capture permission")
            }

//            let day = Date().formatted(date: , time: .standard)
            self.url = FileManager.default.temporaryDirectory.appending(path: "Screen Recording \(UUID().uuidString).mov")
            if let url {
                print("recording at: \(url)")
                self.recorder = try await ScreenRecorder(url: url, displayID: CGMainDisplayID(), cropRect: area)
            }
        } catch {
            print("Error during recording:", error)
        }
    }


    func start() {
        Task {
            // Create a screen recording
            do {
                print("Starting screen recording of main display")
                await createRecorder()
                try await self.recorder?.start()
            } catch {
                print("Error during recording:", error)
            }

        }
    }

    func stop() {
        Task {
            // Create a screen recording
            do {
                print("Hit Return to end recording")
                try await self.recorder?.stop()

                if let url {
                    print("Recording ended, opening video")
//                    NSWorkspaceOpenConfiguration
//                    let config = NSWorkspace.OpenConfiguration()
//                    let asset = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first
//                    asset.
//                    NSWorkspace.shared.open(url, configuration: config)
                    NSWorkspace.shared.open(url)
                }
            } catch {
                print("Error during recording:", error)
            }

        }
    }
}

#Preview {
    RecordingToolBarView(area: .constant(.preview940))
        .modelContainer(for: Item.self, inMemory: true)
}


extension CGRect {
    static let preview940: CGRect = CGRect(origin: .zero, size: CGSize(width: 940, height: 520))
}
