import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Daftarin & cabut perangkat ini di server, biar boleh dikirimi push.
///
/// Push cuma nutup SATU keadaan: HP dengan aplikasi ketutup total. Selama
/// aplikasinya jalan, kabarnya udah nyampe lewat websocket Reverb.
abstract class PendaftaranPush {
  /// `POST /api/device-tokens`. Idempoten — aman dipanggil tiap app kebuka.
  Future<void> daftar(String tokenAkun, String tokenPerangkat);

  /// `DELETE /api/device-tokens`. Dipanggil waktu LOGOUT.
  Future<void> cabut(String tokenAkun, String tokenPerangkat);
}

class ApiPendaftaranPush implements PendaftaranPush {
  ApiPendaftaranPush(this._api);

  final ApiClient _api;

  @override
  Future<void> daftar(String tokenAkun, String tokenPerangkat) async {
    try {
      await _api.post(
        '/device-tokens',
        body: {'token': tokenPerangkat, 'platform': platformSekarang()},
        token: tokenAkun,
      );
    } catch (_) {
      // Ditelan. Gagal daftar itu artinya push-nya nggak nyampe — bukan
      // aplikasinya rusak. Notifikasinya tetap masuk daftar, loncengnya tetap
      // nyala, dan selama aplikasinya kebuka Reverb tetap ngabarin.
      //
      // Kalau dilempar, yang mati bukan push-nya doang: pemanggilnya jalan di
      // alur login, dan satu kegagalan di sini bikin orang nggak bisa masuk
      // cuma gara-gara layanan notifikasi lagi ngadat.
    }
  }

  @override
  Future<void> cabut(String tokenAkun, String tokenPerangkat) async {
    try {
      await _api.delete(
        '/device-tokens',
        token: tokenAkun,
        body: {'token': tokenPerangkat},
      );
    } catch (_) {
      // Sama: logout NGGAK BOLEH gagal gara-gara ini. Orang yang nekan logout
      // harus beneran keluar, apa pun kata server soal token perangkatnya.
      //
      // Konsekuensinya ditanggung sadar: token yang gagal dicabut masih
      // terdaftar di server sampai FCM nolak dia permanen. Itu sebabnya server
      // MEMINDAHKAN kepemilikan token waktu orang lain login di HP yang sama,
      // bukan cuma nambah baris — HP yang dipakai gantian nggak boleh nerima
      // kabar kerja orang sebelumnya.
    }
  }
}

/// Nama platform yang dikenal server (`DeviceToken::PLATFORM`).
///
/// Dipakai server buat milih bentuk muatan push, bukan sekadar statistik —
/// jadi salah nama di sini bikin kirimannya ditolak 422, bukan cuma bikin
/// laporan meleset.
String platformSekarang() {
  if (kIsWeb) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  return 'android';
}

/// Versi test & mode mock — nyatet apa yang mestinya dikirim ke server.
class MockPendaftaranPush implements PendaftaranPush {
  final List<String> didaftarkan = [];
  final List<String> dicabut = [];

  @override
  Future<void> daftar(String tokenAkun, String tokenPerangkat) async {
    didaftarkan.add(tokenPerangkat);
  }

  @override
  Future<void> cabut(String tokenAkun, String tokenPerangkat) async {
    dicabut.add(tokenPerangkat);
  }
}
