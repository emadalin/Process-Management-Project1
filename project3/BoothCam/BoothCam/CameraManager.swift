//
//  CameraManager.swift
//  BoothCam
//
//  Member 2 (Stephen) — demo section 3a: opening the camera, frames, display, cleanup.
//
//  This is a STUB so the project builds and everyone can work in parallel. It
//  publishes nothing and opens no device yet. Checklist (teamTask.md):
//
//    [ ] Permission: AVCaptureDevice.authorizationStatus(for: .video) / requestAccess
//    [ ] Device: AVCaptureDevice.default(for: .video) -> AVCaptureDeviceInput -> session
//    [ ] AVCaptureVideoDataOutput with a delegate on a BACKGROUND DispatchQueue;
//        alwaysDiscardsLateVideoFrames = true
//    [ ] captureOutput: sample buffer -> CVPixelBuffer -> CIImage -> publish on main
//    [ ] Start/stop the session OFF the main thread (startRunning blocks)
//    [ ] Errors: no camera, permission denied, canAddInput fails,
//        AVCaptureSession.runtimeError, dropped frames -> clear message, no crash
//    [ ] Cleanup: stopRunning() and remove inputs/outputs on quit and window close
//    [ ] Explain session preset, the queue, and discarding late frames
//
//  Why the work happens off the main thread: startRunning() blocks until the
//  device is configured, and frames arrive faster than the UI can draw. The
//  delegate queue keeps capture off the main thread; only the published frame
//  crosses back to it.
//

import AVFoundation
import Combine
import CoreImage
import SwiftUI

/// Owns the capture session and publishes the most recent frame.
///
/// `@MainActor` so every published change already lands on the main thread —
/// the delegate callback below is the one place that has to hop back.
@MainActor
final class CameraManager: NSObject, ObservableObject {

    /// The most recent frame, as a `CIImage`. `nil` until the first frame
    /// arrives, which is why the snap button has to handle "no frame yet."
    @Published private(set) var latestFrame: CIImage?

    /// Human-readable state for the UI. Errors go here rather than to a crash.
    @Published private(set) var status: String = "not started — Member 2 (Stephen) owns CameraManager.swift"

    /// True once frames are actually arriving.
    @Published private(set) var isRunning = false

    // MARK: - Lifecycle

    /// Requests permission, builds the session, and starts frames flowing.
    func start() {
        status = "start() not implemented yet — Member 2 (Stephen)"
    }

    /// Stops the session and releases the device.
    ///
    /// This matters more than it looks: without it the camera indicator light
    /// stays on and the device stays locked against other apps.
    func stop() {
        isRunning = false
        status = "stopped"
    }
}
