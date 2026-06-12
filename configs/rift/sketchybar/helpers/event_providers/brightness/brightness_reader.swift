// Reads main display brightness (0-100) via the DisplayServices private framework.
// Compiled once by brightness.sh into bin/brightness_reader (gitignored).
import Foundation
import CoreGraphics

typealias Fn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)!
let s = dlsym(h, "DisplayServicesGetBrightness")!
let f = unsafeBitCast(s, to: Fn.self)
var b: Float = 0.0
if f(CGMainDisplayID(), &b) == 0 { print(String(format: "%.0f", b * 100)) }
dlclose(h)
