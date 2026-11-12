// Writes an image with a chosen container and a chosen metadata payload.
//
// The fixture generator (`make-heic.sh`) needs three things `sips` cannot do:
// write HEIC from a PNG with an EXIF orientation, and attach a GPS dictionary to
// either a HEIC or a JPEG. ImageIO is the only framework on macOS that can write
// HEIC with metadata, so the helper is ten lines of CoreGraphics instead of a
// hand-built `exiftool` dependency.
//
// Usage: inject <input> <output> <heic|jpeg|png> <orientation 1..8> <gps 0|1>
// The pixels are copied as they are: the orientation is metadata, not a rotation,
// which is exactly the state a camera leaves HEIC files in.
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 6,
  let orientation = Int(arguments[4]),
  let gps = Int(arguments[5])
else {
  FileHandle.standardError.write(
    Data("usage: inject <in> <out> <heic|jpeg|png> <orientation> <gps>\n".utf8))
  exit(64)
}

let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
let type: UTType
switch arguments[3] {
case "heic": type = .heic
case "jpeg": type = .jpeg
case "png": type = .png
default:
  FileHandle.standardError.write(Data("unknown type \(arguments[3])\n".utf8))
  exit(64)
}

guard
  let source = CGImageSourceCreateWithURL(input as CFURL, nil),
  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
  FileHandle.standardError.write(Data("cannot read \(input.path)\n".utf8))
  exit(2)
}

guard
  let destination = CGImageDestinationCreateWithURL(
    output as CFURL, type.identifier as CFString, 1, nil)
else {
  FileHandle.standardError.write(Data("cannot write \(output.path)\n".utf8))
  exit(3)
}

var properties: [CFString: Any] = [
  // A plausible camera block: the removal test asserts that *none* of this
  // survives normalisation.
  kCGImagePropertyTIFFDictionary: [
    kCGImagePropertyTIFFMake: "PicPac",
    kCGImagePropertyTIFFModel: "Fixture Camera",
  ] as CFDictionary,
  kCGImagePropertyExifDictionary: [
    kCGImagePropertyExifDateTimeOriginal: "2026:11:12 10:00:00",
    kCGImagePropertyExifUserComment: "synthetic fixture",
  ] as CFDictionary,
]
if orientation >= 1 && orientation <= 8 {
  properties[kCGImagePropertyOrientation] = orientation
}
if gps == 1 {
  properties[kCGImagePropertyGPSDictionary] = [
    kCGImagePropertyGPSLatitude: 53.9023,
    kCGImagePropertyGPSLatitudeRef: "N",
    kCGImagePropertyGPSLongitude: 27.5615,
    kCGImagePropertyGPSLongitudeRef: "E",
    kCGImagePropertyGPSAltitude: 220.0,
  ] as CFDictionary
}

CGImageDestinationAddImage(destination, image, properties as CFDictionary)
guard CGImageDestinationFinalize(destination) else {
  FileHandle.standardError.write(Data("cannot finalise \(output.path)\n".utf8))
  exit(4)
}
