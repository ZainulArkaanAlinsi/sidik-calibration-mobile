import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';

import '../../data/workbook_model.dart';
import '../../data/workbook_provider.dart';
import '../../inti/sesi_studio.dart';
import '../../l10n/studio_l10n.dart';
import '../../tema/tema_studio.dart';
import '../../tema/warna_studio.dart';
import 'daftar_workbook_screen.dart'
    show LencanaImporWorkbook, LencanaStatusWorkbook, LencanaSumberWorkbook;
import 'workbook_screen.dart' show bukaWorkbook;

/// Buka riwayat jenis [wb] di navigator AKAR — layar penuh satu bilah, sama
/// dengan [bukaWorkbook] (dibuka dari daftar MAUPUN dari layar workbook yang
/// sudah di navigator akar).
Future<void> bukaRiwayatWorkbook(BuildContext context, WorkbookRingkas wb) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RiwayatWorkbookScreen(workbookId: wb.id, judul: wb.nama),
      ),
    );

/// Riwayat satu master (K-49-13): Studio memegang SATU master aktif per
/// jenis; impor baru menggantikan yang aktif dan yang lama disimpan sebagai
/// riwayat (`GET /studio/workbook/{id}/riwayat`).
///
/// Urutan baris = urutan server (master aktif dulu, lalu riwayat) — TIDAK
/// diurut ulang menurut `versi`, karena `versi` urutan impor, bukan kebaruan.
/// Aktif/lama dibaca dari `status`/`digantikan_oleh_id` saja
/// ([WorkbookRingkas.riwayat]).
///
/// Baris riwayat dibuka di penampil workbook yang sama, BACA SAJA (layar
/// workbook menolak edit/simulasi untuk riwayat). Baris master aktif hanya
/// keterangan — dibuka dari daftar.
///
/// Seperti layar workbook, layar ini di navigator akar, jadi menutup dirinya
/// sendiri bila akun berganti/keluar, versi Studio ditolak server, atau izin
/// `workbook.lihat` dicabut.
class RiwayatWorkbookScreen extends ConsumerStatefulWidget {
  const RiwayatWorkbookScreen({
    super.key,
    required this.workbookId,
    required this.judul,
  });

  final int workbookId;

  /// Nama master dari baris yang membuka layar ini.
  final String judul;

  @override
  ConsumerState<RiwayatWorkbookScreen> createState() =>
      _RiwayatWorkbookScreenState();
}

class _RiwayatWorkbookScreenState extends ConsumerState<RiwayatWorkbookScreen> {
  /// Akun saat layar dibuka — dibaca di [initState] (pola `WorkbookScreen`).
  late final int? _akun;
  bool _ditutup = false;

  @override
  void initState() {
    super.initState();
    _akun = ref.read(authProvider).value?.id;
    if (ref.read(klienKedaluwarsaProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tutup());
    }
  }

  void _tutup() {
    if (_ditutup || !mounted) return;
    _ditutup = true;
    final rute = ModalRoute.of(context);
    if (rute != null && rute.isActive) {
      Navigator.of(context).removeRoute(rute);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((a) => a.value?.id), (_, id) {
      if (id != _akun) _tutup();
    });
    ref.listen(klienKedaluwarsaProvider, (_, usang) {
      if (usang) _tutup();
    });
    ref.listen(izinProvider, (_, izin) {
      final i = izin.value;
      if (i != null &&
          !i.bolehkah(izinWorkbookLihat, cadangan: cadanganIzinWorkbook)) {
        _tutup();
      }
    });
    final p = riwayatWorkbookProvider(widget.workbookId);
    // Master ini sudah keluar dari Studio (arsip / id lama sesudah ekstrak
    // ulang): daftar di bawah ditarik ulang supaya barisnya tidak ditawarkan.
    ref.listen(p, (_, r) {
      if (r is AsyncError && _tidakAda(r.error)) {
        ref.invalidate(daftarWorkbookProvider);
      }
    });

    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final riwayat = ref.watch(p);

    final Widget isi = switch (riwayat) {
      AsyncData(:final value) when value.versi.isEmpty => _Keadaan(
        ikon: Icons.history,
        judul: l10n.riwayatKosong,
      ),
      AsyncData(:final value) => _IsiRiwayat(riwayat: value),
      AsyncError(:final error) when _tidakAda(error) => _Keadaan(
        ikon: Icons.inventory_2_outlined,
        judul: l10n.workbookDiarsipkan,
        aksi: FilledButton.icon(
          key: const ValueKey('riwayat-kembali'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(l10n.workbookKembaliKeDaftar),
        ),
      ),
      AsyncError(:final error) => _Keadaan(
        ikon: Icons.cloud_off_outlined,
        judul: error is AuthException && error.message.isNotEmpty
            ? error.message
            : l10n.riwayatGagalMuat,
        aksi: FilledButton.icon(
          onPressed: () => ref.invalidate(p),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.cobaLagi),
        ),
      ),
      _ => Center(
        child: Semantics(
          label: l10n.memuat,
          child: const CircularProgressIndicator(),
        ),
      ),
    };

    return Scaffold(
      backgroundColor: w.latar,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BilahRiwayat(
              judul: l10n.riwayatJudul(widget.judul),
              onMuatUlang: () => ref.invalidate(p),
            ),
            Expanded(child: isi),
          ],
        ),
      ),
    );
  }
}

bool _tidakAda(Object? e) => e is ApiException && e.status == 404;

/// Bilah atas: kembali, judul, muat ulang (gaya bilah layar workbook).
class _BilahRiwayat extends StatelessWidget {
  const _BilahRiwayat({required this.judul, required this.onMuatUlang});

  final String judul;
  final VoidCallback onMuatUlang;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    return Material(
      color: w.permukaan,
      child: Container(
        height: UkuranStudio.tinggiBilah,
        padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j1),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: w.garis)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.kembali,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: UkuranStudio.j1),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.workbookMuatUlang,
              icon: const Icon(Icons.refresh),
              onPressed: onMuatUlang,
            ),
          ],
        ),
      ),
    );
  }
}

class _IsiRiwayat extends StatelessWidget {
  const _IsiRiwayat({required this.riwayat});

  final RiwayatWorkbook riwayat;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(UkuranStudio.j6),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              l10n.riwayatKet,
              style: teks.bodyMedium?.copyWith(color: w.teks2),
            ),
          ),
        ),
        const SizedBox(height: UkuranStudio.j4),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, v) in riwayat.versi.indexed) ...[
                if (i > 0) Divider(color: w.garis),
                _BarisVersi(workbook: v),
              ],
              if (riwayat.riwayat.isEmpty) ...[
                Divider(color: w.garis),
                Padding(
                  padding: const EdgeInsets.all(UkuranStudio.j4),
                  child: Text(
                    l10n.riwayatKosong,
                    key: const ValueKey('riwayat-kosong'),
                    style: teks.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Satu versi: nama, nomor impor, sumber, tanggal impor, status. Riwayat
/// bisa diketuk (dibuka baca saja); master aktif tidak.
class _BarisVersi extends StatelessWidget {
  const _BarisVersi({required this.workbook});

  final WorkbookRingkas workbook;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final wb = workbook;
    final waktu = wb.diimporPada;
    final pengganti = wb.riwayat ? wb.digantikanOlehId : null;
    final keterangan = [
      if (waktu != null)
        l10n.workbookDiimpor(DateFormat.yMMMd(locale).format(waktu.toLocal())),
      if (pengganti != null) l10n.workbookDigantikanOleh(pengganti),
    ].join(' · ');

    final baris = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UkuranStudio.j4,
        vertical: UkuranStudio.j3,
      ),
      child: Row(
        children: [
          Icon(
            wb.riwayat ? Icons.history : Icons.grid_on_outlined,
            size: 18,
            color: w.teks2,
          ),
          const SizedBox(width: UkuranStudio.j3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wb.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: teks.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (keterangan.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    keterangan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: teks.bodySmall?.copyWith(color: w.teksRedup),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: UkuranStudio.j3),
          if (wb.versi != null) ...[
            LencanaImporWorkbook(workbook: wb),
            const SizedBox(width: UkuranStudio.j2),
          ],
          LencanaSumberWorkbook(workbook: wb),
          const SizedBox(width: UkuranStudio.j2),
          LencanaStatusWorkbook(workbook: wb),
          const SizedBox(width: UkuranStudio.j1),
          SizedBox(
            width: 18,
            child: wb.riwayat
                ? Icon(Icons.chevron_right, size: 18, color: w.teksRedup)
                : null,
          ),
        ],
      ),
    );

    if (!wb.riwayat) {
      return KeyedSubtree(key: ValueKey('versi-${wb.id}'), child: baris);
    }
    return InkWell(
      key: ValueKey('versi-${wb.id}'),
      onTap: () => bukaWorkbook(context, wb),
      child: baris,
    );
  }
}

class _Keadaan extends StatelessWidget {
  const _Keadaan({required this.ikon, required this.judul, this.aksi});

  final IconData ikon;
  final String judul;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(UkuranStudio.j6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ikon, size: 36, color: w.teksRedup),
              const SizedBox(height: UkuranStudio.j3),
              Text(
                judul,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (aksi != null) ...[
                const SizedBox(height: UkuranStudio.j4),
                aksi!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
