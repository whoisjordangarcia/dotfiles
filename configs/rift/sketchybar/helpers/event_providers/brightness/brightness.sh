#!/bin/bash
# Brightness event provider for SketchyBar
# Uses DisplayServices private framework via Swift to read display brightness
# Emits a custom event with brightness percentage every N seconds

EVENT_NAME="${1:-brightness_update}"
UPDATE_FREQ="${2:-5.0}"

sketchybar --add event "$EVENT_NAME"

while true; do
  brightness=$(swift -e '
import Foundation
import CoreGraphics
typealias Fn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)!
let s = dlsym(h, "DisplayServicesGetBrightness")!
let f = unsafeBitCast(s, to: Fn.self)
var b: Float = 0.0
if f(CGMainDisplayID(), &b) == 0 { print(String(format: "%.0f", b * 100)) }
dlclose(h)
' 2>/dev/null)

  brightness="${brightness:-0}"

  sketchybar --trigger "$EVENT_NAME" brightness="$brightness"

  sleep "$UPDATE_FREQ"
done
