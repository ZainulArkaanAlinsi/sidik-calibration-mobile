import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/versi_provider.dart';
import '../services/pengunduh_apk.dart';

/// Membuka layar pemasang Android SENDIRI waktu aplikasi dibuka, kalau APK-nya
/// memang sudah terunduh diam-diam sebelumnya.
///
/// Membungkus isi layar dan memulangkannya apa adanya — nol pengaruh ke tata
/// letak. Bentuk pembungkus dipilih supaya dia terpasang di keempat keadaan
/// dashboard (skeleton, kosong, normal, gagal), bukan cuma waktu angkanya
/// sudah termuat: yang dashboard-nya gagal memuat justru yang paling mungkin
/// memegang versi lama.
///
/// ## Kenapa ada
///
/// Sebelum ini pemutakhiran butuh DUA ketukan: satu di banner "Pasang
/// sekarang", satu lagi di layar konfirmasi Android. Ketukan pertama tidak
/// memutuskan apa pun yang belum diputuskan — berkasnya sudah ada, orangnya
/// sudah mau, dan layar konfirmasi Android tetap datang sesudahnya menanyakan
/// hal yang sama. Jadi dia cuma pintu yang harus dibuka buat sampai ke pintu
/// yang sebenarnya.
///
/// Sekarang tinggal ketukan Android-nya. **Itu batasnya, dan tidak bisa
/// dikurangi lagi:** pemasangan diam-diam butuh izin `INSTALL_PACKAGES` yang
/// bertingkat `signature|privileged` — cuma buat aplikasi yang ditandatangani
/// kunci sistem. Play Store bisa karena dia bagian dari sistem, bukan karena
/// dia punya izin yang bisa kita minta juga.
///
/// ## Empat syarat, dan kenapa tidak satu pun boleh dilepas
///
/// 1. **APK-nya harus SUDAH terunduh.** Membuka pemasang buat berkas yang
///    belum ada berarti melempar orang ke layar yang menggantung menunggu
///    68 MB. Itu bukan satu ketukan, itu jebakan. Yang belum terunduh
///    diurus banner seperti biasa, lengkap dengan ukurannya.
/// 2. **Sekali seumur proses** ([GiliranPemasangOtomatis]). Menekan "Batal"
///    harus berarti sesuatu; tanpa ini penolakan cuma menunda satu layar.
/// 3. **Dashboard harus jadi layar yang sedang dilihat.** Teknisi yang sudah
///    masuk ke lembar kerja tidak boleh ditarik keluar — itu persis gangguan
///    yang seluruh mekanisme unduh-di-latar dibangun buat menghindarinya.
/// 4. **Gagalnya diam.** Ini jalan tanpa diminta, jadi kegagalannya bukan
///    kabar yang orangnya butuh saat membuka aplikasi. Bannernya masih di
///    layar dengan tombol Pasang yang pesan galatnya lengkap — termasuk yang
///    menyuruh menyalakan "Install unknown apps".
class PemasangOtomatis extends ConsumerStatefulWidget {
  const PemasangOtomatis({super.key, required this.child, this.pengunduh});

  /// Dipulangkan apa adanya.
  final Widget child;

  /// Disuntikkan di test. Null = pakai pengunduh sungguhan.
  final PengunduhApk? pengunduh;

  @override
  ConsumerState<PemasangOtomatis> createState() => _PemasangOtomatisState();
}

class _PemasangOtomatisState extends ConsumerState<PemasangOtomatis> {
  @override
  void initState() {
    super.initState();

    // Di `initState`, bukan `build`. Membuka pemasang itu efek samping, dan
    // `build` dipanggil tiap kali angka dashboard berubah — puluhan kali per
    // sesi. Penjaga giliran memang menahannya, tapi menaruh efek samping di
    // `build` berarti benar-tidaknya bergantung pada penjaga itu saja.
    unawaited(_mungkinBuka());
  }

  Future<void> _mungkinBuka() async {
    final rilis = await ref.read(updateTersediaProvider.future);
    if (rilis == null) return;

    // `ref` tidak boleh disentuh lagi sesudah widget-nya dilepas —
    // flutter_riverpod menolaknya dengan "Cannot use 'ref' after the widget was
    // disposed". Jeda di atas cukup lebar buat itu kejadian: pemeriksaan versi
    // menunggu jawaban server, dan logout atau pindah rute selama menunggu itu
    // hal biasa. Karena jalur ini jalan `unawaited`, lemparannya jadi galat
    // asinkron yang tidak tertangkap siapa pun.
    if (!mounted) return;

    // Sengaja `apkSiap`, BUKAN `updateSiapProvider`.
    //
    // `updateSiapProvider` menunggu unduhan latar selesai kalau belum — dan
    // menunggunya bisa bermenit-menit di WiFi lambat. Kalau jalur ini ikut
    // menunggu, pemasangnya terbuka entah kapan sesudah aplikasi dibuka,
    // waktu orangnya sudah pindah perhatian. Yang dipakai di sini cuma
    // pertanyaan yang jawabannya seketika: berkasnya SUDAH ada atau belum.
    //
    // Yang belum ada tetap terunduh — bannernya yang membaca
    // `updateSiapProvider` dan memulai unduhan latar, persis seperti sebelum
    // ada berkas ini. Hasilnya kepakai di pembukaan aplikasi BERIKUTNYA.
    final berkas = await ref.read(penyiapUpdateProvider).apkSiap(rilis.versi);
    if (berkas == null) return;

    if (!mounted) return;

    // Sudah pindah layar selama menunggu jawaban server di atas.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;

    // Giliran diambil PALING AKHIR, sesudah semua syarat lain lolos. Kalau
    // diambil di awal, pembukaan aplikasi yang kebetulan tanpa sinyal
    // menghabiskan giliran buat pemutakhiran yang bahkan tidak ketahuan ada —
    // dan sesudahnya tidak ada lagi yang membuka pemasang sampai aplikasinya
    // ditutup.
    if (!ref.read(giliranPemasangOtomatisProvider).ambil()) return;

    // Dibungkus karena `pasang` menembus platform channel dan bisa melempar,
    // sementara jalur ini jalan `unawaited`. Janji "gagalnya diam" di atas cuma
    // benar kalau memang ada yang menelannya; tanpa ini, kegagalan pemasang
    // mendarat sebagai galat asinkron yang justru muncul ke layar.
    try {
      await (widget.pengunduh ?? PengunduhApkAsli()).pasang(berkas);
    } catch (_) {
      // Bannernya masih di layar dan tombol Pasang-nya punya pesan galat yang
      // lengkap — termasuk yang menyuruh menyalakan "Install unknown apps".
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
