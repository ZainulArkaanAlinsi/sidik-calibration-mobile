/// Baca lembar kerja APA PUN jadi skema form — `POST /api/dokumen/baca`.
///
/// Beda dari [WorksheetScanService] yang jalur utamanya: yang itu butuh
/// template yang sudah dikenal plus koordinat sel yang diukur dari kertas
/// cetaknya, dan menolak lembar yang belum punya profil. Yang ini nggak butuh
/// dua-duanya — bentuk formnya menyusul dari isi kertas.
///
/// ## Fotonya KELUAR dari HP, dan itu nggak sepele
///
/// Endpoint ini meneruskan foto ke layanan AI pihak ketiga, dan yang dikirim
/// SELURUH HALAMAN — bukan cuma potongan sel seperti jalur lokal. Kop surat,
/// nama pelanggan, dan nomor sertifikat ikut di dalamnya.
///
/// Server menutupnya lewat `VISION_AKTIF=false`, saklar yang sama dengan jalur
/// AI Vision. Waktu tertutup, jawabannya 503 `dimatikan` — dan layar HARUS
/// menjelaskan itu apa adanya, bukan menyuruh teknisi foto ulang buat sesuatu
/// yang mustahil berhasil.
library;

import 'dart:io';

import '../models/skema_dinamis.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Kenapa satu pembacaan gagal. Dibedakan karena tindakan lanjutannya BEDA.
enum GagalBacaDokumen {
  /// Server menutup jalur ini (`VISION_AKTIF=false`). Foto ulang nggak nolong.
  dimatikan,

  /// Kunci API belum diisi di server. Salah setup, bukan salah teknisi.
  salahSetup,

  /// Layanan sibuk / kuota habis. Fotonya nggak perlu diulang.
  layananBermasalah,

  /// Fotonya memang nggak kebaca. Ini yang pantas dijawab "foto ulang".
  takTerbaca,

  /// Jaringan, timeout, atau server nggak nyaut.
  jaringan,
}

class HasilBacaDokumen {
  const HasilBacaDokumen.berhasil(this.skema) : gagal = null, pesan = null;

  const HasilBacaDokumen.gagal(this.gagal, this.pesan) : skema = null;

  final SkemaDinamis? skema;
  final GagalBacaDokumen? gagal;
  final String? pesan;

  bool get berhasil => skema != null;
}

class DokumenGenerikService {
  const DokumenGenerikService(this._api);

  final ApiClient _api;

  /// [namaAlat] cuma KONTEKS buat AI, bukan penentu bentuk formnya. Kalau isi
  /// lembarnya menunjukkan alat lain, yang menang lembarnya — dan bedanya
  /// datang balik sebagai peringatan di [SkemaDinamis.peringatan].
  Future<HasilBacaDokumen> baca({
    required File foto,
    String? namaAlat,
    String? token,
  }) async {
    try {
      final json = await _api.unggahFile(
        '/dokumen/baca',
        field: 'foto',
        filePath: foto.path,
        fields: {
          if (namaAlat != null && namaAlat.isNotEmpty) 'nama_alat': namaAlat,
        },
        token: token,
        // Selembar penuh lebih besar dari potongan sel, dan modelnya butuh
        // waktu lebih lama buat memahami seluruh halaman.
        timeout: const Duration(seconds: 90),
      );

      final data = json['data'];

      if (data is! Map) {
        return const HasilBacaDokumen.gagal(
          GagalBacaDokumen.takTerbaca,
          'Jawaban server nggak berisi hasil baca.',
        );
      }

      return HasilBacaDokumen.berhasil(
        SkemaDinamis.fromJson(Map<String, dynamic>.from(data)),
      );
    } on ApiException catch (e) {
      // Pesan dari `pesan` diutamakan: itu kalimat yang ditulis buat teknisi,
      // sedangkan `e.message` kalimat umum yang disusun ApiClient dari kode
      // HTTP-nya.
      final pesan = e.body['pesan'];

      return HasilBacaDokumen.gagal(
        _kenapa(e),
        pesan is String && pesan.isNotEmpty ? pesan : e.message,
      );
    } catch (_) {
      return const HasilBacaDokumen.gagal(
        GagalBacaDokumen.jaringan,
        'Nggak bisa nyambung ke server. Cek koneksi lalu coba lagi.',
      );
    }
  }

  /// `status` dari bodi -> sebab yang bisa ditindaklanjuti.
  ///
  /// Dibaca dari KODE STATUS, bukan dari kalimat pesannya. Menebak lewat teks
  /// ("ada kata 'sibuk' nggak?") itu rapuh dua arah: kalimatnya bisa diubah
  /// kapan saja tanpa siapa pun ingat ada kode yang membacanya, dan kalimat
  /// yang kebetulan mirip bisa salah dikenali. Kode statusnya bagian dari
  /// kontrak; kalimatnya buat manusia.
  ///
  /// 503 sengaja dipecah dua karena tindakan lanjutannya BERLAWANAN: jalur
  /// yang ditutup lab (nunggu nggak nolong, pakai jalur lain) versus kunci API
  /// belum diisi (admin yang harus bertindak).
  GagalBacaDokumen _kenapa(ApiException e) {
    return switch (e.body['status']) {
      'dimatikan' => GagalBacaDokumen.dimatikan,
      'salah_setup' => GagalBacaDokumen.salahSetup,
      // Penyedianya yang bermasalah — sibuk, kuota habis, atau nggak
      // kesambung. Fotonya NGGAK perlu diulang.
      'gagal' => GagalBacaDokumen.layananBermasalah,
      // AI menolak memproses, atau jawabannya nggak bisa diurai. Dua-duanya
      // berujung sama buat teknisi: isi manual atau foto ulang lebih jelas.
      'ditolak' || 'tak_terbaca' => GagalBacaDokumen.takTerbaca,
      _ =>
        e.status == 422
            ? GagalBacaDokumen.takTerbaca
            : GagalBacaDokumen.jaringan,
    };
  }
}
