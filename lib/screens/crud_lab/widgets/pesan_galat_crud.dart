import '../../../l10n/app_localizations.dart';
import '../../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../../services/auth_service.dart'
    show ApiException, AuthException, KoneksiException;
import '../../../services/kode_galat.dart' show kodeDariBadan;
import '../../../widgets/status_badge.dart';

/// Kode galat bisnis server untuk CRUD lengkap (kontrak
/// `docs/perintah-frontend-crud-lengkap.md` §7). Percabangan UI memakai KODE,
/// bukan isi `message` — teksnya boleh diperbaiki server kapan saja.
abstract final class KodeCrud {
  static const namaKategoriKembar = 'nama_kategori_kembar';
  static const kategoriDipakai = 'kategori_dipakai';
  static const kategoriNonaktif = 'kategori_nonaktif';
  static const kodeKategoriBentrok = 'kode_kategori_bentrok';
  static const bukanDraf = 'bukan_draf';
  static const pernahDikirim = 'pernah_dikirim';
  static const tidakDiarsipkan = 'tidak_diarsipkan';
  static const statusBerubah = 'status_berubah';
  static const hanyaAdmin = 'hanya_admin';
  static const penugasanTidakAktif = 'penugasan_tidak_aktif';
  static const penugasanSudahSelesai = 'penugasan_sudah_selesai';
  static const itemSudahDikerjakan = 'item_sudah_dikerjakan';
}

/// Kalimat untuk galat apa pun dari aksi CRUD.
///
/// - Kode bisnis yang dikenal → kalimat lokal yang menyebut jalan keluarnya.
/// - `403`/`404`/`409`/`429`/`5xx` → kalimat lokal; `404` selalu "mungkin sudah
///   berubah" (server menjawab 404 untuk milik lab lain juga).
/// - `422` tanpa kode → kalimat pertama dari `errors`, atau pesan server.
/// - [ditolak422] mengganti SEMUA `422` tanpa kode (mis. hapus order yang
///   alatnya sudah masuk kalibrasi: server menjawab 422 tanpa kode).
/// - [simpanBaru] true untuk POST yang tidak boleh diulang buta: galat jaringan
///   diganti kalimat "periksa daftar dulu" supaya tidak lahir data kembar.
String pesanGalatCrud(
  AppLocalizations l10n,
  Object galat, {
  String? ditolak422,
  bool simpanBaru = false,
}) {
  if (galat is TokenHilangException) return l10n.historySessionExpired;

  if (galat is ApiException) {
    final badan = galat.body;
    switch (kodeDariBadan(badan)) {
      case KodeCrud.namaKategoriKembar:
        // Yang kembar nonaktif: arahkan ke "Aktifkan kembali", bukan sekadar
        // menolak nama (server memberi tahu lewat `kategori.aktif`).
        final kembar = badan['kategori'];
        return kembar is Map && kembar['aktif'] == false
            ? l10n.crudGalatKategoriKembarNonaktif
            : l10n.crudGalatKategoriKembar;
      case KodeCrud.kategoriDipakai:
        return l10n.crudGalatKategoriDipakai(_rincianPemakai(l10n, badan));
      case KodeCrud.kategoriNonaktif:
        return l10n.crudGalatKategoriNonaktif;
      case KodeCrud.kodeKategoriBentrok:
        return l10n.crudGalatKodeBentrok;
      case KodeCrud.bukanDraf:
        return l10n.crudGalatBukanDraf(_statusTeks(l10n, badan['status']));
      case KodeCrud.pernahDikirim:
        return l10n.crudGalatPernahDikirim;
      case KodeCrud.tidakDiarsipkan:
        return l10n.crudGalatTidakDiarsipkan;
      case KodeCrud.statusBerubah:
        return l10n.crudGalatStatusBerubah;
      case KodeCrud.hanyaAdmin:
        return l10n.crudGalatHanyaAdmin;
      case KodeCrud.penugasanTidakAktif:
        return l10n.crudGalatPenugasanTidakAktif(
          _statusTeks(l10n, badan['status']),
        );
      case KodeCrud.penugasanSudahSelesai:
        return l10n.crudGalatPenugasanSelesai;
      case KodeCrud.itemSudahDikerjakan:
        return l10n.crudGalatItemSudahDikerjakan;
    }
    if (galat.status == 401) return l10n.historySessionExpired;
    if (galat.status == 403) return l10n.crudGalat403;
    if (galat.status == 404) return l10n.saGalatTidakAda;
    if (galat.status == 409) return l10n.crudGalat409;
    if (galat.status == 429) return l10n.crudGalat429;
    if (galat.status >= 500) return l10n.crudGalat500;
    if (galat.status == 422) {
      if (ditolak422 != null) return ditolak422;
      return _pesanValidasi(badan) ?? galat.message;
    }
    return galat.message;
  }

  if (galat is KoneksiException) {
    return simpanBaru ? l10n.crudGalatKoneksiSimpan : l10n.crudGalatKoneksi;
  }
  if (galat is AuthException && galat.message.isNotEmpty) return galat.message;
  return l10n.saGalatUmum;
}

/// Galat yang artinya daftar di layar sudah basi dan perlu diambil ulang.
bool perluMuatUlangCrud(Object galat) {
  if (galat is! ApiException) return false;
  if (galat.status == 404 || galat.status == 409) return true;
  final kode = kodeDariBadan(galat.body);
  return kode == KodeCrud.tidakDiarsipkan ||
      kode == KodeCrud.bukanDraf ||
      kode == KodeCrud.statusBerubah ||
      kode == KodeCrud.penugasanTidakAktif ||
      kode == KodeCrud.penugasanSudahSelesai;
}

/// Pesan pertama kolom [kunci] dari badan 422 Laravel (`errors.<kolom>[0]`).
/// [kunci] boleh bertitik (`items.0.id`); `null` bila tidak ada.
String? pesanKolomCrud(ApiException e, String kunci) {
  final errors = e.body['errors'];
  if (errors is! Map) return null;
  final nilai = errors[kunci];
  if (nilai is List && nilai.isNotEmpty) return '${nilai.first}';
  if (nilai is String && nilai.isNotEmpty) return nilai;
  return null;
}

/// Pesan validasi pertama dari semua kolom `errors`, urutan server.
String? _pesanValidasi(Map<String, dynamic> badan) {
  final errors = badan['errors'];
  if (errors is! Map) return null;
  for (final nilai in errors.values) {
    if (nilai is List && nilai.isNotEmpty) return '${nilai.first}';
    if (nilai is String && nilai.isNotEmpty) return nilai;
  }
  return null;
}

String _statusTeks(AppLocalizations l10n, Object? status) {
  if (status is! String || status.isEmpty) return '-';
  return StatusBadge.labelApi(status, l10n);
}

/// " (3 alat, 1 kemampuan)" dari `pemakai` (`kategori_dipakai`); hanya yang
/// > 0. Kosong bila server tidak merinci.
String _rincianPemakai(AppLocalizations l10n, Map<String, dynamic> badan) {
  final pemakai = badan['pemakai'];
  if (pemakai is! Map) return '';
  int n(String k) => (pemakai[k] as num?)?.toInt() ?? 0;
  final bagian = <String>[
    if (n('alat') > 0) l10n.crudPemakaiAlat(n('alat')),
    if (n('kemampuan') > 0) l10n.crudPemakaiKemampuan(n('kemampuan')),
    if (n('penugasan') > 0) l10n.crudPemakaiPenugasan(n('penugasan')),
    if (n('metode') > 0) l10n.crudPemakaiMetode(n('metode')),
    if (n('rumus') > 0) l10n.crudPemakaiRumus(n('rumus')),
  ];
  return bagian.isEmpty ? '' : ' (${bagian.join(', ')})';
}
