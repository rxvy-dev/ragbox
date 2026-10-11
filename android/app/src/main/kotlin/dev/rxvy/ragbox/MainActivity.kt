package dev.rxvy.ragbox

import android.app.Activity
import android.content.Intent
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ragbox host activity.
 *
 * Provides a tiny platform bridge for the Dart side:
 *  - filesDir:   private app storage path (saves, settings, characters)
 *  - loadSound / playSound: low-latency SoundPool playback of locally generated WAVs
 *  - exportText / importText: system file picker (Storage Access Framework) for backups
 *
 * There is no networking anywhere in the app and no INTERNET permission in release builds.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dev.rxvy.ragbox/native"
    private val reqExport = 4101
    private val reqImport = 4102

    private var soundPool: SoundPool? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingExport: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        soundPool = SoundPool.Builder().setMaxStreams(24).setAudioAttributes(attrs).build()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "filesDir" -> result.success(filesDir.absolutePath)
                "loadSound" -> {
                    val path = call.argument<String>("path")
                    val id = if (path != null) (soundPool?.load(path, 1) ?: -1) else -1
                    result.success(id)
                }
                "playSound" -> {
                    val id = call.argument<Int>("id") ?: -1
                    val vol = (call.argument<Double>("volume") ?: 1.0).toFloat()
                    val rate = (call.argument<Double>("rate") ?: 1.0).toFloat()
                    if (id > 0) soundPool?.play(id, vol, vol, 1, 0, rate)
                    result.success(null)
                }
                "exportText" -> {
                    if (pendingResult != null) {
                        result.error("busy", "A file dialog is already open", null)
                    } else {
                        pendingExport = call.argument<String>("content") ?: ""
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "ragbox.json")
                        }
                        try {
                            startActivityForResult(intent, reqExport)
                        } catch (e: Exception) {
                            pendingResult = null
                            pendingExport = null
                            result.success(false)
                        }
                    }
                }
                "importText" -> {
                    if (pendingResult != null) {
                        result.error("busy", "A file dialog is already open", null)
                    } else {
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        try {
                            startActivityForResult(intent, reqImport)
                        } catch (e: Exception) {
                            pendingResult = null
                            result.success(null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Uses the classic activity result API to stay dependency free")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != reqExport && requestCode != reqImport) return
        val res = pendingResult ?: return
        pendingResult = null
        val uri: Uri? = data?.data
        val isExport = requestCode == reqExport
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendingExport = null
            res.success(if (isExport) false else null)
            return
        }
        try {
            if (isExport) {
                contentResolver.openOutputStream(uri, "wt")?.use {
                    it.write((pendingExport ?: "").toByteArray(Charsets.UTF_8))
                }
                pendingExport = null
                res.success(true)
            } else {
                val text = contentResolver.openInputStream(uri)?.use {
                    it.readBytes().toString(Charsets.UTF_8)
                }
                res.success(text)
            }
        } catch (e: Exception) {
            pendingExport = null
            res.success(if (isExport) false else null)
        }
    }

    override fun onDestroy() {
        soundPool?.release()
        soundPool = null
        super.onDestroy()
    }
}
