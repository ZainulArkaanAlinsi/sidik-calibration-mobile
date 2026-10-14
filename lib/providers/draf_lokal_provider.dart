import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';
import '../services/auth_service.dart' show ApiException, gagalJaringan;
import '../services/draf_lokal.dart';
import '../services/pengirim_draf_service.dart';
import 'auth_provider.dart';
import 'history_provider.dart' show drafProvider;

/// Simpanan lembar kerja di HP — folder dukungan aplikasi, bukan folder
/// dokumen: isinya nama pelanggan & angka kalibrasi, jadi nggak boleh
/// kelihatan dari aplikasi Files. Alasan yang sama dengan
/// `penampungContohSelProvider`.
final simpananDrafLokalProvider = Provider<SimpananDrafLokal>(
  (ref) => SimpananDrafLokalBerkas(() async {
    final dasar = await getApplicationSupportDirectory();
    return Directory('${dasar.path}${Platform.pathSeparator}draf_lokal');
  }),
);

final pengirimDrafServiceProvider = Provider<PengirimDrafService>((ref) {
  if (AppConfig.useMock) return MockPengirimDrafService();
  return ApiPengirimDrafService(ref.watch(apiClientProvider));
});

/// Kunci salinan yang lagi DIBUKA di layar lembar kerja.
///
/// Pengirim antrean melewatinya: layar yang terbuka masih menulis ulang
/// salinannya, dan mengirim versi yang sedang diubah dari dua tempat sekaligus
/// cuma bikin server menerima dua kiriman yang saling susul.
final drafLokalTerbukaProvider = Provider<Set<String>>((ref) => <String>{});

/// Salinan di HP yang ditampilkan di layar Draf ("Belum tersinkron di HP
/// ini"), terbaru di atas.
///
/// Yang lahir dari sesi server dan cuma simpanan otomatis (`lokal`) NGGAK ikut:
/// sesinya sudah ada di daftar "Draf di server", dan membukanya dari sana
/// memulihkan isian HP ini juga. Dua baris untuk satu lembar cuma bikin
/// bingung yang mana yang benar.
///
/// `ref.watch(authProvider)` — data milik satu akun (sidik-fe-scope-akun).
final drafLokalProvider = FutureProvider<List<DrafLokal>>((ref) async {
  final userId = ref.watch(authProvider.select((s) => s.value?.id));
  if (userId == null) return const [];

  final semua = await ref.watch(simpananDrafLokalProvider).daftar(userId);

  return [
    for (final d in semua)
      if (d.sesiId == null || d.status != StatusDrafLokal.lokal) d,
  ];
});

/// Pengirim antrean draf offline — satu per akun yang login.
///
/// Dipasang di akar aplikasi (`SidikApp`), sama seperti pendaftaran push:
/// provider nggak jalan sampai ada yang membacanya. Dibangun ulang tiap yang
/// login BERGANTI ORANG (`select` id), dan di situ juga salinan akun lain di
/// HP ini dibuang (K-30-09).
final sinkronDrafLokalProvider = Provider<SinkronDrafLokal?>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.value?.id));
  if (userId == null) return null;

  late final SinkronDrafLokal sinkron;
  sinkron = SinkronDrafLokal(
    simpanan: ref.watch(simpananDrafLokalProvider),
    pengirim: ref.watch(pengirimDrafServiceProvider),
    userId: userId,
    terbuka: ref.watch(drafLokalTerbukaProvider),
    bacaToken: () async {
      if (sinkron.dibuang) return null;
      return ref.read(tokenStorageProvider).read();
    },
    setelahBerubah: () {
      if (sinkron.dibuang) return;
      ref.invalidate(drafProvider);
      ref.invalidate(drafLokalProvider);
    },
  );

  ref.onDispose(sinkron.dispose);
  unawaited(sinkron.mulai());

  return sinkron;
});

/// Ringkasan satu putaran kirim antrean.
class HasilSinkronDraf {
  const HasilSinkronDraf({
    this.terkirim = 0,
    this.ditolak = 0,
    this.gagalJaringan = false,
  });

  final int terkirim;
  final int ditolak;
  final bool gagalJaringan;
}

/// Mengirim draf yang tertahan di HP begitu servernya bisa dicapai.
///
/// Aturan yang dijaga, dan semuanya disengaja:
///
///  - **Cuma `status: draft`.** Dipaksa di sini, apa pun isi kirimannya.
///    Mengirim ke antrean admin itu keputusan sadar teknisi di depan alatnya,
///    bukan efek samping sinyal yang balik.
///  - **Satu putaran dalam satu waktu** ([jalankan] memulangkan putaran yang
///    lagi jalan).
///  - **422 / penolakan lain → `perlu_diperbaiki`, nggak diulang.**
///  - **401 → berhenti sampai login berikutnya** (provider-nya dibangun ulang
///    waktu login).
///  - **Gagal jaringan → berhenti, coba lagi dengan jeda mundur.**
///
/// ## Kenapa `POST` disusul `PUT`
///
/// Server mendedup `client_request_id`: kiriman kedua dengan kunci yang sama
/// memulangkan sesi LAMA apa adanya, tanpa membandingkan isinya. Draf yang
/// gagal karena timeout bisa saja SUDAH tersimpan di server — dan kalau
/// teknisi melanjutkan isiannya sesudah itu, `POST` ulangnya diterima "200"
/// sementara isian barunya dibuang diam-diam. `PUT` penyusul (tetap `draft`)
/// memastikan yang tersimpan di server persis isi antrean.
class SinkronDrafLokal {
  SinkronDrafLokal({
    required this.simpanan,
    required this.pengirim,
    required this.userId,
    required this.bacaToken,
    required this.setelahBerubah,
    Set<String>? terbuka,
    DateTime Function()? jam,
    bool dengarSiklusAplikasi = true,
  }) : terbuka = terbuka ?? <String>{},
       _jam = jam ?? DateTime.now {
    if (dengarSiklusAplikasi) {
      _siklus = AppLifecycleListener(onResume: () => unawaited(jalankan()));
    }
  }

  final SimpananDrafLokal simpanan;
  final PengirimDrafService pengirim;
  final int userId;
  final Future<String?> Function() bacaToken;
  final VoidCallback setelahBerubah;
  final Set<String> terbuka;
  final DateTime Function() _jam;

  /// Jeda antar percobaan selama antrean masih ada. Naik tiap putaran yang
  /// gagal karena jaringan, kembali ke awal begitu ada yang berhasil.
  static const jedaMundur = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
  ];

  AppLifecycleListener? _siklus;
  Future<HasilSinkronDraf>? _berjalan;
  Timer? _timer;
  int _gagalBeruntun = 0;
  bool _dijeda401 = false;
  bool dibuang = false;

  bool get dijeda => _dijeda401;
  bool get adaJadwal => _timer?.isActive ?? false;

  /// Dipanggil sekali waktu akun ini login / aplikasi dibuka.
  Future<void> mulai() async {
    await simpanan.buangAkunLain(userId);
    await simpanan.buangKedaluwarsa(userId, sekarang: _jam());
    if (dibuang) return;
    await jalankan();
  }

  Future<HasilSinkronDraf> jalankan() =>
      _berjalan ??= _jalankan().whenComplete(() => _berjalan = null);

  /// Pasang percobaan berikutnya. Dipanggil layar sesudah menitipkan draf.
  void jadwalkan({Duration? jeda}) {
    if (dibuang || _dijeda401) return;
    _timer?.cancel();
    _timer = Timer(
      jeda ?? jedaMundur[math.min(_gagalBeruntun, jedaMundur.length - 1)],
      () => unawaited(jalankan()),
    );
  }

  Future<HasilSinkronDraf> _jalankan() async {
    if (dibuang || _dijeda401) return const HasilSinkronDraf();

    final token = await bacaToken();
    if (token == null || dibuang) return const HasilSinkronDraf();

    final antrean =
        (await simpanan.daftar(userId))
            .where(
              (d) =>
                  d.status == StatusDrafLokal.belumTersinkron &&
                  !terbuka.contains(d.kunci),
            )
            .toList()
          ..sort((a, b) => a.disimpanPada.compareTo(b.disimpanPada));

    var terkirim = 0;
    var ditolak = 0;
    var gagal = false;

    for (final d in antrean) {
      if (dibuang) break;

      final kiriman = d.kiriman;
      if (kiriman == null) continue;

      // Lihat docblock kelas: antrean NGGAK PERNAH mengirim ke admin.
      final body = {...kiriman, 'status': 'draft'};
      int? idBaru;

      try {
        final sesiId = d.sesiId;

        if (sesiId != null) {
          await pengirim.perbarui(
            token,
            matriks: d.matriks,
            id: sesiId,
            body: body,
          );
        } else {
          final dibuat = await pengirim.buat(
            token,
            matriks: d.matriks,
            body: body,
          );
          idBaru = dibuat.id;

          // Sesi yang sudah lebih jauh dari draft (terlanjur dikirim ke admin
          // dari percobaan sebelumnya) nggak ditimpa jadi draft lagi.
          final status = dibuat.status;
          if (status == null || status == 'draft' || status == 'perlu_revisi') {
            await pengirim.perbarui(
              token,
              matriks: d.matriks,
              id: dibuat.id,
              body: body,
            );
          }
        }

        await simpanan.hapus(userId, d.kunci);
        terkirim++;
      } catch (e) {
        var sisa = d;

        // Sesinya SUDAH lahir di server, yang gagal cuma PUT penyusulnya:
        // salinannya pindah kunci ke id itu, supaya percobaan berikutnya
        // `PUT` ke sana — bukan `POST` lagi.
        if (idBaru != null) {
          sisa = d.copyWith(sesiId: idBaru);
          await simpanan.simpan(sisa);
          await simpanan.hapus(userId, d.kunci);
        }

        if (e is ApiException && e.status == 401) {
          _dijeda401 = true;
          gagal = true;
          break;
        }

        final sementara =
            gagalJaringan(e) ||
            e is! ApiException ||
            e.status >= 500 ||
            e.status == 408 ||
            e.status == 429;

        if (sementara) {
          gagal = true;
          break;
        }

        // Bukan sementara = penolakan server (422 / 403 / 404 / 409):
        // mengirim isi yang sama cuma dapat penolakan yang sama.
        await simpanan.simpan(
          sisa.copyWith(
            status: StatusDrafLokal.perluDiperbaiki,
            pesan: e.message,
          ),
        );
        ditolak++;
      }
    }

    if (dibuang) {
      return HasilSinkronDraf(terkirim: terkirim, ditolak: ditolak);
    }

    if (terkirim > 0 || ditolak > 0) setelahBerubah();

    _gagalBeruntun = gagal ? _gagalBeruntun + 1 : 0;

    final masihAntre = (await simpanan.daftar(
      userId,
    )).any((d) => d.status == StatusDrafLokal.belumTersinkron);

    if (masihAntre && !_dijeda401) {
      jadwalkan();
    } else {
      _timer?.cancel();
    }

    return HasilSinkronDraf(
      terkirim: terkirim,
      ditolak: ditolak,
      gagalJaringan: gagal,
    );
  }

  void dispose() {
    dibuang = true;
    _timer?.cancel();
    _siklus?.dispose();
  }
}
