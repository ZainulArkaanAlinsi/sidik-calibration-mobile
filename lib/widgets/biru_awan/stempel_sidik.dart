import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import '../sidik/status_tampil.dart';

/// Stempel status Biru Awan: pil 30, ikon 14 + kata 12/700 (`Komponen.dc.html`).
///
/// Nada dan kata TIDAK dibuat di sini: dipakai pemetaan status yang sudah ada
/// ([StatusTampil.dariKode], [StatusTampil.jadwal]) sehingga satu status satu
/// tampilan di seluruh app. Yang baru hanya penggambarannya:
///
/// | Nada | Isi | Tinta |
/// |---|---|---|
/// | lulus | hijau | navy |
/// | awas | kuning | navy |
/// | tunggu | awan | navy |
/// | gagal (lewat jadwal, ditolak, ...) | koral | navy |
/// | netral | netralStempel | navy |
/// | **FAIL** (`KataStatus.fail`) | navy pekat | putih |
///
/// FAIL "tidak dilunakkan" (`DESIGN.md`): tidak memakai koral. Ini menutup
/// utang `standar-kualitas-desain.md` §11 butir 12 untuk komponen baru; stempel
/// lama (`widgets/sidik/stempel.dart`) tidak diubah.
///
/// Status selalu ikon + kata, tidak pernah warna saja. Stempel bukan tombol:
/// pembaca layar menerima "Status: kata" tanpa aksi ketuk. Tinggi 30 adalah
/// minimum; kata panjang ("Masa berlaku berakhir") membungkus dan stempel
/// tumbuh, tidak dipotong.
///
/// Hasil ukur TIDAK dihitung di sini: nada dari kode status atau keputusan yang
/// dilewatkan pemanggil (dari server).
class StempelSidik extends StatelessWidget {
  /// Dari status yang sudah dipetakan (`StatusTampil.dariKode('menunggu_approval')`).
  const StempelSidik(this.status, {super.key})
    : _teks = null,
      _nada = null,
      _ikon = null,
      _tanpaKeputusan = false;

  /// Teks bebas dengan nada yang dipilih pemanggil, untuk penanda yang bukan
  /// status baku ("1 FAIL", "Belum tersinkron", "Lagi di sini"). Ikon wajib:
  /// status tidak boleh hanya warna.
  const StempelSidik.teks({
    super.key,
    required String teks,
    required NadaStempel nada,
    required IconData ikon,
  }) : status = null,
       _teks = teks,
       _nada = nada,
       _ikon = ikon,
       _tanpaKeputusan = false;

  /// Vonis hasil kalibrasi dari server (`PratinjauHitung`, detail sesi).
  ///
  /// - `'PASS'`: hijau. `'FAIL'`: navy pekat (FAIL tidak dilunakkan).
  /// - **`null` atau `''`: netral "Tanpa PASS/FAIL"; tidak pernah hijau** dan
  ///   tidak pernah FAIL.
  /// - Nilai lain TIDAK disaring: diteruskan apa adanya ke
  ///   [StatusTampil.dariKode], jadi kode status yang dikenal mengikuti
  ///   pemetaan itu, termasuk yang HIJAU (`disetujui`, `terbit`, `selesai`,
  ///   `aktif`, `valid`/`berlaku`) dan yang koral (`overdue`, `expired`).
  ///   Hanya kode yang tidak dikenal, termasuk ejaan lain (`pass`, `Fail`,
  ///   `LULUS?`), tampil apa adanya dengan nada netral.
  ///
  /// Karena itu pemanggil melewatkan vonis (`'PASS'`, `'FAIL'`, atau `null`),
  /// bukan status sesi. Pemetaan dikunci `test/biru_awan/stempel_sidik_test.dart`.
  StempelSidik.keputusan(String? keputusan, {super.key})
    : status = (keputusan == null || keputusan.isEmpty)
          ? null
          : StatusTampil.dariKode(keputusan),
      _teks = null,
      _nada = null,
      _ikon = null,
      _tanpaKeputusan = keputusan == null || keputusan.isEmpty;

  final StatusTampil? status;
  final String? _teks;
  final NadaStempel? _nada;
  final IconData? _ikon;
  final bool _tanpaKeputusan;

  /// Nada yang akhirnya digambar untuk stempel ini.
  NadaStempel get nada => status?.nada ?? _nada ?? NadaStempel.netral;

  /// `true` bila digambar sebagai FAIL navy pekat.
  bool get adalahFail => status?.kata == KataStatus.fail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final w = WarnaBiruAwan.of(context);
    final skala = MediaQuery.textScalerOf(context);

    final String kata;
    final IconData ikon;
    if (status != null) {
      kata = status!.label(l10n);
      ikon = status!.ikon;
    } else if (_tanpaKeputusan) {
      kata = l10n.biruAwanTanpaKeputusan;
      ikon = Icons.remove_circle_outline;
    } else {
      kata = _teks!;
      ikon = _ikon!;
    }

    final Color isi;
    final Color tinta;
    if (adalahFail) {
      isi = w.isiFail;
      tinta = w.tintaFail;
    } else {
      final pilihan = switch (nada) {
        NadaStempel.lulus => IsiBiruAwan.hijau,
        NadaStempel.awas => IsiBiruAwan.kuning,
        NadaStempel.tunggu => IsiBiruAwan.awan,
        NadaStempel.gagal => IsiBiruAwan.koral,
        NadaStempel.netral => IsiBiruAwan.netral,
      };
      isi = w.isi(pilihan);
      tinta = w.tinta(pilihan);
    }

    return Semantics(
      label: l10n.stempelSemantik(kata),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: UkuranBiruAwan.stempel),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isi,
            borderRadius: BorderRadius.circular(BentukBiruAwan.pil),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: JarakBiruAwan.blok,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ikon,
                  size: skala.scale(UkuranKomponenBiruAwan.ikonStempel),
                  color: tinta,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    kata,
                    style: HurufBiruAwan.stempel.copyWith(color: tinta),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
