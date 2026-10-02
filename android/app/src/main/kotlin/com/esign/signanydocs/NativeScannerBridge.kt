package com.esign.signanydocs

import android.app.Activity
import android.graphics.Bitmap
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

/** Android bridge for importing documents and capturing a page with the native camera. */
class NativeScannerBridge(private val activity: Activity) {
    private var pendingResult: OnceResult? = null
    private val importRequestCode = 4107
    private val scanRequestCode = 4108

    fun handle(method: String, result: MethodChannel.Result): Boolean = when (method) {
        "importDocument" -> {
            if (pendingResult != null) {
                result.error("SCANNER_BUSY", "A document selection is already in progress.", null)
                return true
            }
            pendingResult = OnceResult(result)
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", "image/png", "image/jpeg"))
            }
            activity.startActivityForResult(intent, importRequestCode)
            true
        }
        "scanDocument" -> {
            if (pendingResult != null) {
                result.error("SCANNER_BUSY", "A camera capture is already in progress.", null)
                return true
            }
            pendingResult = OnceResult(result)
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            if (intent.resolveActivity(activity.packageManager) == null) {
                pendingResult = null
                result.error("SCANNER_UNAVAILABLE", "No camera app is available on this device.", null)
            } else {
                activity.startActivityForResult(intent, scanRequestCode)
            }
            true
        }
        else -> false
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            importRequestCode -> {
                val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
                val result = pendingResult
                pendingResult = null
                result?.success(uri?.let(::copyToCache))
            }
            scanRequestCode -> {
                val bitmap = if (resultCode == Activity.RESULT_OK) {
                    data?.extras?.get("data") as? Bitmap
                } else {
                    null
                }
                val result = pendingResult
                pendingResult = null
                result?.success(bitmap?.let(::copyBitmapToCache))
            }
        }
    }

    private fun copyToCache(uri: Uri): String? = try {
        val extension = activity.contentResolver.getType(uri)
            ?.substringAfterLast('/')
            ?.takeIf { it.length in 1..8 } ?: "bin"
        val destination = File(activity.cacheDir, "esign_import_${System.currentTimeMillis()}.$extension")
        activity.contentResolver.openInputStream(uri)?.use { input ->
            destination.outputStream().use { output -> input.copyTo(output) }
        } ?: return null
        destination.absolutePath
    } catch (_: Exception) {
        null
    }

    private fun copyBitmapToCache(bitmap: Bitmap): String? = try {
        val destination = File(activity.cacheDir, "esign_scan_${System.currentTimeMillis()}.jpg")
        FileOutputStream(destination).use { output ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 92, output)
        }
        destination.absolutePath
    } catch (_: Exception) {
        null
    }

    /** Android can deliver a cancelled activity result more than once on some devices. */
    private class OnceResult(private val delegate: MethodChannel.Result) : MethodChannel.Result {
        private val replied = AtomicBoolean(false)

        override fun success(result: Any?) {
            if (replied.compareAndSet(false, true)) delegate.success(result)
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            if (replied.compareAndSet(false, true)) delegate.error(errorCode, errorMessage, errorDetails)
        }

        override fun notImplemented() {
            if (replied.compareAndSet(false, true)) delegate.notImplemented()
        }
    }
}
