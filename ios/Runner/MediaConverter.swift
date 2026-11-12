import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers
import os

/// HEIC/JPEG → single JPEG, without metadata.
///
/// Framework-only code: no Flutter import, so the same file is compiled into the
/// app and into the macOS checker (`scripts/fixtures/verify-conversion.sh`), which
/// makes the conversion verifiable without building the app.
///
/// Why ImageIO and not `UIImage`:
/// * `CGImageSourceCreateThumbnailAtIndex` decodes *into the target size*, so a
///   48 MP HEIC never materialises as a 195 MB `UIImage`
///   (`kCGImageSourceThumbnailMaxPixelSize`);
/// * `kCGImageSourceCreateThumbnailWithTransform` bakes the EXIF orientation into
///   the pixels, so the output needs no Orientation tag;
/// * no dictionary is passed to `CGImageDestinationAddImage`, so EXIF, GPS,
///   MakerNote and XMP cannot be "forgotten" — there is nothing to copy from;
/// * the destination writes straight to the file, the JPEG never lives in `Data`.
///
/// Docs: docs/research/hevc-pipeline.md §5.
enum MediaConverter {
  /// Pixel budget under memory pressure. A photo still prints; preflight reports
  /// `LOW_DPI` honestly instead of the pipeline silently keeping 12 MP of 48 MP.
  static let lowMemoryPixelBudget = 12_000_000

  /// Decodes `source` once and writes `output` without any metadata.
  ///
  /// Returns the channel payload: path, geometry, size, SHA-256 of the file and
  /// the MIME types of the result and of the source.
  static func normalize(
    source: URL,
    output: URL,
    outputMime: String,
    quality: Double,
    maxPixels: Int
  ) throws -> [String: Any] {
    let manager = FileManager.default
    guard manager.isReadableFile(atPath: source.path) else {
      throw MediaConversionError.permissionDenied
    }
    let sourceBytes =
      (try? manager.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?
      .intValue ?? 0
    guard sourceBytes > 0 else { throw MediaConversionError.decodeFailed }

    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard
      let imageSource = CGImageSourceCreateWithURL(
        source as CFURL,
        sourceOptions as CFDictionary
      ), CGImageSourceGetCount(imageSource) > 0
    else {
      throw MediaConversionError.decodeFailed
    }

    // 1. Geometry from the header only, including the orientation swap.
    let properties =
      CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
      as? [CFString: Any] ?? [:]
    let rawWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?
      .intValue ?? 0
    let rawHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?
      .intValue ?? 0
    guard rawWidth > 0, rawHeight > 0 else {
      throw MediaConversionError.decodeFailed
    }
    let orientation = CGImagePropertyOrientation(
      rawValue: (properties[kCGImagePropertyOrientation] as? NSNumber)?
        .uint32Value ?? 1
    ) ?? .up
    let swapped = [
      CGImagePropertyOrientation.left, .leftMirrored, .right, .rightMirrored,
    ].contains(orientation)
    let displayWidth = swapped ? rawHeight : rawWidth
    let displayHeight = swapped ? rawWidth : rawHeight

    // 2. Pixel cap, never an upscale.
    let budget = min(maxPixels, effectivePixelBudget(requested: maxPixels))
    let scale = min(
      1.0,
      (Double(budget) / (Double(displayWidth) * Double(displayHeight)))
        .squareRoot()
    )
    let targetWidth = max(1, Int((Double(displayWidth) * scale).rounded()))
    let targetHeight = max(1, Int((Double(displayHeight) * scale).rounded()))

    // 3. Decode straight into the target size with the orientation baked in.
    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: max(targetWidth, targetHeight),
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(
        imageSource,
        0,
        thumbnailOptions as CFDictionary
      )
    else {
      throw MediaConversionError.decodeFailed
    }

    // 4. Write it. No metadata dictionary is ever passed to the destination.
    let isPng = outputMime == "image/png"
    let type = isPng ? UTType.png.identifier : UTType.jpeg.identifier
    try? manager.removeItem(at: output)
    guard
      let destination = CGImageDestinationCreateWithURL(
        output as CFURL,
        type as CFString,
        1,
        nil
      )
    else {
      throw MediaConversionError.encodeFailed
    }
    var destinationOptions: [CFString: Any] = [
      kCGImageDestinationEmbedThumbnail: false,
      kCGImageMetadataShouldExcludeGPS: true,
      kCGImageDestinationOptimizeColorForSharing: true,
    ]
    if !isPng {
      destinationOptions[kCGImageDestinationLossyCompressionQuality] =
        max(0.0, min(1.0, quality / 100.0))
    }
    CGImageDestinationAddImage(
      destination,
      image,
      destinationOptions as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
      throw MediaConversionError.encodeFailed
    }

    // ImageIO re-attaches a minimal EXIF block when the *source* already had one
    // (observed on JPEG → JPEG, both with and without an explicit empty
    // `CGImageDestinationMetadata`). The allowlist must be enforced on the bytes,
    // not on the writer's goodwill.
    try stripIdentifyingSegments(at: output)

    let outputBytes =
      (try? manager.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?
      .intValue ?? 0
    guard outputBytes > 0 else { throw MediaConversionError.encodeFailed }

    return [
      "path": output.path,
      "widthPx": image.width,
      "heightPx": image.height,
      "mimeType": isPng ? "image/png" : "image/jpeg",
      "bytes": outputBytes,
      "sha256": try sha256Hex(output),
      "converted": true,
      "sourceMime": sourceMimeType(imageSource),
    ]
  }

  /// Drops the JPEG segments that can carry identities.
  ///
  /// Removed: `APP1` (EXIF and XMP — camera model, serial number, GPS), `APP13`
  /// (IPTC/Photoshop, often a GPS duplicate), `APP12` (camera vendor block) and
  /// `COM` (free text). Kept: `APP0` (JFIF density) and `APP2` (ICC profile),
  /// neither of which describes the photographer.
  ///
  /// A JPEG has to be read to do this; it is the file this pipeline just wrote
  /// (single digit megabytes), not the original, and it is re-written atomically.
  static func stripIdentifyingSegments(at url: URL) throws {
    let data = try Data(contentsOf: url)
    let bytes = [UInt8](data)
    guard bytes.count > 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else {
      throw MediaConversionError.encodeFailed
    }
    var output = Data([0xFF, 0xD8])
    var offset = 2
    while offset + 4 <= bytes.count {
      // Skip fill bytes (0xFF padding between segments).
      if bytes[offset] != 0xFF {
        offset += 1
        continue
      }
      let marker = bytes[offset + 1]
      if marker == 0xDA {  // start of scan: the rest is entropy-coded data
        output.append(contentsOf: bytes[offset...])
        break
      }
      let length = (Int(bytes[offset + 2]) << 8) | Int(bytes[offset + 3])
      guard length >= 2, offset + 2 + length <= bytes.count else {
        output.append(contentsOf: bytes[offset...])
        break
      }
      let end = offset + 2 + length
      let identifying = marker == 0xE1 || marker == 0xED || marker == 0xEC
        || marker == 0xFE
      if !identifying {
        output.append(contentsOf: bytes[offset..<end])
      }
      offset = end
    }
    try output.write(to: url, options: .atomic)
  }

  /// Lowers the pixel budget when the process has little memory left.
  ///
  /// `os_proc_available_memory()` is the documented per-process headroom on
  /// iOS 13+, and `physicalMemory` covers the 2 GB devices where the headroom
  /// number is already close to zero when the picker has been open.
  static func effectivePixelBudget(requested: Int) -> Int {
    #if os(iOS)
      let headroom = os_proc_available_memory()
    #else
      // The macOS checker builds this file too; there is no per-process
      // headroom API there and no low-RAM phone to protect.
      let headroom: Int = 0
    #endif
    let physical = ProcessInfo.processInfo.physicalMemory
    let lowHeadroom = headroom > 0 && headroom < 400 * 1024 * 1024
    let smallDevice = physical > 0 && physical <= 2 * 1024 * 1024 * 1024
    return (lowHeadroom || smallDevice)
      ? min(requested, lowMemoryPixelBudget)
      : requested
  }

  /// MIME type the source declares, for the payload (Dart has sniffed the bytes
  /// already; this is the second, framework-side opinion).
  private static func sourceMimeType(_ imageSource: CGImageSource) -> String {
    guard let type = CGImageSourceGetType(imageSource) as String? else {
      return ""
    }
    return UTType(type)?.preferredMIMEType ?? ""
  }

  /// Streamed SHA-256: the file never enters memory as a whole.
  static func sha256Hex(_ url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while true {
      let chunk = try handle.read(upToCount: 1 << 20) ?? Data()
      if chunk.isEmpty { break }
      hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

/// Typed failure codes shared with `lib/core/media/photo_normalizer.dart`.
enum MediaConversionError: String, Error {
  case unsupportedFormat = "unsupported_format"
  case tooLarge = "too_large"
  case decodeFailed = "decode_failed"
  case encodeFailed = "encode_failed"
  case outOfMemory = "out_of_memory"
  case permissionDenied = "permission_denied"

  /// Message is developer-facing only: the user sees an ARB string chosen by the
  /// mapped `MediaErrorCode`, never this text.
  var message: String {
    switch self {
    case .unsupportedFormat: return "the format is not supported by ImageIO"
    case .tooLarge: return "the photo exceeds the import budget"
    case .decodeFailed: return "the photo cannot be decoded"
    case .encodeFailed: return "the photo cannot be encoded"
    case .outOfMemory: return "the decoder ran out of memory"
    case .permissionDenied: return "the photo cannot be read"
    }
  }
}
