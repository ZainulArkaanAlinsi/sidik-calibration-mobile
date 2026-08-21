# Aturan R8 buat build release.
#
# R8 cuma jalan di `--release`. `flutter build apk --debug` — yang dipakai job
# "Build Android (debug)" di periksa-pr.yml — nggak pernah menyentuhnya. Itu
# sebabnya kegagalan di berkas ini nggak akan ketahuan dari PR check biasa;
# yang nangkep cuma workflow yang beneran mbangun release.

# ML Kit text recognition ngerujuk pengenal Mandarin, Jepang, Korea, dan
# Devanagari dari `TextRecognizer.initialize()`, padahal aplikasi ini cuma
# masang paket latin (`google_mlkit_text_recognition` bawaan). Kelasnya emang
# nggak ada di APK, dan itu disengaja — tiap paket bahasa nambah ukuran unduhan
# buat aksara yang nggak pernah muncul di lembar kerja kalibrasi.
#
# R8 nolak nyelesaiin build selama rujukannya masih menggantung:
#
#   Missing class com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
#   Execution failed for task ':app:minifyReleaseWithR8'
#
# `-dontwarn` bilang ke R8 bahwa rujukan yang nggak ketemu itu memang
# diharapkan. Bukan mematikan pemeriksaannya — cuma buat cabang bahasa yang
# nggak dipakai. Jalur latin yang beneran dipanggil tetap diperiksa penuh.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
