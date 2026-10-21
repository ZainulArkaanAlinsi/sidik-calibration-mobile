import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/data_acuan/daftar_paket_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/widgets/keadaan_acuan.dart';

import '../data/workbook_provider.dart';
import '../l10n/studio_l10n.dart';
import 'beranda/beranda_screen.dart';
import 'workbook/daftar_workbook_screen.dart';

/// Seksi navigasi Studio, urut sidebar `04-UI-UX-Flow.md` §2.2.
///
/// Seksi yang BELUM dibangun tetap terlihat, tapi nonaktif dan berlabel jujur
/// tahapnya ([tahap]) — tidak ada layar tiruan di baliknya. Begitu tahapnya
/// mendarat, [tahap] dikosongkan dan [bangun] diisi.
enum SeksiStudio {
  beranda(Icons.home_outlined, Icons.home),
  kelolaData(Icons.table_chart_outlined, Icons.table_chart, tahap: 'S2'),
  dataAcuan(Icons.dataset_outlined, Icons.dataset),
  // S1b: workbook master per alat, mode Asli Excel, baca saja (K-49-08).
  workbookAlat(Icons.grid_on_outlined, Icons.grid_on),
  lembarHitung(Icons.functions_outlined, Icons.functions, tahap: 'S4'),
  pengesahan(Icons.verified_outlined, Icons.verified, tahap: 'S3'),
  impor(Icons.upload_file_outlined, Icons.upload_file, tahap: 'S5'),
  // ST-T-017 (S1, tugas tersendiri).
  pengaturan(Icons.settings_outlined, Icons.settings, tahap: 'S1');

  const SeksiStudio(this.ikon, this.ikonAktif, {this.tahap});

  final IconData ikon;
  final IconData ikonAktif;

  /// Kode tahap rencana re-scope (`06-rencana-rescope.md`) bila seksi ini
  /// belum dibangun. `null` = seksi sudah punya layar.
  final String? tahap;

  bool get tersedia => tahap == null;

  String label(StudioL10n l10n) => switch (this) {
    SeksiStudio.beranda => l10n.seksiBeranda,
    SeksiStudio.kelolaData => l10n.seksiKelolaData,
    SeksiStudio.dataAcuan => l10n.seksiDataAcuan,
    SeksiStudio.workbookAlat => l10n.seksiWorkbookAlat,
    SeksiStudio.lembarHitung => l10n.seksiLembarHitung,
    SeksiStudio.pengesahan => l10n.seksiPengesahan,
    SeksiStudio.impor => l10n.seksiImpor,
    SeksiStudio.pengaturan => l10n.seksiPengaturan,
  };

  /// Gerbang izin per seksi — izin DARI SERVER (`/me/permissions`), sama
  /// persis dengan gerbang yang dipakai app lapangan untuk data acuan
  /// (`bolehBukaDataAcuan`, cadangan `false`). Seksi yang tidak boleh TIDAK
  /// TAMPIL (FR-STU-012). Menyembunyikan menu bukan kontrol akses; server
  /// tetap menolak sendiri.
  ///
  /// Beranda milik semua peran internal (ST-02); isinya digerbangi per kartu.
  ///
  /// Seksi tahap mendatang belum punya nama izin di server: mereka tampil
  /// NONAKTIF (cangkang tidak bertanya `boleh` untuknya). Begitu [tahap]
  /// dikosongkan tanpa gerbang, seksi itu jatuh ke cabang terakhir — TIDAK
  /// TAMPIL untuk siapa pun — dan `test/seksi_gerbang_test.dart` merah. Jadi
  /// lupa memasang gerbang gagal tertutup, bukan terbuka diam-diam.
  bool boleh(WidgetRef ref) => switch (this) {
    SeksiStudio.beranda => true,
    SeksiStudio.dataAcuan => bolehBukaDataAcuan(ref),
    SeksiStudio.workbookAlat => bolehBukaWorkbook(ref),
    _ when !tersedia => true,
    _ => false,
  };

  /// Nama izin server yang menggerbangi seksi ini; `null` = Beranda (milik
  /// semua peran internal) atau seksi tahap mendatang. Dipakai test penjaga
  /// gerbang — harus sama dengan yang dibaca [boleh].
  String? get namaIzin => switch (this) {
    SeksiStudio.dataAcuan => NamaIzin.dataAcuanLihat,
    SeksiStudio.workbookAlat => izinWorkbookLihat,
    _ => null,
  };

  /// Layar akar seksi. Seksi tahap mendatang tidak punya layar.
  Widget? bangun() => switch (this) {
    SeksiStudio.beranda => const BerandaScreen(),
    SeksiStudio.dataAcuan => const DaftarPaketAcuanScreen(),
    SeksiStudio.workbookAlat => const DaftarWorkbookScreen(),
    SeksiStudio.kelolaData ||
    SeksiStudio.lembarHitung ||
    SeksiStudio.pengesahan ||
    SeksiStudio.impor ||
    SeksiStudio.pengaturan => null,
  };
}

/// Seksi yang dipilih pengguna. `null` = bawaan (seksi pertama yang bisa
/// dibuka — Beranda).
///
/// Provider, bukan state cangkang, supaya kartu Beranda bisa membuka seksi
/// lain. Kembali ke bawaan tiap akun berganti: akun berikutnya tidak mendarat
/// di seksi terakhir akun sebelumnya.
final pilihanSeksiStudioProvider =
    NotifierProvider<PilihanSeksiStudio, SeksiStudio?>(PilihanSeksiStudio.new);

class PilihanSeksiStudio extends Notifier<SeksiStudio?> {
  @override
  SeksiStudio? build() {
    ref.watch(authProvider.select((a) => a.value?.id));
    return null;
  }

  /// Seksi tahap mendatang tidak bisa dipilih.
  void pilih(SeksiStudio seksi) {
    if (seksi.tersedia) state = seksi;
  }
}
