import 'dart:async';
import 'dart:convert';

import '../../services/draf_lokal.dart';

/// Keadaan formulir yang dibutuhkan buat menulis satu salinan.
typedef KeadaanDrafLokal = ({
  Map<String, dynamic> isian,
  bool adaIsian,
  int? sesiId,
  String clientRequestId,
  int? equipmentId,
  int? pengulangan,
  String? judul,
  bool matriks,
});

/// Simpanan otomatis satu layar lembar kerja (F3-01).
///
/// Dipisah dari layarnya supaya aturan kapan menulis & kapan diam bisa diuji
/// tanpa merender formulir 4.000 baris:
///
///  - menulis [jeda] (800 ms) sesudah perubahan terakhir, dan SEKETIKA lewat
///    [simpanSekarang] waktu aplikasi ke latar;
///  - **diam** selama [aktif] `false` — sesi lama yang masih dimuat, yang gagal
///    dimuat, atau yang sudah disetujui. Menulis di situ sama saja menyimpan
///    formulir kosong lalu "memulihkannya" di atas isian server;
///  - nggak menulis kalau isiannya sama dengan yang terakhir ditulis (atau
///    dengan isian yang baru dimuat), jadi membuka draf tanpa mengubah apa pun
///    nggak meninggalkan salinan di HP.
class PenjagaDrafLokal {
  PenjagaDrafLokal({
    required this.simpanan,
    required this.userId,
    required this.profil,
    required this.keadaan,
    this.judulTambahan,
    this.buatKiriman,
    this.versiAplikasi,
    this.jeda = const Duration(milliseconds: 800),
    DateTime Function()? jam,
  }) : _jam = jam ?? DateTime.now;

  final SimpananDrafLokal simpanan;
  final int userId;
  final String profil;
  final String? judulTambahan;
  final KeadaanDrafLokal Function() keadaan;

  /// Body server buat draf yang sedang ANTRE — dirakit ulang tiap simpan
  /// otomatis supaya yang dikirim nanti ikut isian terakhir, bukan isian waktu
  /// tombolnya ditekan.
  final Map<String, dynamic>? Function()? buatKiriman;

  String? versiAplikasi;
  final Duration jeda;
  final DateTime Function() _jam;

  bool aktif = false;
  StatusDrafLokal status = StatusDrafLokal.lokal;
  String? pesan;
  bool dicobaKirim = false;
  Map<String, dynamic>? kiriman;
  DateTime? basisServer;

  Timer? _tertunda;
  String? _jejak;
  final Set<String> _kunciDitulis = {};
  bool _selesai = false;

  bool get adaTertunda => _tertunda?.isActive ?? false;

  /// Pakai keadaan salinan yang dimuat (status antrean, dsb.).
  void pakaiEntri(DrafLokal d) {
    status = d.status;
    pesan = d.pesan;
    dicobaKirim = d.dicobaKirim;
    kiriman = d.kiriman;
    basisServer ??= d.basisServer;
    _kunciDitulis.add(d.kunci);
  }

  /// Isian sekarang dianggap "sudah tersimpan" — perubahan berikutnya yang
  /// memicu tulisan.
  void tetapkanAcuan() {
    _jejak = _sandi(keadaan().isian);
  }

  /// Ada yang berubah — tulis [jeda] lagi, kecuali ada perubahan lain.
  void berubah() {
    if (!aktif || _selesai) return;
    _tertunda?.cancel();
    _tertunda = Timer(jeda, () => unawaited(simpanSekarang()));
  }

  /// Jaring pengaman buat kotak yang nggak punya pendengar ketikan: isiannya
  /// dibandingkan dengan tulisan terakhir, dan kalau beda dijadwalkan seperti
  /// [berubah].
  void periksa() {
    if (!aktif || _selesai || adaTertunda) return;
    if (_sandi(keadaan().isian) != _jejak) berubah();
  }

  /// Tulis sekarang juga. Snapshot diambil SINKRON sebelum `await` pertama —
  /// aman dipanggil dari `dispose()` layar, sebelum controller-nya dibuang.
  Future<void> simpanSekarang({bool paksa = false}) async {
    _tertunda?.cancel();
    if (_selesai || (!aktif && !paksa)) return;

    final k = keadaan();
    final sandi = _sandi(k.isian);

    // Lembar baru yang belum disentuh sama sekali nggak dititipkan.
    if (!paksa && !k.adaIsian && k.sesiId == null) return;
    if (!paksa && sandi == _jejak) return;

    if (status == StatusDrafLokal.belumTersinkron) {
      try {
        kiriman = buatKiriman?.call() ?? kiriman;
      } catch (_) {
        // Kiriman lama tetap dipakai — lebih baik draf yang sedikit basi
        // terkirim daripada antreannya macet.
      }
    }

    final draf = DrafLokal(
      userId: userId,
      sesiId: k.sesiId,
      clientRequestId: k.clientRequestId,
      profil: profil,
      judul: k.judul,
      judulTambahan: judulTambahan,
      equipmentId: k.equipmentId,
      pengulangan: k.pengulangan,
      disimpanPada: _jam(),
      basisServer: basisServer,
      status: status,
      pesan: pesan,
      dicobaKirim: dicobaKirim,
      matriks: k.matriks,
      kiriman: status == StatusDrafLokal.lokal ? null : kiriman,
      isian: k.isian,
      versiAplikasi: versiAplikasi,
    );

    _jejak = sandi;
    final lama = {..._kunciDitulis}..remove(draf.kunci);
    _kunciDitulis
      ..clear()
      ..add(draf.kunci);

    await simpanan.simpan(draf);

    // `baru-<cid>` yang sudah dapat id server pindah ke `sesi-<id>`.
    for (final kunci in lama) {
      await simpanan.hapus(userId, kunci);
    }
  }

  /// Simpan Draf gagal karena server nggak terjangkau → antre.
  Future<void> antrekan(
    Map<String, dynamic> kirimanBaru, {
    required bool mungkinSudahSampai,
  }) {
    status = StatusDrafLokal.belumTersinkron;
    pesan = null;
    kiriman = kirimanBaru;
    dicobaKirim = dicobaKirim || mungkinSudahSampai;
    return simpanSekarang(paksa: true);
  }

  /// Kirim (bukan draf) gagal karena jaringan: TIDAK diantrekan, tapi
  /// isiannya tetap disimpan di HP.
  Future<void> catatGagalJaringan({required bool mungkinSudahSampai}) {
    dicobaKirim = dicobaKirim || mungkinSudahSampai;
    return simpanSekarang(paksa: true);
  }

  /// Hapus semua salinan layar ini dan berhenti menulis — dipakai sesudah
  /// tersimpan di server, atau waktu teknisi sengaja membuang isiannya.
  Future<void> hapus({Iterable<String> kunciLain = const []}) async {
    _selesai = true;
    aktif = false;
    _tertunda?.cancel();

    final k = keadaan();
    final semua = {
      ..._kunciDitulis,
      ...kunciLain,
      DrafLokal.kunciUntuk(
        sesiId: k.sesiId,
        clientRequestId: k.clientRequestId,
      ),
      DrafLokal.kunciUntuk(clientRequestId: k.clientRequestId),
    };
    _kunciDitulis.clear();

    for (final kunci in semua) {
      await simpanan.hapus(userId, kunci);
    }
  }

  /// Tulis balik salinan [awal] apa adanya lalu berhenti — "keluar tanpa
  /// simpan" dari draf yang SUDAH antre: yang dibuang cuma ketikan sesi layar
  /// ini, bukan draf yang dulu sengaja disimpan.
  Future<void> kembalikan(DrafLokal awal) async {
    _selesai = true;
    aktif = false;
    _tertunda?.cancel();

    final lama = {..._kunciDitulis}..remove(awal.kunci);
    await simpanan.simpan(awal);
    for (final kunci in lama) {
      await simpanan.hapus(userId, kunci);
    }
  }

  void dispose() {
    _tertunda?.cancel();
  }

  static String _sandi(Map<String, dynamic> isian) {
    try {
      return jsonEncode(isian);
    } catch (_) {
      return '';
    }
  }
}
