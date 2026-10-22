//
//  FrameFilter.swift
//  BoothCam
//
//  Member 4 (Calli) — demo section 3c: the filter.
//
//  This is a STUB so the project builds. Both functions currently return the
//  image unchanged, so the filtered panels look identical to the originals
//  until they are implemented. Checklist (teamTask.md):
//
//    [ ] grayscale(_:) using CIPhotoEffectMono, or CIColorControls with saturation 0
//    [ ] invert(_:) using CIColorInvert (optional second toggle)
//    [ ] Apply the SAME function to the live frame and the captured still
//    [ ] Never mutate the input — filtering always returns a new image
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
    /// Returns the input unchanged for now, so the UI has something to draw.
    static func grayscale(_ image: CIImage) -> CIImage {
        // TODO: Member 4 (Calli)
        //   let f = CIFilter.photoEffectMono()
        //   f.inputImage = image
        //   return f.outputImage ?? image
        image
    }

    /// Flips every channel: 1 - value.
    static func invert(_ image: CIImage) -> CIImage {
        // TODO: Member 4 (Calli), optional
        //   let f = CIFilter.colorInvert()
        //   f.inputImage = image
        //   return f.outputImage ?? image
        image
    }

    /// True once the filters actually do something — the UI uses this to label
    /// the filtered panels honestly instead of showing a copy of the original.
    static let isImplemented = false
}
