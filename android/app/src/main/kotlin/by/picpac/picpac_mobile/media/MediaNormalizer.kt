package by.picpac.picpac_mobile.media

import android.app.ActivityManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Platform channel `by.picpac/media`.
 *
 * One job: turn a picked photo into the single file the print pipeline accepts
 * (JPEG q0.95, no metadata) or refuse it with a typed code. The policy lives in
 * Dart (`NormalizationPolicy`); this file executes it.
 *
 * Why `ImageDecoder` (API 28+) and not `BitmapFactory`:
 * * `setTargetSize` decodes *into* the target size, so a 48 MP HEIF never becomes
 *   a 195 MB bitmap — the pixel cap is applied before allocation;
 * * EXIF orientation is applied by the decoder itself, so no manual `Matrix` can
 *   double-rotate the photo;
 * * `setTargetColorSpace(SRGB)` converts the pixels once, and the file needs no
 *   ICC profile afterwards.
 *
 * `Bitmap.compress` writes no EXIF at all, so GPS, MakerNote and XMP disappear by
 * construction — the only reliable allowlist on Android is the empty one.
 *
 * API 24–27 fall back to `BitmapFactory` + a power-of-two `inSampleSize` + the
 * system `android.media.ExifInterface` for the orientation. No androidx
 * dependency is added: `androidx.exifinterface` is not in the build and the
 * system class does exactly one thing here (read the orientation tag).
 *
 * Docs: docs/research/hevc-pipeline.md §5.
 */
object MediaNormalizer {
    private const val CHANNEL = "by.picpac/media"

    /** Pixel budget under memory pressure; preflight then reports LOW_DPI honestly. */
    private const val LOW_MEMORY_PIXEL_BUDGET = 12_000_000L

    /** Below this `ActivityManager.memoryClass` the device is treated as low-RAM. */
    private const val LOW_MEMORY_CLASS_MB = 256

    /** API 24 is the project minimum; HEIF decoding starts at API 28. */
    private const val IMAGE_DECODER_API = Build.VERSION_CODES.P

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "picpac-media").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Registers the channel on the Flutter engine of `MainActivity`. */
    fun register(messenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "normalize") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val sourcePath = call.argument<String>("sourcePath")
            val outputPath = call.argument<String>("outputPath")
            if (sourcePath == null || outputPath == null) {
                result.error("decode_failed", "sourcePath and outputPath are required", null)
                return@setMethodCallHandler
            }
            val outputMime = call.argument<String>("outputMime") ?: "image/jpeg"
            val sourceMime = call.argument<String>("sourceMime") ?: ""
            val quality = call.argument<Number>("quality")?.toInt() ?: 95
            val maxPixels = call.argument<Number>("maxPixels")?.toLong() ?: 20_000_000L

            // The channel handler runs on the main thread: decode and encode on
            // the single background thread so the UI keeps its frames.
            executor.execute {
                try {
                    val payload = normalize(
                        context = appContext,
                        source = File(sourcePath),
                        output = File(outputPath),
                        outputMime = outputMime,
                        sourceMime = sourceMime,
                        quality = quality,
                        maxPixels = maxPixels,
                    )
                    mainHandler.post { result.success(payload) }
                } catch (error: MediaFailure) {
                    mainHandler.post { result.error(error.code, error.message, null) }
                } catch (error: OutOfMemoryError) {
                    // No silent inSampleSize retry: a lower resolution the user
                    // never asked for is worse than an honest refusal.
                    mainHandler.post {
                        result.error("out_of_memory", "the decoder ran out of memory", null)
                    }
                } catch (error: Throwable) {
                    mainHandler.post {
                        result.error("decode_failed", error.javaClass.simpleName, null)
                    }
                }
            }
        }
    }

    private fun normalize(
        context: Context,
        source: File,
        output: File,
        outputMime: String,
        sourceMime: String,
        quality: Int,
        maxPixels: Long,
    ): Map<String, Any> {
        if (!source.exists() || !source.canRead()) throw MediaFailure("permission_denied", "the photo cannot be read")
        if (source.length() <= 0L) throw MediaFailure("decode_failed", "the photo is empty")
        val budget = pixelBudget(context, maxPixels)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            throw MediaFailure("unsupported_format", "Android below 7.0 cannot decode this photo")
        }
        output.parentFile?.mkdirs()
        if (output.exists()) output.delete()

        val bitmap = if (Build.VERSION.SDK_INT >= IMAGE_DECODER_API) {
            decodeWithImageDecoder(source, budget)
        } else {
            decodeWithBitmapFactory(source, budget)
        }
        val width: Int
        val height: Int
        try {
            width = bitmap.width
            height = bitmap.height
            val format = if (outputMime == "image/png") Bitmap.CompressFormat.PNG
            else Bitmap.CompressFormat.JPEG
            val written = FileOutputStream(output).use { stream ->
                bitmap.compress(format, quality.coerceIn(0, 100), stream)
            }
            if (!written) throw MediaFailure("encode_failed", "the photo cannot be encoded")
        } finally {
            // A 20 MP bitmap is 80 MB; it must not outlive the write.
            bitmap.recycle()
        }
        if (!output.exists() || output.length() <= 0L) {
            throw MediaFailure("encode_failed", "the encoded photo is empty")
        }
        return mapOf(
            "path" to output.path,
            "widthPx" to width,
            "heightPx" to height,
            "mimeType" to if (outputMime == "image/png") "image/png" else "image/jpeg",
            "bytes" to output.length(),
            "sha256" to sha256Hex(output),
            "converted" to true,
            "sourceMime" to sourceMime,
        )
    }

    /** Pixel budget: the request, lowered on a low-RAM device. */
    private fun pixelBudget(context: Context, requested: Long): Long {
        val memoryClass = (context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager)?.memoryClass
        return if (memoryClass != null && memoryClass < LOW_MEMORY_CLASS_MB) {
            min(requested, LOW_MEMORY_PIXEL_BUDGET)
        } else {
            requested
        }
    }

    @RequiresApi(IMAGE_DECODER_API)
    private fun decodeWithImageDecoder(source: File, maxPixels: Long): Bitmap {
        return try {
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(source)) { decoder, info, _ ->
                val width = info.size.width
                val height = info.size.height
                if (width <= 0 || height <= 0) {
                    throw MediaFailure("decode_failed", "the photo has no pixels")
                }
                val scale = min(1.0, sqrt(maxPixels.toDouble() / (width.toDouble() * height.toDouble())))
                decoder.setTargetSize(
                    max(1, (width * scale).roundToInt()),
                    max(1, (height * scale).roundToInt()),
                )
                // P3 → sRGB in pixels, so the JPEG needs no ICC profile.
                decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
                // HARDWARE bitmaps cannot be compressed.
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.memorySizePolicy = ImageDecoder.MEMORY_POLICY_LOW_RAM
                decoder.isMutableRequired = false
                // Orientation is applied by the decoder: a manual Matrix on top
                // of it would rotate the photo twice.
            }
        } catch (error: ImageDecoder.DecodeException) {
            throw MediaFailure("decode_failed", error.javaClass.simpleName)
        }
    }

    @Suppress("DEPRECATION")
    private fun decodeWithBitmapFactory(source: File, maxPixels: Long): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw MediaFailure("decode_failed", "the photo has no pixels")
        }
        var sample = 1
        while ((bounds.outWidth.toLong() / sample) * (bounds.outHeight.toLong() / sample) > maxPixels) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inScaled = false
        }
        val decoded = BitmapFactory.decodeFile(source.path, options)
            ?: throw MediaFailure("decode_failed", "the photo cannot be decoded")
        val orientation = try {
            android.media.ExifInterface(source.path)
                .getAttributeInt(android.media.ExifInterface.TAG_ORIENTATION, android.media.ExifInterface.ORIENTATION_NORMAL)
        } catch (error: Throwable) {
            android.media.ExifInterface.ORIENTATION_NORMAL
        }
        val upright = applyOrientation(decoded, orientation)
        if (upright !== decoded) decoded.recycle()
        return upright
    }

    /** Bakes an EXIF orientation into the pixels (API 24–27 only). */
    private fun applyOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            android.media.ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            android.media.ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            android.media.ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            android.media.ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            android.media.ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            android.media.ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.postScale(-1f, 1f)
            }
            android.media.ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    /** Streamed SHA-256: the file never enters memory as a whole. */
    private fun sha256Hex(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(1 shl 20)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xFF) }
    }

    /** Typed failure codes shared with `lib/core/media/photo_normalizer.dart`. */
    private class MediaFailure(val code: String, override val message: String) : Exception(message)
}
