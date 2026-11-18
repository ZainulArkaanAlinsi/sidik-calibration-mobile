import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/arsip_draf_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../super_admin/widgets/dialog_isian.dart';
import 'widgets/pesan_galat_crud.dart';

/// Arsipkan satu draf lembar kerja lewat dialog alasan (5–400 karakter).
/// `true` bila terarsip (server idempoten: draf yang sudah diarsipkan juga
/// dijawab 200).
///
/// Mengarsipkan BUKAN hapus: pembacaan mentah, nomor sesi, dan hasil hitung
/// tidak dihapus, dan Master Data bisa memulihkan. Galat server tampil DI
/// dalam dialog dengan isian alasan tetap utuh (`bukan_draf`, `status_berubah`,
/// 404, dst). [saatSelesai] dipanggil sesudah sukses supaya pemanggil
/// menyegarkan daftarnya sendiri.
Future<bool> arsipkanDrafCrud(
  BuildContext context,
  WidgetRef ref, {
  required int id,
  required String nama,
  VoidCallback? saatSelesai,
  VoidCallback? saatBasi,
}) async {
  final l10n = AppLocalizations.of(context);
  // Dibaca SEBELUM dialog dibuka: galat `bukan_draf`/404 menyegarkan daftar
  // (kartu pemilik `ref` ini terbuang), lalu percobaan ulang di dialog yang
  // masih terbuka tidak boleh memakai `ref` yang sudah mati.
  final penyimpanToken = ref.read(tokenStorageProvider);
  final layanan = ref.read(arsipDrafServiceProvider);
  final ok = await tampilkanDialogIsian(
    context,
    judul: l10n.crudDrafArsipkanJudul(nama),
    isi: l10n.crudDrafArsipkanIsi,
    labelKolom: l10n.crudAlasanWajib,
    catatan: l10n.crudAlasanCatatan,
    labelAksi: l10n.crudDrafArsipkanAksi,
    destruktif: true,
    panjangMinimal: 5,
    panjangMaksimal: 400,
    pesanPendek: l10n.crudAlasanPendek,
    pesanPanjang: l10n.crudAlasanPanjang,
    petakanGalat: (e) => pesanGalatCrud(l10n, e),
    aksi: (alasan) async {
      final token = await penyimpanToken.read();
      if (token == null) throw const TokenHilangException();
      await layanan.arsipkan(token, id, alasan: alasan);
    },
    saatGalat: (e) {
      // Sesi sudah bukan draf / sudah hilang: daftar di layar basi.
      if (perluMuatUlangCrud(e)) saatBasi?.call();
    },
  );
  if (!ok) return false;

  // Kabar dulu, baru segarkan daftar: penyegaran membuang kartu (dan
  // `context`-nya) sebelum snackbar sempat dipasang.
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.crudDrafArsipkanBerhasil)));
  }
  saatSelesai?.call();
  return true;
}
