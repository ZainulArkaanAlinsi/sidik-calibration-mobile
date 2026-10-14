# Aturan R8 build release Sidik Studio.
#
# Studio tidak memakai OCR, tapi `google_mlkit_text_recognition` ikut
# terdaftar sebagai plugin karena Studio bergantung pada paket
# `sidik_calibration` lewat path. Rujukan menggantung ML Kit ke pengenal
# Mandarin/Jepang/Korea/Devanagari yang sama dengan app lapangan bikin
# `:app:minifyReleaseWithR8` gagal total tanpa baris di bawah. Alasan lengkap:
# `android/app/proguard-rules.pro` di akar repo.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
