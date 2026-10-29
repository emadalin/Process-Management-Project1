//
//  CameraManager.swift
//  BoothCam
//
//  Member 2 (Stephen) — demo section 3a: opening the camera, frames, display, cleanup.
//
//  Checklist (teamTask.md):
//
//    [x] Permission: AVCaptureDevice.authorizationStatus(for: .video) / requestAccess
//    [x] Device: AVCaptureDevice.default(for: .video) -> AVCaptureDeviceInput -> session
//    [x] AVCaptureVideoDataOutput with a delegate on a BACKGROUND DispatchQueue;
//        alwaysDiscardsLateVideoFrames = true
//    [x] captureOutput: sample buffer -> CVPixelBuffer -> CIImage -> publish on main
//    [x] Start/stop the session OFF the main thread (startRunning blocks)
//    [x] Errors: no camera, permission denied, canAddInput fails,
//        AVCaptureSession.runtimeError, dropped frames -> clear message, no crash
//    [x] Cleanup: stopRunning() and remove inputs/outputs on quit and window close
//    [ ] Test failure: deny permission (tccutil reset Camera <bundle id>, click Don't
//        Allow) and one more case. Manual — needs the GUI prompt. Write down how it
//        was tested in the test record (docs/test-record-template.md), not here.
//
//  Why the work happens off the main thread: startRunning() blocks until the
//  device is configured, and frames arrive faster than the UI can draw. The
//  delegate queue keeps capture off the main thread; only the published frame
//  crosses back to it.
//

import AVFoundation
import Combine
import CoreImage
import CoreMedia
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

    // MARK: - Session (configured and run on sessionQueue, off the main actor)

    /// `nonisolated(unsafe)`: these four are touched ONLY from `sessionQueue`,
    /// a serial queue — session configuration, start/stop, and the delegate
    /// callbacks all run there, never on the main actor or anywhere else. So
    /// there is no actual data race, just one the compiler can't see, because
    /// DispatchQueue exclusivity isn't something Swift's actor model knows
    /// how to check. (Same justification `DemoLog` in project2's
    /// `Models.swift` uses for its own single-owner global.) If any of this
    /// ever gets touched from a second queue, this becomes a real race and
    /// needs an `actor` instead of a plain class + DispatchQueue.
    private nonisolated(unsafe) let session = AVCaptureSession()
    private nonisolated(unsafe) let videoOutput = AVCaptureVideoDataOutput()

    /// Serial queue for everything AVFoundation needs off the main thread:
    /// session configuration, startRunning()/stopRunning() (both block the
    /// calling thread), and the video data output delegate callbacks (frames
    /// arrive far faster than SwiftUI can redraw).
    private let sessionQueue = DispatchQueue(label: "com.boothcam.sessionQueue")

    /// Held so `stop()` can remove exactly the input we added, rather than
    /// walking `session.inputs` and guessing. `sessionQueue`-only, see above.
    private nonisolated(unsafe) var deviceInput: AVCaptureDeviceInput?

    /// Whether the session's input/output are currently wired up. Reset to
    /// `false` on `stop()`, so a later `start()` (window reopened, app
    /// relaunched into the same process) reconfigures from scratch instead of
    /// trying to add an input/output that's already there. `sessionQueue`-only.
    private nonisolated(unsafe) var isConfigured = false

    /// Guards the one-time pixel-format log below, so it prints once per
    /// session instead of once per frame. `sessionQueue`-only, same
    /// justification as the rest of this group.
    private nonisolated(unsafe) var hasLoggedPixelFormat = false

    // MARK: - Lifecycle

    /// Requests permission, builds the session, and starts frames flowing.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()

        case .notDetermined:
            status = "requesting camera permission…"
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                // Unwrap the weak reference HERE, before handing it to the
                // Task below — capturing an already-strong `self` into the
                // Task avoids a "captured var in concurrently-executing code"
                // warning that referencing the weak optional from inside the
                // nested Task would otherwise trigger.
                guard let self else { return }
                Task { @MainActor in
                    if granted {
                        self.configureAndStart()
                    } else {
                        self.status = "camera permission denied — enable it in System Settings \u{2192} Privacy & Security \u{2192} Camera"
                    }
                }
            }

        case .denied, .restricted:
            status = "camera permission denied — enable it in System Settings \u{2192} Privacy & Security \u{2192} Camera"

        @unknown default:
            status = "camera permission in an unrecognized state"
        }
    }

    /// Stops the session and releases the device.
    ///
    /// This matters more than it looks: without it the camera indicator light
    /// stays on and the device stays locked against other apps. Removing the
    /// input/output (not just stopping) is what actually releases the device,
    /// not just pauses delivery.
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.session.beginConfiguration()
            if let deviceInput = self.deviceInput {
                self.session.removeInput(deviceInput)
            }
            self.session.removeOutput(self.videoOutput)
            self.session.commitConfiguration()
            self.deviceInput = nil
            self.isConfigured = false
            NotificationCenter.default.removeObserver(
                self, name: AVCaptureSession.runtimeErrorNotification, object: self.session
            )
        }
        isRunning = false
        status = "stopped"
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Session configuration

    /// Configures the session (once) and starts it. Both steps run on
    /// `sessionQueue`: `startRunning()` blocks the calling thread until the
    /// device is ready, so doing this on the main thread would freeze the UI
    /// on every launch.
    private func configureAndStart() {
        status = "starting camera…"
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                let result = self.configureSession()
                self.isConfigured = result.success
                if !result.success {
                    let message = result.message ?? "could not configure the camera"
                    Task { @MainActor in
                        self.status = message
                    }
                    return
                }
            }

            self.session.startRunning()
            let running = self.session.isRunning
            Task { @MainActor in
                self.isRunning = running
                self.status = running ? "live" : "camera failed to start"
            }
        }
    }

    /// Adds the device input and video output to the session. Runs on
    /// `sessionQueue`. Returns whether it succeeded and, if not, why — so
    /// every failure path produces a specific message instead of a generic
    /// one, per the checklist's error list.
    ///
    /// `nonisolated`: called synchronously from inside the `sessionQueue.async`
    /// block in `configureAndStart()`, which is not on the main actor. It only
    /// touches the `nonisolated(unsafe)` session state above, never a
    /// `@Published` property directly — the caller hops to `@MainActor` itself
    /// to report the result.
    private nonisolated func configureSession() -> (success: Bool, message: String?) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // .high rather than a fixed resolution: the lowest common setting
        // every team Mac's built-in or USB webcam is guaranteed to support.
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video) else {
            return (false, "no camera found")
        }

        // One-time, for the README's device-selection note: this Mac reports
        // TWO cameras (the built-in FaceTime/MacBook Pro camera, and an
        // iPhone over Continuity), both through the same
        // AVCaptureDevice.default(for:) call. We never chose which one — the
        // system did, by whatever priority order it uses internally. Printed
        // once so the test record can say which camera actually backed each
        // run, which the team's device-stack doc already flags as required.
        print("[CameraManager] device: \(device.localizedName) (\(device.deviceType.rawValue), uniqueID \(device.uniqueID))")

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            return (false, "could not open \(device.localizedName): \(error.localizedDescription)")
        }

        guard session.canAddInput(input) else {
            return (false, "camera input could not be added to the session")
        }
        session.addInput(input)
        deviceInput = input

        // Frames arrive faster than SwiftUI can draw; discarding late frames
        // keeps the delegate queue from backing up behind stale buffers
        // instead of always showing the most recent one.
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard session.canAddOutput(videoOutput) else {
            session.removeInput(input)
            deviceInput = nil
            return (false, "camera output could not be added to the session")
        }
        session.addOutput(videoOutput)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError(_:)),
            name: AVCaptureSession.runtimeErrorNotification,
            object: session
        )

        return (true, nil)
    }

    /// `AVCaptureSessionRuntimeError` can post from any thread AVFoundation
    /// happens to be using internally, not necessarily `sessionQueue` — hence
    /// `nonisolated`, with the actual state change hopping to the main actor.
    @objc nonisolated private func sessionRuntimeError(_ notification: Notification) {
        let message: String
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            message = "camera stopped: \(error.localizedDescription)"
        } else {
            message = "camera stopped unexpectedly"
        }
        Task { @MainActor [weak self] in
            self?.isRunning = false
            self?.status = message
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Called on `sessionQueue`, NOT the main actor — frames arrive far
    /// faster than SwiftUI redraws, so this has to stay off the main thread.
    /// `nonisolated` is what makes that legal on a `@MainActor` type; only
    /// the final `@Published` write below hops back to the main actor.
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // One-time, for Sarah Rae's section 2 "what the library hides vs
        // what we can still find out": the pixel format is AVFoundation's
        // choice, not ours — we never asked for one. Printed once (not per
        // frame, which would spam the console at ~30/sec) the first time a
        // frame actually arrives.
        if !hasLoggedPixelFormat {
            hasLoggedPixelFormat = true
            let formatCode = CVPixelBufferGetPixelFormatType(pixelBuffer)
            print("[CameraManager] pixel format: \(fourCCString(formatCode)) (raw \(formatCode))")
        }

        // CIImage wrapping a CVPixelBuffer is a recipe, not a pixel copy —
        // cheap here. The actual render happens later, in ContentView, each
        // time a panel needs to draw.
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        Task { @MainActor [weak self] in
            self?.latestFrame = image
        }
    }

    /// A frame was dropped — the buffer pool ran out, or a late frame got
    /// discarded because `alwaysDiscardsLateVideoFrames` is on. Not an error:
    /// the UI will just show the next frame that does arrive. Logged only to
    /// stdout so a dropped-frame burst is visible while debugging without
    /// surfacing a false "something's wrong" message to the user.
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didDrop sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        print("[CameraManager] dropped a frame")
    }
}

/// Decodes a `CVPixelBufferGetPixelFormatType` / `OSType` FourCC into its
/// 4-character form (e.g. `420v`, `BGRA`) — the raw integer alone isn't
/// something a person, or a doc, can read. Apple's own pixel format
/// constants (`kCVPixelFormatType_420YpCbCr8BiPlanarFullRange`, etc.) are
/// *defined* as these four bytes, so this is lossless, not a guess. A byte
/// outside the printable ASCII range renders as `.` rather than garbage.
private nonisolated func fourCCString(_ type: OSType) -> String {
    let bytes: [UInt8] = [
        UInt8((type >> 24) & 0xFF),
        UInt8((type >> 16) & 0xFF),
        UInt8((type >> 8) & 0xFF),
        UInt8(type & 0xFF),
    ]
    let characters = bytes.map { byte in
        (32...126).contains(byte) ? Character(UnicodeScalar(byte)) : "."
    }
    return String(characters)
}
