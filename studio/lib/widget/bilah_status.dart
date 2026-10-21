import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';

import '../data/status_server_provider.dart';
import '../data/status_server_service.dart';
import '../inti/lingkungan_studio.dart';
import '../l10n/studio_l10n.dart';
import '../tema/tema_studio.dart';
import '../tema/warna_studio.dart';

/// Label peran versi Studio (FR-STU-013): `admin` = "Master Data" — sebutan
/// lab untuk pemegang data induk, bukan "Admin" app lapangan.
String labelPeranStudio(UserRole? peran, StudioL10n l10n) => switch (peran) {
  UserRole.admin => l10n.peranAdmin,
  UserRole.teknisi => l10n.peranTeknisi,
  UserRole.viewer => l10n.peranViewer,
  UserRole.superAdmin => l10n.peranSuperAdmin,
  null => '',
};

/// Peran menurut server (`/me/permissions`) bila sudah sampai; kalau belum,
/// peran yang tersimpan saat masuk. Pola `peranDataAcuan` paket bersama.
UserRole? peranAkunStudio(WidgetRef ref) =>
    ref.watch(izinProvider).value?.role ?? ref.watch(authProvider).value?.role;

/// Bilah status bawah 24 dp — Windows (FR-STU-013, `04-UI-UX-Flow.md` §2.1):
/// server yang dituju, koneksi, realtime, versi API, pengguna + peran.
///
/// Di tablet isi yang sama dilipat ke menu akun ([RincianStatus]).
class BilahStatus extends ConsumerWidget {
  const BilahStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final status = ref.watch(statusServerProvider);
    final alamat = ref.watch(alamatServerStudioProvider);
    final akun = ref.watch(authProvider).value;
    final peran = labelPeranStudio(peranAkunStudio(ref), l10n);
    final koneksi = _Koneksi.dari(status, l10n, w);
    final versiApi = status.value?.versiApi;

    return Semantics(
      container: true,
      label: l10n.bilahStatus,
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          color: w.permukaan,
          border: Border(top: BorderSide(color: w.garis)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j3),
        child: Row(
          children: [
            _Butir(
              ikon: Icons.dns_outlined,
              teks: l10n.statusServer(hostServer(alamat)),
              tooltip: alamat,
            ),
            const _Pemisah(),
            _Butir(titik: koneksi.warna, teks: koneksi.teks),
            if (!status.hasError) ...[
              const _Pemisah(),
              _Butir(
                ikon: Icons.sensors_outlined,
                teks: _teksRealtime(status.value, l10n),
              ),
            ],
            if (versiApi != null) ...[
              const _Pemisah(),
              _Butir(
                teks: l10n.statusVersiApi(versiPendek(versiApi)),
                tooltip: versiApi,
                angka: true,
              ),
            ],
            const Spacer(),
            if (akun != null)
              Flexible(
                child: _Butir(
                  ikon: Icons.person_outline,
                  teks: peran.isEmpty ? akun.nama : '${akun.nama} · $peran',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Isi bilah status dalam bentuk tegak — untuk menu akun di tablet.
class RincianStatus extends ConsumerWidget {
  const RincianStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final status = ref.watch(statusServerProvider);
    final alamat = ref.watch(alamatServerStudioProvider);
    final akun = ref.watch(authProvider).value;
    final peran = labelPeranStudio(peranAkunStudio(ref), l10n);
    final koneksi = _Koneksi.dari(status, l10n, w);
    final versiApi = status.value?.versiApi;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: Padding(
        padding: const EdgeInsets.all(UkuranStudio.j4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (akun != null) ...[
              Text(akun.nama, style: teks.titleSmall),
              Text(
                [
                  if (peran.isNotEmpty) peran,
                  if (akun.employeeId.isNotEmpty) akun.employeeId,
                ].join(' · '),
                style: teks.bodySmall,
              ),
              const SizedBox(height: UkuranStudio.j3),
            ],
            _Butir(
              ikon: Icons.dns_outlined,
              teks: l10n.statusServer(hostServer(alamat)),
              tooltip: alamat,
            ),
            const SizedBox(height: UkuranStudio.j2),
            _Butir(titik: koneksi.warna, teks: koneksi.teks),
            if (!status.hasError) ...[
              const SizedBox(height: UkuranStudio.j2),
              _Butir(
                ikon: Icons.sensors_outlined,
                teks: _teksRealtime(status.value, l10n),
              ),
            ],
            if (versiApi != null) ...[
              const SizedBox(height: UkuranStudio.j2),
              _Butir(
                teks: l10n.statusVersiApi(versiPendek(versiApi)),
                tooltip: versiApi,
                angka: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// SHA commit dipendekkan ke 7 karakter (gaya `git log --oneline`); versi
/// berbentuk lain ditampilkan utuh.
String versiPendek(String versi) =>
    RegExp(r'^[0-9a-f]{12,}$').hasMatch(versi) ? versi.substring(0, 7) : versi;

String _teksRealtime(StatusServer? s, StudioL10n l10n) =>
    switch (s?.realtimeNyala) {
      true => l10n.statusRealtimeNyala,
      false => l10n.statusRealtimeMati,
      null => l10n.statusRealtimeTakDiketahui,
    };

/// Koneksi ke server menurut tarikan `/health` terakhir. Status selalu
/// disebut dengan TEKS — warna titik cuma penguat, bukan satu-satunya tanda.
class _Koneksi {
  const _Koneksi(this.teks, this.warna);

  final String teks;
  final Color warna;

  static _Koneksi dari(
    AsyncValue<StatusServer> status,
    StudioL10n l10n,
    WarnaStudio w,
  ) {
    if (status.hasError) return _Koneksi(l10n.statusTerputus, w.gagal);
    if (status.hasValue) return _Koneksi(l10n.statusTersambung, w.lulus);
    return _Koneksi(l10n.statusMemeriksa, w.teksRedup);
  }
}

class _Butir extends StatelessWidget {
  const _Butir({
    required this.teks,
    this.ikon,
    this.titik,
    this.tooltip,
    this.angka = false,
  });

  final String teks;
  final IconData? ikon;
  final Color? titik;
  final String? tooltip;
  final bool angka;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    final gaya = angka
        ? TipografiStudio.angka(ukuran: 11, warna: w.teks2)
        : Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5);

    Widget isi = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ikon != null) ...[
          Icon(ikon, size: 13, color: w.teksRedup),
          const SizedBox(width: UkuranStudio.j1),
        ],
        if (titik != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: titik, shape: BoxShape.circle),
          ),
          const SizedBox(width: UkuranStudio.j1 + 2),
        ],
        Flexible(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: gaya,
          ),
        ),
      ],
    );

    if (tooltip != null) isi = Tooltip(message: tooltip, child: isi);
    return isi;
  }
}

class _Pemisah extends StatelessWidget {
  const _Pemisah();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 12,
    margin: const EdgeInsets.symmetric(horizontal: UkuranStudio.j3),
    color: WarnaStudio.of(context).garis,
  );
}
