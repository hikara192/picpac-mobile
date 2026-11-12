// Runs the real conversion (`ios/Runner/MediaConverter.swift`) on macOS.
//
// The app build needs the whole Dart graph, and the device test needs a
// simulator; this checker needs neither. It compiles the same Swift file the app
// links and converts the committed fixtures, so the "does it really produce a
// JPEG without EXIF?" question has an answer in one command.
//
// Usage: scripts/fixtures/verify-conversion.sh
import Foundation
import ImageIO

func dump(_ label: String, _ path: String) {
  guard
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
      as? [CFString: Any]
  else {
    print("\(label): cannot read \(path)")
    return
  }
  let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
  let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
  let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
  let gps = properties[kCGImagePropertyGPSDictionary] != nil
  let exif = properties[kCGImagePropertyExifDictionary] != nil
  let tiff = properties[kCGImagePropertyTIFFDictionary] != nil
  print(
    "\(label): \(width)x\(height) orientation=\(orientation) "
      + "exif=\(exif) gps=\(gps) tiff=\(tiff)")
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
  FileHandle.standardError.write(
    Data("usage: verify <input> <output>\n".utf8))
  exit(64)
}
let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])

dump("input ", input.path)

do {
  let started = Date()
  let payload = try MediaConverter.normalize(
    source: input,
    output: output,
    outputMime: "image/jpeg",
    quality: 95,
    maxPixels: 20_000_000
  )
  let elapsed = Date().timeIntervalSince(started) * 1000

  let bytes = try Data(contentsOf: output)
  let magic = bytes.prefix(3).map { String(format: "%02X", $0) }.joined(separator: " ")
  print("output: magic=\(magic) bytes=\(payload["bytes"] ?? 0) "
    + "size=\(payload["widthPx"] ?? 0)x\(payload["heightPx"] ?? 0) "
    + "mime=\(payload["mimeType"] ?? "") sourceMime=\(payload["sourceMime"] ?? "") "
    + "in \(String(format: "%.0f", elapsed)) ms")
  print("output: sha256=\(payload["sha256"] ?? "")")
  dump("output", output.path)

  if magic != "FF D8 FF" {
    FileHandle.standardError.write(Data("FAIL: the output is not a JPEG\n".utf8))
    exit(1)
  }
} catch let error as MediaConversionError {
  FileHandle.standardError.write(
    Data("FAIL: \(error.rawValue): \(error.message)\n".utf8))
  exit(2)
} catch {
  FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
  exit(3)
}
