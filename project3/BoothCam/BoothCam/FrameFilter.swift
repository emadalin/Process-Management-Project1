//
//  FrameFilter.swift
//  BoothCam
//
//  Member 4 (Calli) — demo section 3c: the filter.
//
//  Checklist (teamTask.md):
//
//    [x] grayscale(_:) using CIPhotoEffectMono
//    [x] invert(_:) using CIColorInvert (optional second toggle)
//    [x] Apply the SAME function to the live frame and the captured still
//        (ContentView.filter(_:) is the one call both columns go through)
//    [x] Never mutate the input — filtering always returns a new image
//    [ ] Explain the data change: RGB -> one brightness value
//        (about 0.3R + 0.59G + 0.11B); invert = 1 - each channel
//    [ ] Explain where it runs: inside Core Image, usually on the GPU, called
//        from our code — it is NOT a camera setting
//    [ ] Note any effect on frame rate or quality, filter on vs off
//
//  Why these are free functions on a namespace rather than methods on a view:
//  the live frame and the captured still both go through the same call, which
//  is what makes "the filter does the same thing to both" true by construction
//  rather than by two code paths agreeing.
//
//  A note on Core Image you will want for the demo: applying a filter does not
//  compute anything. `CIImage` is a recipe, not pixels. The work happens when
//  something renders it — `CIContext.createCGImage` in the snap path, or
//  SwiftUI drawing it. That is why filtering a live frame is cheap.
//

import CoreImage
import CoreImage.CIFilterBuiltins

enum FrameFilter {

    /// Drops colour, keeping brightness.
    ///
    /// Each pixel's R, G and B become one brightness value — the textbook
    /// version is 0.3R + 0.59G + 0.11B (green counts most because our eyes are
    /// most sensitive to it). The input is not changed; this returns a new image.
    ///
    /// Observed: the real numbers differ from that formula. Pure red comes out
    /// as 132 (of 255), not 77, because Core Image does the maths on linear
    /// light rather than on the stored 0–255 values, and PhotoEffectMono adds
    /// its own film-style contrast curve on top. Green > red > blue still holds.
    static func grayscale(_ image: CIImage) -> CIImage {
        let filter = CIFilter.photoEffectMono()
        filter.inputImage = image
        // outputImage is only nil if the filter has no input, which cannot
        // happen here — falling back to the original keeps the panel drawing.
        if let output = filter.outputImage {
            return output
        }
        return image
    }

    /// Flips every channel: 1 - value (255 - value in 8-bit terms), so
    /// black becomes white and red becomes cyan. Returns a new image.
    static func invert(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorInvert()
        filter.inputImage = image
        if let output = filter.outputImage {
            return output
        }
        return image
    }

    /// True once the filters actually do something — the UI uses this to label
    /// the filtered panels honestly instead of showing a copy of the original.
    static let isImplemented = true
}
