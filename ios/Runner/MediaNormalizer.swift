import Flutter
import Foundation

/// Platform channel `by.picpac/media`.
///
/// Transport only: the conversion lives in `MediaConverter.swift`, which the
/// macOS checker compiles as well. Everything here is thread marshalling and error
/// mapping.
///
/// Docs: docs/research/hevc-pipeline.md §5.
final class MediaNormalizer: NSObject {
  static let channelName = "by.picpac/media"

  /// Registers the channel on the implicit Flutter engine.
  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "PicPacMediaNormalizer")
    else { return }
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = MediaNormalizer()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "normalize" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
      let sourcePath = args["sourcePath"] as? String,
      let outputPath = args["outputPath"] as? String
    else {
      result(MediaConversionError.decodeFailed.flutterError(
        "sourcePath and outputPath are required"))
      return
    }
    let outputMime = args["outputMime"] as? String ?? "image/jpeg"
    let quality = (args["quality"] as? NSNumber)?.doubleValue ?? 95
    let maxPixels = (args["maxPixels"] as? NSNumber)?.intValue
      ?? 20_000_000

    // The channel handler runs on the main thread: decode and encode off it, then
    // hand the payload back on the main thread as Flutter requires.
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let payload = try MediaConverter.normalize(
          source: URL(fileURLWithPath: sourcePath),
          output: URL(fileURLWithPath: outputPath),
          outputMime: outputMime,
          quality: quality,
          maxPixels: maxPixels
        )
        DispatchQueue.main.async { result(payload) }
      } catch let error as MediaConversionError {
        DispatchQueue.main.async { result(error.flutterError()) }
      } catch {
        DispatchQueue.main.async {
          result(MediaConversionError.decodeFailed.flutterError(
            String(describing: type(of: error))))
        }
      }
    }
  }
}

extension MediaConversionError {
  /// Native code on the wire; Dart maps it to a namespaced `MediaErrorCode`.
  func flutterError(_ override: String? = nil) -> FlutterError {
    FlutterError(code: rawValue, message: override ?? message, details: nil)
  }
}
