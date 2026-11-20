import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/penugasan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/penugasan_kelola_provider.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/kode_galat.dart' show kodeDariBadan;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../super_admin/widgets/dialog_isian.dart';
import '../super_admin/widgets/pesan_layar.dart';
import 'hak_crud_lab.dart';
import 'penugasan_ubah_screen.dart';
import 'widgets/dialog_konfirmasi_crud.dart';
import 'widgets/kartu_penugasan.dart';
import 'widgets/pesan_galat_crud.dart';

/// Papan penugasan untuk dikelola: ubah dan batalkan penugasan yang masih
/// aktif (kontrak CRUD lengkap §4), selesaikan yang sudah tuntas, dan buka lagi
/// yang sudah selesai (PR #284). MEMBUAT penugasan tetap di layar lama;
/// teknisi melaporkan progres di layar lama juga — keduanya tidak disentuh.
///
/// Tiap tombol mengikuti izin server: `penugasan.ubah`, `penugasan.batalkan`,
/// `penugasan.selesaikan` (admin dan super admin), `penugasan.buka-lagi` (super
/// admin saja). Batalkan dan Buka lagi mewajibkan alasan 5–400 karakter. Semua
/// aksi mengambil ulang papan dari server sesudah sukses.
class PenugasanKelolaScreen extends ConsumerStatefulWidget {
  const PenugasanKelolaScreen({super.key});

  @override
  ConsumerState<PenugasanKelolaScreen> createState() =>
      _PenugasanKelolaScreenState();
}

class _PenugasanKelolaScreenState extends ConsumerState<PenugasanKelolaScreen> {
  bool _memuatLagi = false;

  PenugasanKelolaController get _ctl =>
      ref.read(penugasanKelolaProvider.notifier);

  Future<void> _muatLagi() async {
    if (_memuatLagi) return;
    setState(() => _memuatLagi = true);
    try {
      await _ctl.muatLebihBanyak();
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  void _kabari(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _ubah(Penugasan p) async {
    final hasil = await Navigator.of(context).push<Penugasan>(
      MaterialPageRoute<Penugasan>(
        builder: (_) => PenugasanUbahScreen(penugasan: p),
      ),
    );
    if (hasil != null) {
      _ctl.muatUlang();
      if (mounted) _kabari(AppLocalizations.of(context).crudPenugasanBerhasilUbah);
    }
  }

  Future<void> _batalkan(Penugasan p) async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.crudPenugasanBatalJudul(p.judul),
      isi: l10n.crudPenugasanBatalIsi,
      labelKolom: l10n.crudAlasanWajib,
      catatan: l10n.crudAlasanCatatan,
      labelAksi: l10n.crudPenugasanBatalAksi,
      destruktif: true,
      panjangMinimal: 5,
      panjangMaksimal: 400,
      pesanPendek: l10n.crudAlasanPendek,
      pesanPanjang: l10n.crudAlasanPanjang,
      petakanGalat: (e) => pesanGalatCrud(l10n, e),
      aksi: (alasan) async {
        final token = await ref.read(tokenStorageProvider).read();
        if (token == null) throw const TokenHilangException();
        await ref
            .read(penugasanKelolaServiceProvider)
            .batalkan(token, p.id, alasan: alasan);
      },
      saatGalat: (e) {
        if (perluMuatUlangCrud(e)) _ctl.muatUlang();
      },
    );
    if (ok) {
      _ctl.muatUlang();
      _kabari(l10n.crudPenugasanBatalBerhasil);
    }
  }

  /// Tutup penugasan yang sudah tuntas. Server memutuskan; yang dikirim hanya
  /// niat "tutup". Dialog konfirmasi karena anggota langsung diberi tahu dan
  /// hanya super admin yang bisa membukanya lagi.
  Future<void> _selesaikan(Penugasan p) async {
    final l10n = AppLocalizations.of(context);
    var sudahSelesai = false;
    final ok = await tampilkanDialogKonfirmasiCrud(
      context,
      judul: l10n.crudPenugasanSelesaiJudul(p.judul),
      isi: l10n.crudPenugasanSelesaiIsi,
      labelAksi: l10n.crudPenugasanSelesaiAksi,
      destruktif: false,
      aksi: () async {
        final token = await ref.read(tokenStorageProvider).read();
        if (token == null) throw const TokenHilangException();
        try {
          await ref
              .read(penugasanKelolaServiceProvider)
              .selesaikan(token, p.id);
        } on ApiException catch (e) {
          // Kirim ulang sesudah balasan hilang dijawab 422
          // `penugasan_sudah_selesai` (kontrak #284, sengaja bukan 200). Itu
          // bukan galat: tujuannya sudah tercapai.
          if (kodeDariBadan(e.body) != KodeCrud.penugasanSudahSelesai) rethrow;
          sudahSelesai = true;
        }
      },
      saatGalat: (e) {
        if (perluMuatUlangCrud(e)) _ctl.muatUlang();
      },
    );
    if (ok) {
      _ctl.muatUlang();
      _kabari(
        sudahSelesai
            ? l10n.crudPenugasanSudahSelesai
            : l10n.crudPenugasanSelesaiBerhasil,
      );
    }
  }

  /// Buka lagi penugasan selesai (super admin). Alasan 5–400 karakter masuk
  /// jejak audit dan sampai ke anggota; progres teknisi tidak tersentuh.
  Future<void> _bukaLagi(Penugasan p) async {
    final l10n = AppLocalizations.of(context);
    var sudahAktif = false;
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.crudPenugasanBukaLagiJudul(p.judul),
      isi: l10n.crudPenugasanBukaLagiIsi,
      labelKolom: l10n.crudAlasanWajib,
      catatan: l10n.crudAlasanCatatan,
      labelAksi: l10n.crudPenugasanBukaLagiAksi,
      panjangMinimal: 5,
      panjangMaksimal: 400,
      pesanPendek: l10n.crudAlasanPendek,
      pesanPanjang: l10n.crudAlasanPanjang,
      petakanGalat: (e) => pesanGalatCrud(l10n, e),
      aksi: (alasan) async {
        final token = await ref.read(tokenStorageProvider).read();
        if (token == null) throw const TokenHilangException();
        try {
          await ref
              .read(penugasanKelolaServiceProvider)
              .bukaLagi(token, p.id, alasan: alasan);
        } on ApiException catch (e) {
          // Kirim ulang sesudah balasan hilang: penugasan sudah dibuka dan kini
          // `aktif`, jadi server menjawab 422 `penugasan_tidak_selesai` dengan
          // `status: aktif`. Tujuannya sudah tercapai (cermin Selesaikan yang
          // menganggap `penugasan_sudah_selesai` berhasil). Status `dibatalkan`
          // tetap galat: itu tidak pernah dibuka lagi.
          final aktif =
              kodeDariBadan(e.body) == KodeCrud.penugasanTidakSelesai &&
              e.body['status'] == 'aktif';
          if (!aktif) rethrow;
          sudahAktif = true;
        }
      },
      saatGalat: (e) {
        if (perluMuatUlangCrud(e)) _ctl.muatUlang();
      },
    );
    if (ok) {
      _ctl.muatUlang();
      _kabari(
        sudahAktif
            ? l10n.crudPenugasanSudahAktif
            : l10n.crudPenugasanBukaLagiBerhasil,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bolehUbah = ref.bolehUbahPenugasan;
    final bolehBatal = ref.bolehBatalkanPenugasan;
    final bolehSelesai = ref.bolehSelesaikanPenugasan;
    final bolehBuka = ref.bolehBukaLagiPenugasan;
    final boleh = bolehUbah || bolehBatal || bolehSelesai || bolehBuka;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.crudPenugasanJudul)),
      body: SafeArea(
        top: false,
        child: !boleh
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.crudTanpaIzin)
            : ReadableWidth(
                maksimum: 720,
                child: _Papan(
                  memuatLagi: _memuatLagi,
                  saatMuatLagi: _muatLagi,
                  saatUbah: bolehUbah ? _ubah : null,
                  saatBatalkan: bolehBatal ? _batalkan : null,
                  saatSelesaikan: bolehSelesai ? _selesaikan : null,
                  saatBukaLagi: bolehBuka ? _bukaLagi : null,
                ),
              ),
      ),
    );
  }
}

class _Papan extends ConsumerWidget {
  const _Papan({
    required this.memuatLagi,
    required this.saatMuatLagi,
    required this.saatUbah,
    required this.saatBatalkan,
    required this.saatSelesaikan,
    required this.saatBukaLagi,
  });

  final bool memuatLagi;
  final VoidCallback saatMuatLagi;
  final ValueChanged<Penugasan>? saatUbah;
  final ValueChanged<Penugasan>? saatBatalkan;
  final ValueChanged<Penugasan>? saatSelesaikan;
  final ValueChanged<Penugasan>? saatBukaLagi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(penugasanKelolaProvider);
    final ctl = ref.read(penugasanKelolaProvider.notifier);
    final data = async.value;

    final int isi;
    final Widget Function(BuildContext, int) bangunIsi;
    if (data != null && data.items.isNotEmpty) {
      isi = data.items.length + (data.adaLagi ? 1 : 0);
      bangunIsi = (context, i) {
        if (i == data.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: AppButton(
                label: l10n.saMuatLagi,
                icon: Icons.expand_more,
                variant: AppButtonVariant.secondary,
                ringkas: true,
                isLoading: memuatLagi,
                onPressed: saatMuatLagi,
              ),
            ),
          );
        }
        final p = data.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: KartuPenugasan(
            key: Key('kartu-penugasan-${p.id}'),
            penugasan: p,
            saatUbah: saatUbah == null ? null : () => saatUbah!(p),
            saatBatalkan: saatBatalkan == null ? null : () => saatBatalkan!(p),
            saatSelesaikan: saatSelesaikan == null
                ? null
                : () => saatSelesaikan!(p),
            saatBukaLagi: saatBukaLagi == null ? null : () => saatBukaLagi!(p),
          ),
        );
      };
    } else if (data != null) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 280,
        child: PesanLayar(
          ikon: Icons.assignment_outlined,
          teks: ctl.status == null
              ? l10n.crudPenugasanKosong
              : l10n.crudPenugasanKosongStatus,
        ),
      );
    } else if (async.hasError) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 320,
        child: PesanLayar(
          ikon: Icons.cloud_off_outlined,
          galat: true,
          teks: async.error is TokenHilangException
              ? l10n.historySessionExpired
              : l10n.crudPenugasanGagal,
          aksi: AppButton(
            label: l10n.saCobaLagi,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: ctl.muatUlang,
          ),
        ),
      );
    } else {
      isi = 3;
      bangunIsi = (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: _KerangkaKartu(),
      );
    }

    final pilihan = <(String?, String)>[
      (null, l10n.crudPenugasanSemua),
      for (final s in StatusPenugasan.semua) (s, StatusBadge.labelApi(s, l10n)),
    ];

    return RefreshIndicator(
      onRefresh: ctl.muatUlang,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: isi + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (nilai, label) in pilihan)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          key: Key('saring-penugasan-${nilai ?? 'semua'}'),
                          label: Text(label),
                          selected: ctl.status == nilai,
                          onSelected: (_) => ctl.saring(nilai),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
          return bangunIsi(context, i - 1);
        },
      ),
    );
  }
}

class _KerangkaKartu extends StatelessWidget {
  const _KerangkaKartu();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 16, width: 180),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 220),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 6),
          ],
        ),
      ),
    );
  }
}
