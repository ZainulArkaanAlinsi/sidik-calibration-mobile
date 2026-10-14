import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart'
    show TokenHilangException;

import '../widget/grid/alamat_sel.dart';
import 'simulasi_model.dart';
import 'workbook_provider.dart';
import 'workbook_service.dart';

export 'simulasi_model.dart';

/// Peran yang boleh menjalankan simulasi (kontrak Tahap C: admin,
/// super_admin, teknisi). Menyembunyikan edit BUKAN kontrol akses — server
/// menolak sendiri (403).
bool peranBolehSimulasi(UserRole? peran) => switch (peran) {
  UserRole.admin || UserRole.superAdmin || UserRole.teknisi => true,
  _ => false,
};

/// Jeda sebelum `/hitung` dikirim. Edit beruntun (Ctrl+Z ditahan, hapus
/// rentang lalu ketik, isi sel lalu Enter berturut-turut) jadi SATU kiriman
/// — satu hitung bisa belasan detik. "Menghitung…" tampil sejak edit pertama.
const Duration jedaKirimHitung = Duration(milliseconds: 500);

/// Jarak minimum antara dua kiriman `/hitung` satu simulasi. Jatah server
/// `studio-hitung` = 30/menit/pengguna (API `AppServiceProvider`) = satu
/// kiriman per 2 s; dengan jarak ini mengisi sel secepat apa pun tidak
/// menghabiskannya sendirian. Edit yang tiba lebih rapat MENUNGGU (tetap
/// "Menghitung…") lalu dikirim SEKALI dengan semua edit terbaru — kiriman
/// lama yang jawabannya dibuang pun ikut dihitung server.
const Duration jarakMinKirimHitung = Duration(seconds: 2);

/// Simulasi satu workbook — edit terkumpul selama layar workbook terbuka.
///
/// `autoDispose`: menutup layar = semua edit hilang (memang tidak disimpan).
/// Ikut akun (`authProvider`): ganti akun → kosong lagi. Terdaftar di
/// `providerSesiStudio` (masuk ulang/keluar menyapunya).
final simulasiWorkbookProvider = NotifierProvider.autoDispose
    .family<SimulasiWorkbook, KeadaanSimulasi, int>(SimulasiWorkbook.new);

/// Kunci [overlayLembarProvider].
typedef KunciOverlayLembar = ({int workbookId, int lembarId});

/// Lapisan simulasi satu lembar — yang ditonton sel grid. Identitasnya cuma
/// berubah bila edit/jawaban lembar ITU berubah, jadi "Menghitung…" atau
/// edit di lembar lain tidak membangun ulang sel lembar ini.
final overlayLembarProvider = Provider.autoDispose
    .family<OverlayLembar, KunciOverlayLembar>(
      (ref, k) => ref.watch(
        simulasiWorkbookProvider(
          k.workbookId,
        ).select((s) => s.overlayUntuk(k.lembarId)),
      ),
    );

class SimulasiWorkbook extends Notifier<KeadaanSimulasi> {
  SimulasiWorkbook(this.workbookId);

  final int workbookId;

  final _riwayat = <List<PerubahanEdit>>[];
  final _ulang = <List<PerubahanEdit>>[];
  Timer? _jeda;

  /// Naik tiap edit/urung/reset. Jawaban yang tiba untuk generasi lama
  /// DIBUANG — itulah "batalkan request lama": `ApiClient` tidak bisa
  /// memutus request yang sudah berangkat, tapi hasilnya tidak pernah
  /// menimpa keadaan yang lebih baru.
  int _generasi = 0;

  /// Edit yang menghasilkan [KeadaanSimulasi.hasil].
  Map<KunciEditSel, String>? _terhitung;

  /// Aktif = kiriman terakhir berangkat kurang dari [jarakMinKirimHitung]
  /// lalu.
  Timer? _jarak;

  /// Generasi yang jedanya sudah lewat tapi menunggu [_jarak] habis.
  int? _antre;

  /// Sesudah 429: TIDAK ada kiriman otomatis. Edit tetap tercatat (tampil
  /// sementara) dan baru dikirim lewat "Coba lagi" ([hitungUlang]) — tanpa
  /// ini tiap edit berikutnya memukul server yang baru saja menolak.
  /// Header `Retry-After` tidak terbaca di sini: `ApiException` tidak
  /// membawa header, dan jawaban 429 `studio-hitung` (callback
  /// `perMenitPengguna` di API) tidak menyertakannya.
  bool _ditahan = false;

  @override
  KeadaanSimulasi build() {
    ref.watch(authProvider.select((a) => a.value?.id));
    _riwayat.clear();
    _ulang.clear();
    _jeda?.cancel();
    _jarak?.cancel();
    _antre = null;
    _ditahan = false;
    _generasi++;
    _terhitung = null;
    ref.onDispose(() {
      _jeda?.cancel();
      _jarak?.cancel();
      _generasi++;
    });
    return KeadaanSimulasi.awal;
  }

  /// Terapkan edit (satu sel, atau satu rentang dikosongkan) sebagai SATU
  /// langkah urung. `false` = DITOLAK karena edit yang berlaku akan melebihi
  /// [batasEditSimulasi]; tidak ada yang berubah. Isi yang sama dengan edit
  /// yang berlaku diabaikan.
  bool terapkan(Map<KunciEditSel, String> isi) {
    final baru = Map.of(state.edit);
    final perubahan = <PerubahanEdit>[];
    for (final e in isi.entries) {
      final lama = baru[e.key];
      if (lama == e.value) continue;
      perubahan.add((kunci: e.key, sebelum: lama, sesudah: e.value));
      baru
        ..remove(e.key)
        ..[e.key] = e.value;
    }
    if (perubahan.isEmpty) return true;
    if (baru.length > batasEditSimulasi) return false;
    _riwayat.add(perubahan);
    _ulang.clear();
    _pasang(baru);
    return true;
  }

  /// Ctrl+Z — juga "batalkan edit terakhir" sesudah 409/422/504.
  void urungkan() {
    if (_riwayat.isEmpty) return;
    final p = _riwayat.removeLast();
    _ulang.add(p);
    _pasang(_jalankan(p, mundur: true));
  }

  /// Ctrl+Y.
  void ulangi() {
    if (_ulang.isEmpty) return;
    final p = _ulang.removeLast();
    _riwayat.add(p);
    _pasang(_jalankan(p, mundur: false));
  }

  /// Hapus SEMUA edit — grid kembali ke snapshot impor.
  void reset() {
    if (state.edit.isEmpty && _riwayat.isEmpty && _ulang.isEmpty) return;
    _riwayat.clear();
    _ulang.clear();
    _pasang(const {});
  }

  /// Kirim ulang edit yang berlaku (sesudah 429/504/jaringan) — juga
  /// melepas tahanan 429. Tetap lewat jeda & [jarakMinKirimHitung]: menekan
  /// "Coba lagi" berkali-kali tidak menjadi rentetan POST.
  void hitungUlang() {
    _ditahan = false;
    if (state.edit.isNotEmpty) _jadwalkan();
  }

  Map<KunciEditSel, String> _jalankan(
    List<PerubahanEdit> p, {
    required bool mundur,
  }) {
    final baru = Map.of(state.edit);
    for (final u in mundur ? p.reversed : p) {
      final isi = mundur ? u.sebelum : u.sesudah;
      baru.remove(u.kunci);
      if (isi != null) baru[u.kunci] = isi;
    }
    return baru;
  }

  void _pasang(Map<KunciEditSel, String> edit) {
    final tetap = Map<KunciEditSel, String>.unmodifiable(edit);
    final s = state;
    state = KeadaanSimulasi(
      edit: tetap,
      hasil: s.hasil,
      overlay: susunOverlay(s.hasil, tetap, _terhitung),
      menghitung: s.menghitung,
      galat: s.galat,
      bisaUrungkan: _riwayat.isNotEmpty,
      bisaUlangi: _ulang.isNotEmpty,
    );
    _jadwalkan();
  }

  void _jadwalkan() {
    _jeda?.cancel();
    _antre = null;
    final generasi = ++_generasi;
    final s = state;
    if (s.edit.isEmpty) {
      _terhitung = null;
      // Tanpa edit tidak ada yang ditahan; edit berikutnya dikirim biasa
      // (kena 429 lagi = ditahan lagi).
      _ditahan = false;
      state = KeadaanSimulasi(
        bisaUrungkan: s.bisaUrungkan,
        bisaUlangi: s.bisaUlangi,
      );
      return;
    }
    if (_ditahan) {
      // Galat 429 & "Coba lagi" tetap tampil; edit baru hanya sementara.
      state = KeadaanSimulasi(
        edit: s.edit,
        hasil: s.hasil,
        overlay: s.overlay,
        galat: s.galat,
        bisaUrungkan: s.bisaUrungkan,
        bisaUlangi: s.bisaUlangi,
      );
      return;
    }
    state = KeadaanSimulasi(
      edit: s.edit,
      hasil: s.hasil,
      overlay: s.overlay,
      menghitung: true,
      bisaUrungkan: s.bisaUrungkan,
      bisaUlangi: s.bisaUlangi,
    );
    _jeda = Timer(jedaKirimHitung, () => _kirimBilaBoleh(generasi));
  }

  /// Kirim sekarang, atau antre sampai [_jarak] habis. Yang antre hanya
  /// generasi TERAKHIR — edit yang lebih baru menggantikannya.
  void _kirimBilaBoleh(int generasi) {
    if (_jarak?.isActive ?? false) {
      _antre = generasi;
      return;
    }
    _jarak = Timer(jarakMinKirimHitung, () {
      final g = _antre;
      _antre = null;
      if (g != null && g == _generasi && !_ditahan) _kirimBilaBoleh(g);
    });
    unawaited(_kirim(generasi));
  }

  Future<void> _kirim(int generasi) async {
    final layanan = ref.read(workbookServiceProvider);
    final simpanan = ref.read(tokenStorageProvider);
    final edit = state.edit;
    try {
      final token = await simpanan.read();
      if (token == null) throw const TokenHilangException();
      final hasil = await layanan.hitung(
        token,
        workbookId: workbookId,
        edit: [
          for (final e in edit.entries)
            (
              lembarId: e.key.lembarId,
              alamat: AlamatSel(e.key.baris, e.key.kolom),
              isi: e.value,
            ),
        ],
      );
      if (!ref.mounted || generasi != _generasi) return;
      _terhitung = edit;
      final s = state;
      state = KeadaanSimulasi(
        edit: s.edit,
        hasil: hasil,
        overlay: susunOverlay(hasil, s.edit, edit),
        bisaUrungkan: s.bisaUrungkan,
        bisaUlangi: s.bisaUlangi,
      );
    } catch (e) {
      if (!ref.mounted || generasi != _generasi) return;
      final galat = GalatSimulasi.dari(e);
      if (galat.jenis == JenisGalatSimulasi.terlaluSering) _ditahan = true;
      final s = state;
      state = KeadaanSimulasi(
        edit: s.edit,
        hasil: s.hasil,
        overlay: s.overlay,
        galat: galat,
        bisaUrungkan: s.bisaUrungkan,
        bisaUlangi: s.bisaUlangi,
      );
    }
  }
}
