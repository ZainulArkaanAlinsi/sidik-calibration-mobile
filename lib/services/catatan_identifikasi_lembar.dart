import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'jenis_lembar.dart';
import 'keputusan_pindai_lembar.dart';

/// CATATAN LOKAL identifikasi lembar dari foto: bahan kalibrasi ambang
/// (`identifikasi_lembar.dart`, target 26 Nov 2026) dan ambang auto-buka
/// ([ambangAutoBuka]) dengan kejadian nyata di lapangan.
///
/// Privasi (`sidik-fe-ocr-privasi-audit`): berkas ini TETAP di HP (folder
/// dukungan aplikasi), tidak diunggah, dan TIDAK memuat citra, byte foto,
/// nama pengguna, nama pelanggan, alat, atau isian lembar. Isinya hanya teks
/// CETAK formulir yang dibaca mesin (potongan kode/judul, paling banyak 32
/// karakter), skor, dan keputusan. Mengeluarkannya dari HP (kalau dibutuhkan
/// untuk kalibrasi) adalah keputusan terpisah, bukan efek samping berkas ini.
///
/// Gagal menulis TIDAK PERNAH menggagalkan alur pindai.
abstract class CatatanIdentifikasiLembar {
  /// Satu baris JSON. [kejadian] = `identifikasi` | `pilihan` | `ganti_jenis`
  /// | `baca_otomatis`.
  Future<void> tulis(
    String kejadian,
    String idPindai,
    Map<String, Object?> isi,
  );
}

/// Tidak menulis apa-apa (bawaan tes yang tidak berurusan dengan catatan).
class CatatanIdentifikasiKosong implements CatatanIdentifikasiLembar {
  const CatatanIdentifikasiKosong();

  @override
  Future<void> tulis(
    String kejadian,
    String idPindai,
    Map<String, Object?> isi,
  ) async {}
}

/// Menampung di memori (tes).
class CatatanIdentifikasiMemori implements CatatanIdentifikasiLembar {
  final baris = <Map<String, Object?>>[];

  @override
  Future<void> tulis(
    String kejadian,
    String idPindai,
    Map<String, Object?> isi,
  ) async {
    baris.add({'kejadian': kejadian, 'id_pindai': idPindai, ...isi});
  }
}

/// JSON Lines di folder dukungan aplikasi. Berkas dijaga kecil: lewat
/// [batasByte] hanya [sisaBaris] baris terakhir yang dipertahankan.
class CatatanIdentifikasiBerkas implements CatatanIdentifikasiLembar {
  CatatanIdentifikasiBerkas({
    this.folder,
    this.batasByte = 256 * 1024,
    this.sisaBaris = 300,
    DateTime Function()? jam,
  }) : _jam = jam ?? DateTime.now;

  /// `null` = folder dukungan aplikasi (`path_provider`).
  final Future<Directory> Function()? folder;
  final int batasByte;
  final int sisaBaris;
  final DateTime Function() _jam;

  static const namaBerkas = 'identifikasi_lembar.jsonl';

  /// Antrean tulis: kejadian beruntun (identifikasi lalu pilihan) tidak boleh
  /// saling menimpa waktu berkas dipangkas.
  Future<void> _antre = Future.value();

  @override
  Future<void> tulis(
    String kejadian,
    String idPindai,
    Map<String, Object?> isi,
  ) {
    final baris = jsonEncode({
      'waktu': _jam().toUtc().toIso8601String(),
      'kejadian': kejadian,
      'id_pindai': idPindai,
      ...isi,
    });

    return _antre = _antre.then((_) async {
      try {
        final dir = await (folder ?? getApplicationSupportDirectory)();
        final berkas = File('${dir.path}/$namaBerkas');
        await berkas.writeAsString('$baris\n', mode: FileMode.append);

        if (await berkas.length() > batasByte) {
          final semua = await berkas.readAsLines();
          final sisa = semua.length > sisaBaris
              ? semua.sublist(semua.length - sisaBaris)
              : semua;
          await berkas.writeAsString('${sisa.join('\n')}\n');
        }
      } catch (_) {
        // Catatan kalibrasi bukan alasan menggagalkan alur pindai.
      }
    });
  }
}

/// Ringkasan keputusan alur foto untuk catatan: tanpa citra, tanpa isian.
Map<String, Object?> ringkasIdentifikasi(
  HasilJenisLembar? hasil,
  KeputusanPindai keputusan,
) {
  final teratas = hasil != null && hasil.peringkat.isNotEmpty
      ? hasil.peringkat.first
      : null;

  return {
    'keputusan': switch (keputusan) {
      BukaOtomatis() => 'buka_otomatis',
      PilihSatu() => 'pilih_satu',
      TakDikenali() => 'tak_dikenali',
    },
    'alasan_mesin': hasil?.alasan?.name ?? 'tidak_ada_bukti',
    'sumber': hasil?.sumber.name,
    'kode_cocok': hasil?.kodeFormulir,
    'revisi_terbaca': hasil?.revisiTerbaca,
    'skor_teratas': teratas?.skor,
    'kandidat': [
      if (hasil != null)
        for (final k in hasil.peringkat)
          {
            'template_id': k.formulir.templateId,
            'skor': k.skor,
            'bukti': [
              for (final b in k.bukti)
                {
                  'lapis': b.lapis.name,
                  'mutu': b.mutu.name,
                  'skor': b.skor,
                  // Teks CETAK formulir yang dibaca (maks 32 karakter).
                  'terbaca': b.terbaca,
                },
            ],
          },
    ],
    'pra_pilih': hasil?.praPilihTemplateId,
    'ambang_auto_buka': ambangAutoBuka,
    if (keputusan case BukaOtomatis(:final formulir))
      'dibuka': formulir.templateId,
    if (keputusan case PilihSatu(:final kandidat, :final alasan)) ...{
      'alasan_pilih': alasan.name,
      'ditawarkan': [for (final k in kandidat) k.templateId],
    },
    if (keputusan case TakDikenali(:final alasan))
      'alasan_tak_dikenali': alasan.name,
  };
}
