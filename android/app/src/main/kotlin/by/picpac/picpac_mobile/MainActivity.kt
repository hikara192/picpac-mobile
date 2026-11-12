package by.picpac.picpac_mobile

import by.picpac.picpac_mobile.media.MediaNormalizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // HEIC/HEIF → JPEG: our own channel, so the photo never reaches the
        // server as HEVC and never carries EXIF/GPS.
        MediaNormalizer.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
    }
}
