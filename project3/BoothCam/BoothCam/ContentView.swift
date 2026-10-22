//
//  ContentView.swift
//  BoothCam
//
//  Shared file. Member 1 (Sarah Rae) set up the layout skeleton; Member 3
//  (Georgia) owns the snap path and the CAPTURED panels; Member 4 (Calli) owns
//  what the FILTERED panels actually show.
//
//  Layout is the comparison the demo is built around:
//
//      LIVE ORIGINAL      |  LIVE FILTERED
//      CAPTURED ORIGINAL  |  CAPTURED FILTERED
//
//  Controls (teamTask.md): Space snap · F filter · I invert · Cmd-Q quit.
//

import CoreImage
import SwiftUI

struct ContentView: View {

    @StateObject private var camera = CameraManager()

    /// Whether the right-hand column shows the filter. `F` toggles it.
    @State private var showFiltered = true

    /// Grayscale (default) vs Color Invert. `I` toggles it.
    @State private var useInvert = false

    /// The captured still, as its OWN `CGImage`.
    ///
    /// Deliberately not a `CIImage` wrapping the live pixel buffer: those
    /// buffers come from a pool the capture session reuses, so holding one
    /// would let the "still" change under us, or stall the pipeline by keeping
    /// a buffer out of circulation. Rendering to a `CGImage` copies the pixels
    /// out, which is why this panel stays put while the live feed moves.
    @State private var captured: CGImage?

    /// Anything the user needs to be told — "no frame yet", a render failure.
    @State private var message: String?

    /// One context for the whole view, not one per render. Creating a
    /// `CIContext` is expensive; it holds the GPU resources the render uses.
    private static let ciContext = CIContext()

    var body: some View {
        VStack(spacing: 14) {
            header

            HStack(spacing: 14) {
                FramePanel(title: "LIVE ORIGINAL",
                           image: render(camera.latestFrame),
                           placeholder: "waiting for the first frame")
                FramePanel(title: "LIVE FILTERED",
                           image: showFiltered ? render(camera.latestFrame.map(filter)) : nil,
                           placeholder: showFiltered ? "waiting for the first frame" : "filter off (F)")
            }

            HStack(spacing: 14) {
                FramePanel(title: "CAPTURED ORIGINAL",
                           image: captured,
                           placeholder: "press Space to snap")
                FramePanel(title: "CAPTURED FILTERED",
                           image: showFiltered ? render(captured.map { filter(CIImage(cgImage: $0)) }) : nil,
                           placeholder: showFiltered ? "press Space to snap" : "filter off (F)")
            }

            controls
        }
        .padding()
        .frame(minWidth: 780, minHeight: 660)
        // The camera is opened when the window appears and released when it
        // goes away. Member 2 also needs the quit path — see CameraManager.stop().
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 4) {
            Text("BoothCam").font(.title2).bold()
            Text(camera.status)
                .font(.caption)
                .foregroundStyle(camera.isRunning ? Color.secondary : Color.orange)
            if !FrameFilter.isImplemented {
                Text("Filter is a stub — the filtered panels are copies of the originals for now")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Snap") { snap() }
                .keyboardShortcut(.space, modifiers: [])

            Button(showFiltered ? "Filter: on" : "Filter: off") { showFiltered.toggle() }
                .keyboardShortcut("f", modifiers: [])

            Button(useInvert ? "Mode: invert" : "Mode: grayscale") { useInvert.toggle() }
                .keyboardShortcut("i", modifiers: [])

            Spacer()
            Text("Space snap · F filter · I invert · ⌘Q quit")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    /// Member 3 (Georgia) owns this. Checklist (teamTask.md):
    ///
    ///   [ ] Render the current frame into a NEW CGImage with CIContext —
    ///       a real copy, not a reference to the live pixel buffer
    ///   [ ] Show it in the CAPTURED panel so it stays put as the feed moves
    ///   [ ] Handle "snap before any frame arrived" with a message, not a crash
    ///   [ ] Optional: save to file with NSSavePanel + PNG
    ///
    /// The shape it wants:
    ///
    ///     guard let frame = camera.latestFrame else { message = "No frame yet"; return }
    ///     captured = Self.ciContext.createCGImage(frame, from: frame.extent)
    ///
    private func snap() {
        message = "Snap not implemented yet — Member 3 (Georgia) owns this."
    }

    /// The single filter call both columns go through, so "the same filter is
    /// applied to the live frame and the still" is true by construction.
    private func filter(_ image: CIImage) -> CIImage {
        useInvert ? FrameFilter.invert(image) : FrameFilter.grayscale(image)
    }

    /// `CIImage` is a recipe, not pixels — this is where the work happens.
    private func render(_ image: CIImage?) -> CGImage? {
        guard let image else { return nil }
        return Self.ciContext.createCGImage(image, from: image.extent)
    }
}

/// One labelled panel. Shows the image if there is one, the reason if not.
private struct FramePanel: View {
    let title: String
    let image: CGImage?
    let placeholder: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).bold().foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Text(placeholder).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 220)
        }
    }
}

#Preview {
    ContentView()
}
