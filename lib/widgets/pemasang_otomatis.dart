import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/versi_provider.dart';
import '../services/pemasang_sesi.dart';
import '../services/pengunduh_apk.dart';
import 'dialog_update.dart';

/// Menampilkan pop-up pembaruan ([DialogUpdate]) SENDIRI waktu aplikasi
/// dibuka di dashboard dan ada versi baru, lalu memasangnya diam-diam waktu
/// aplikasi ditinggalkan kalau Android mengizinkan.
///
/// Membungkus isi layar dan memulangkannya apa adanya — nol pengaruh ke tata
/// letak. Bentuk pembungkus dipilih supaya dia terpasang di keempat keadaan
/// dashboard (skeleton, kosong, normal, gagal), bukan cuma waktu angkanya
/// sudah termuat: yang dashboard-nya gagal memuat justru yang paling mungkin
/// memegang versi lama.
///
/// ## Kenapa dialog, bukan langsung membuka pemasang (8 Okt 2026)
///
/// Sampai 8 Okt 2026 berkas ini membuka layar pemasang Android tanpa dialog,
/// tapi cuma kalau APK-nya SUDAH terunduh di latar — dan unduhan latar
/// sengaja tidak jalan di data seluler. Jadi teknisi yang selalu di seluler
/// tidak pernah disapa apa pun selain banner yang gampang terlewat. Permintaan
/// pemilik proyek: "kalau ada versi baru, muncul pop-up; tinggal pencet
/// Update". Dialognya muncul baik berkasnya sudah terunduh maupun belum; yang
/// belum diunduh SESUDAH tombolnya ditekan, dengan ukuran tertulis di tombol
/// dan progres di dialog yang sama.
///
/// Ketukan "Update" lalu layar konfirmasi Android masih dua langkah. Sejak
/// 15 Sep 2026 langkah Android itu bisa hilang: Android 12+ punya jalur untuk
/// memperbarui DIRI SENDIRI (`USER_ACTION_NOT_REQUIRED`) asal aplikasi ini yang
/// tercatat sebagai pemasangnya. Pemasangan lewat `PemasangSesi` yang membuat
/// catatan itu; sesudahnya [_mungkinPasangDiam] memasang rilis berikutnya
/// tanpa layar, waktu aplikasi ditinggalkan dari dashboard. Android 11 ke
/// bawah tetap butuh ketukan.
///
/// ## Tiga syarat dialognya muncul, dan kenapa tidak satu pun boleh dilepas
///
/// 1. **Sekali seumur proses** ([GiliranPemasangOtomatis]). Menekan "Nanti"
///    harus berarti sesuatu; tanpa ini penolakan cuma menunda satu layar.
/// 2. **Dashboard harus jadi layar yang sedang dilihat.** Teknisi yang sudah
///    masuk ke lembar kerja tidak boleh disela — itu persis gangguan yang
///    seluruh mekanisme unduh-di-latar dibangun buat menghindarinya.
/// 3. **Pemeriksaan versinya tidak gagal.** Pemeriksaan yang gagal (tanpa
///    sinyal) tidak menampilkan apa pun dan tidak menghabiskan giliran.
///
/// Kegagalan unduh/pasang tampil di dialog — itu jawaban atas ketukan
/// orangnya sendiri, jadi dia memang perlu tahu, lengkap dengan petunjuk
/// "Install unknown apps". Rilis wajib tetap punya "Nanti" — lihat
/// [DialogUpdate].
class PemasangOtomatis extends ConsumerStatefulWidget {
  const PemasangOtomatis({super.key, required this.child, this.pengunduh});

  /// Dipulangkan apa adanya.
  final Widget child;

  /// Disuntikkan di test. Null = pakai pengunduh sungguhan.
  final PengunduhApk? pengunduh;

  @override
  ConsumerState<PemasangOtomatis> createState() => _PemasangOtomatisState();
}

class _PemasangOtomatisState extends ConsumerState<PemasangOtomatis>
    with WidgetsBindingObserver {
  /// Pemasangan diam cukup dicoba sekali per proses: kalau berhasil, prosesnya
  /// memang dimatikan Android; kalau gagal, mengulang tiap kali aplikasi
  /// ditinggal cuma menulis 68 MB berulang ke sesi yang ditolak.
  bool _diamSudahDicoba = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Di `initState`, bukan `build`. Membuka dialog itu efek samping, dan
    // `build` dipanggil tiap kali angka dashboard berubah — puluhan kali per
    // sesi. Penjaga giliran memang menahannya, tapi menaruh efek samping di
    // `build` berarti benar-tidaknya bergantung pada penjaga itu saja.
    unawaited(_mungkinBuka());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState keadaan) {
    if (keadaan == AppLifecycleState.paused ||
        keadaan == AppLifecycleState.hidden) {
      unawaited(_mungkinPasangDiam());
    }
  }

  /// Pemutakhiran TANPA ketukan (Android 12+, sesudah aplikasi ini tercatat
  /// sebagai pemasangnya sendiri — lihat `PemasangSesi`).
  ///
  /// ## Kenapa waktu aplikasi DITINGGALKAN, dan cuma dari dashboard
  ///
  /// Memasang pembaruan mematikan proses aplikasi. Dilakukan waktu dipakai,
  /// layar tertutup sendiri di depan teknisi. Dilakukan waktu teknisi sedang di
  /// lembar kerja — termasuk saat dia pindah ke aplikasi kamera buat memotret
  /// lembar, yang juga membuat aplikasi ini "ditinggalkan" — isian yang belum
  /// dikirim ikut hilang. Jadi syaratnya: aplikasi masuk latar DAN yang terakhir
  /// dilihat dashboard (tidak ada layar lain yang menumpuk di atasnya).
  /// Dibuka lagi berikutnya, versinya sudah baru.
  Future<void> _mungkinPasangDiam() async {
    if (_diamSudahDicoba || !mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;

    final rilis = ref.read(updateTersediaProvider).value;
    if (rilis == null) return;

    final sesi = ref.read(pemasangSesiProvider);
    final berkas = await ref.read(penyiapUpdateProvider).apkSiap(rilis.versi);
    if (berkas == null || !mounted) return;
    if (!await sesi.bisaTanpaKetukan()) return;

    _diamSudahDicoba = true;
    try {
      await sesi.pasang(berkas.path, diam: true);
    } catch (_) {
      // Diam: dialog pembaruan dan bannernya tetap jadi jalan memasang.
    }
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

    // Sengaja `apkSiap`, BUKAN `updateSiapProvider` — dan hasilnya cuma
    // menentukan LABEL tombol ("Update sekarang" lawan "Update (68 MB)"),
    // bukan apakah dialognya muncul.
    //
    // `updateSiapProvider` menunggu unduhan latar selesai kalau belum — dan
    // menunggunya bisa bermenit-menit di WiFi lambat. Kalau jalur ini ikut
    // menunggu, dialognya muncul entah kapan sesudah aplikasi dibuka, waktu
    // orangnya sudah pindah perhatian. Yang dipakai di sini cuma pertanyaan
    // yang jawabannya seketika: berkasnya SUDAH ada atau belum. Waktu tombolnya
    // ditekan, `pasangPembaruan` memeriksanya ulang.
    final berkas = await ref.read(penyiapUpdateProvider).apkSiap(rilis.versi);

    if (!mounted) return;

    // Sudah pindah layar selama menunggu jawaban server di atas.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;

    // Giliran diambil PALING AKHIR, sesudah semua syarat lain lolos. Kalau
    // diambil di awal, pembukaan aplikasi yang kebetulan tanpa sinyal
    // menghabiskan giliran buat pemutakhiran yang bahkan tidak ketahuan ada —
    // dan sesudahnya tidak ada lagi dialog sampai aplikasinya ditutup.
    if (!ref.read(giliranPemasangOtomatisProvider).ambil()) return;

    await tampilkanDialogUpdate(
      context,
      rilis: rilis,
      siap: berkas != null,
      pengunduh: widget.pengunduh,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
