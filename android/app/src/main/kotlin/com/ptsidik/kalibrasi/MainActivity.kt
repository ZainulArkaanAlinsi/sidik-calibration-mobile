package com.ptsidik.kalibrasi

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Jembatan ke `PemasangSesi` — lihat `lib/services/pemasang_sesi.dart`.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ptsidik.kalibrasi/pemasang")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bisaTanpaKetukan" -> result.success(PemasangSesi.bisaTanpaKetukan(applicationContext))

                    "pasang" -> {
                        val jalur = call.argument<String>("jalur")
                        if (jalur == null) {
                            result.success("gagal: jalur kosong")
                            return@setMethodCallHandler
                        }
                        val diam = call.argument<Boolean>("diam") ?: false

                        // Menyalin APK ~68 MB ke sesi makan beberapa detik. Di
                        // thread utama itu ANR — layar membeku lalu Android
                        // menawarkan "tutup aplikasi".
                        Thread {
                            val hasil = PemasangSesi.pasang(applicationContext, jalur, diam)
                            runOnUiThread { result.success(hasil) }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
