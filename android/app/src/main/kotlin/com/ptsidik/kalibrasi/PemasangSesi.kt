package com.ptsidik.kalibrasi

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log
import java.io.File

/**
 * Memasang APK pemutakhiran lewat `PackageInstaller`, bukan dengan membuka
 * berkasnya ke layar pemasang sistem.
 *
 * ## Kenapa bukan `open_filex` lagi
 *
 * Membuka APK lewat intent VIEW selalu memunculkan layar "Install", DAN yang
 * tercatat sebagai pemasang aplikasinya tetap pemasang sistem. Android 12+
 * cuma mengizinkan pemutakhiran TANPA ketukan (`USER_ACTION_NOT_REQUIRED`)
 * kalau yang memasang adalah "installer of record" paket itu sendiri. Jadi
 * pemasangan pertama lewat sesi ini masih minta satu ketukan — sesudahnya
 * aplikasi ini tercatat sebagai pemasangnya, dan rilis berikutnya bisa masuk
 * tanpa layar konfirmasi.
 *
 * Android 11 ke bawah tidak punya jalur itu sama sekali: sesi tetap jalan,
 * layar konfirmasinya tetap muncul.
 */
object PemasangSesi {
    private const val TAG = "PemasangSesi"
    const val AKSI_HASIL = "com.ptsidik.kalibrasi.HASIL_PASANG"

    /** Pemutakhiran berikutnya boleh masuk tanpa ketukan di perangkat ini. */
    fun bisaTanpaKetukan(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        if (!context.packageManager.canRequestPackageInstalls()) return false

        return try {
            val sumber = context.packageManager.getInstallSourceInfo(context.packageName)
            sumber.installingPackageName == context.packageName
        } catch (e: Exception) {
            false
        }
    }

    /**
     * @return `"dimulai"`, `"izin"` (Install unknown apps belum diizinkan),
     *         atau `"gagal: ..."`.
     */
    fun pasang(context: Context, jalur: String, diam: Boolean): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !context.packageManager.canRequestPackageInstalls()
        ) {
            return "izin"
        }

        val berkas = File(jalur)
        if (!berkas.isFile) return "gagal: berkas tidak ada"

        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(context.packageName)
        params.setSize(berkas.length())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(
                if (diam) PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED
                else PackageInstaller.SessionParams.USER_ACTION_UNSPECIFIED,
            )
        }

        var idSesi = -1
        return try {
            idSesi = installer.createSession(params)
            installer.openSession(idSesi).use { sesi ->
                berkas.inputStream().use { masuk ->
                    sesi.openWrite("sidik.apk", 0, berkas.length()).use { keluar ->
                        masuk.copyTo(keluar)
                        sesi.fsync(keluar)
                    }
                }

                val intent = Intent(context, PenerimaHasilPasang::class.java).setAction(AKSI_HASIL)
                // MUTABLE wajib: sistem mengisi status & intent konfirmasi ke
                // dalam PendingIntent ini.
                val bendera = PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
                val pending = PendingIntent.getBroadcast(context, idSesi, intent, bendera)
                sesi.commit(pending.intentSender)
            }
            "dimulai"
        } catch (e: Exception) {
            Log.w(TAG, "Sesi pemasangan gagal", e)
            if (idSesi != -1) {
                try { installer.abandonSession(idSesi) } catch (_: Exception) {}
            }
            "gagal: ${e.message}"
        }
    }
}

/**
 * Hasil sesi pemasangan. Kalau Android tetap minta konfirmasi (pemasangan
 * pertama, atau Android 11 ke bawah), layar konfirmasinya dibuka dari sini.
 */
class PenerimaHasilPasang : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val konfirmasi = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT) ?: return
                konfirmasi.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    context.startActivity(konfirmasi)
                } catch (e: Exception) {
                    // Aplikasi sedang di latar dan Android menahan pembukaan
                    // layar. APK-nya tetap tersimpan; PemasangOtomatis membuka
                    // pemasang lagi di pembukaan aplikasi berikutnya.
                    Log.w("PemasangSesi", "Layar konfirmasi tidak bisa dibuka", e)
                }
            }
            PackageInstaller.STATUS_SUCCESS -> Log.i("PemasangSesi", "Pemutakhiran terpasang")
            else -> Log.w(
                "PemasangSesi",
                "Pemasangan gagal ($status): ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)}",
            )
        }
    }
}
