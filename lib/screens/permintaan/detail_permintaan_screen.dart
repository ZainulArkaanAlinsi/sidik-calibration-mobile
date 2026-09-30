import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/permintaan_pelanggan.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/permintaan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_status.dart';
import '../../widgets/sidik/sidik_tombol.dart';
import '../../widgets/skeleton.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;
import 'antrean_permintaan_screen.dart' show izinPermintaan, statusPermintaan;
import 'terima_permintaan_screen.dart';

/// Satu permintaan pelanggan: rincian + utas pesan dalam dua tab.
///
/// Tombol Terima/Tolak hanya muncul kalau statusnya `baru` DAN perannya boleh
/// memutuskan. Super admin melihat satu kalimat yang bilang kenapa tidak ada
/// tombol — bukan layar yang diam-diam lebih pendek. Server tetap penjaganya
/// (403), jadi ini soal tidak menawarkan pintu yang pasti ditolak.
class DetailPermintaanScreen extends ConsumerWidget {
  const DetailPermintaanScreen({super.key, required this.permintaanId});

  final int permintaanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(detailPermintaanProvider(permintaanId));
    final p = async.value;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p?.nomor ?? l10n.permintaanJudul),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.permintaanTabRincian),
              Tab(
                text: p == null || p.jumlahPesan == 0
                    ? l10n.permintaanTabPesan
                    : l10n.permintaanTabPesanJumlah(p.jumlahPesan),
              ),
            ],
          ),
        ),
        body: switch (async) {
          AsyncData(:final value) => ReadableWidth(
            child: TabBarView(
              children: [
                _TabRincian(permintaan: value),
                _TabPesan(permintaan: value),
              ],
            ),
          ),
          AsyncError(:final error) => _Gagal(
            teks: error is TokenHilangException
                ? l10n.historySessionExpired
                : l10n.permintaanGagalDetail,
            onCobaLagi: () =>
                ref.invalidate(detailPermintaanProvider(permintaanId)),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: SkeletonBox(height: 120),
          ),
        },
      ),
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.teks, required this.onCobaLagi});

  final String teks;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(teks, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: SidikTombol(
            label: AppLocalizations.of(context).custRetry,
            ikon: Icons.refresh,
            onPressed: onCobaLagi,
          ),
        ),
      ],
    );
  }
}

// ── Tab Rincian ──────────────────────────────────────────────────────────────

class _TabRincian extends ConsumerWidget {
  const _TabRincian({required this.permintaan});

  final PermintaanPelanggan permintaan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = permintaan;
    final izin = izinPermintaan(ref);
    final perluKeputusan = p.status.bisaDiputuskan;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(detailPermintaanProvider(p.id));
              await ref.read(detailPermintaanProvider(p.id).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _Kepala(permintaan: p),
                const SizedBox(height: AppSpacing.md),
                _Keterangan(permintaan: p),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.permintaanAlatDaftar(p.alat.length),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final a in p.alat) ...[
                  _KartuAlat(alat: a, perluKeputusan: perluKeputusan),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
        if (perluKeputusan)
          _BilahKeputusan(
            boleh: izin.putuskan,
            onTolak: () => _tolak(context, ref),
            onTerima: () => _terima(context, ref),
          ),
      ],
    );
  }

  Future<void> _terima(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hasil = await Navigator.of(context).push<PermintaanPelanggan>(
      MaterialPageRoute<PermintaanPelanggan>(
        builder: (_) => TerimaPermintaanScreen(permintaan: permintaan),
      ),
    );
    if (hasil == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.permintaanDiterimaToast(hasil.orderNomor ?? '—')),
      ),
    );
  }

  Future<void> _tolak(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final alasan = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogTolak(),
    );
    if (alasan == null) return;
    try {
      await ref.read(permintaanAksiProvider).tolak(permintaan.id, alasan);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.permintaanDitolakToast)),
      );
    } catch (e) {
      // 422 status ("admin lain lebih dulu") dan 403/404 membawa pesan server
      // yang sudah layak dibaca; tampilkan apa adanya lalu segarkan layar.
      ref.invalidate(detailPermintaanProvider(permintaan.id));
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _BilahKeputusan extends StatelessWidget {
  const _BilahKeputusan({
    required this.boleh,
    required this.onTolak,
    required this.onTerima,
  });

  final bool boleh;
  final VoidCallback onTolak;
  final VoidCallback onTerima;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: m.kertas,
          border: Border(top: BorderSide(color: m.garis)),
        ),
        child: boleh
            ? Row(
                children: [
                  Expanded(
                    child: SidikTombol(
                      key: const ValueKey('tombol-tolak-permintaan'),
                      label: l10n.permintaanTolak,
                      ikon: Icons.close,
                      ragam: RagamTombol.bahayaGaris,
                      penuh: true,
                      onPressed: onTolak,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SidikTombol(
                      key: const ValueKey('tombol-terima-permintaan'),
                      label: l10n.permintaanTerima,
                      ikon: Icons.check,
                      ragam: RagamTombol.utama,
                      penuh: true,
                      onPressed: onTerima,
                    ),
                  ),
                ],
              )
            : Text(
                l10n.permintaanBacaSaja,
                key: const ValueKey('catatan-baca-saja-permintaan'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala({required this.permintaan});

  final PermintaanPelanggan permintaan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final p = permintaan;

    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.nomor,
                  style: SidikTheme.gayaAngka(ukuran: 12, warna: m.tinta2),
                ),
              ),
              SidikLencana(statusPermintaan(l10n, p.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(p.pelangganNama ?? '—', style: theme.textTheme.titleLarge),
          if (p.pemohonNama != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Baris(label: l10n.permintaanPemohon, isi: p.pemohonNama!),
            if (p.pemohonEmail != null) _Baris(isi: p.pemohonEmail!),
            if (p.pemohonTelepon != null)
              _Baris(isi: p.pemohonTelepon!, angka: true),
          ],
        ],
      ),
    );
  }
}

class _Keterangan extends StatelessWidget {
  const _Keterangan({required this.permintaan});

  final PermintaanPelanggan permintaan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final p = permintaan;

    final tanggal = switch ((p.tanggalDari, p.tanggalSampai)) {
      (final DateTime a, final DateTime b) => l10n.permintaanTanggalRentang(
        tanggalPendek(context, a),
        tanggalPendek(context, b),
      ),
      (final DateTime a, null) => l10n.permintaanTanggalSejak(
        tanggalPendek(context, a),
      ),
      (null, final DateTime b) => l10n.permintaanTanggalSampaiSaja(
        tanggalPendek(context, b),
      ),
      _ => null,
    };

    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.metode != null)
            _Baris(
              label: l10n.permintaanPengantaran,
              isi: p.metode == MetodePengantaran.diantarSendiri
                  ? l10n.permintaanDiantarSendiri
                  : l10n.permintaanDiambilLab,
            ),
          if (tanggal != null) ...[
            _Baris(label: l10n.permintaanTanggalDiinginkan, isi: tanggal),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.permintaanTanggalHanyaKeinginan,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (p.catatan != null && p.catatan!.isNotEmpty)
            _Baris(label: l10n.permintaanCatatanPelanggan, isi: p.catatan!),
          if (p.status == StatusPermintaan.ditolak && p.alasanPenolakan != null)
            _Baris(
              label: l10n.permintaanAlasanPenolakan,
              isi: p.alasanPenolakan!,
              warna: m.gagal,
            ),
          if (p.orderNomor != null)
            _Baris(
              label: l10n.permintaanOrderLahir,
              isi: p.orderNomor!,
              angka: true,
            ),
          if (p.diputuskanOleh != null)
            _Baris(isi: l10n.permintaanDiputuskanOleh(p.diputuskanOleh!)),
        ],
      ),
    );
  }
}

/// Satu pasang label-etsa + isi. Tanpa [label] = lanjutan baris sebelumnya.
class _Baris extends StatelessWidget {
  const _Baris({this.label, required this.isi, this.angka = false, this.warna});

  final String? label;
  final String isi;

  /// Nomor, telepon, serial: lebar digit tetap (`SidikTheme.gayaAngka`).
  final bool angka;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return Padding(
      padding: EdgeInsets.only(top: label == null ? 2 : AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(label!.toUpperCase(), style: m.gayaEtsa(ukuran: 11)),
          Text(
            isi,
            style: angka
                ? SidikTheme.gayaAngka(
                    ukuran: 14,
                    berat: FontWeight.w500,
                    warna: warna,
                  )
                : theme.textTheme.bodyMedium?.copyWith(color: warna),
          ),
        ],
      ),
    );
  }
}

class _KartuAlat extends StatelessWidget {
  const _KartuAlat({required this.alat, required this.perluKeputusan});

  final AlatPermintaan alat;
  final bool perluKeputusan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final a = alat;
    final merkModel = [
      if (a.merk != null && a.merk!.isNotEmpty) a.merk!,
      if (a.model != null && a.model!.isNotEmpty) a.model!,
    ].join(' · ');

    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(a.namaAlat, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: AppSpacing.sm),
              SidikLencana(
                a.baru
                    ? StatusSidik(
                        l10n.permintaanAlatBaru,
                        NadaStatus.awas,
                        Icons.add_circle_outline,
                      )
                    : StatusSidik(
                        l10n.permintaanAlatTerdaftar,
                        NadaStatus.lulus,
                        Icons.check_circle_outline,
                      ),
              ),
            ],
          ),
          if (merkModel.isNotEmpty)
            Text(merkModel, style: theme.textTheme.bodySmall),
          if (a.serialNumber != null && a.serialNumber!.isNotEmpty)
            _Baris(
              label: l10n.permintaanSerial,
              isi: a.serialNumber!,
              angka: true,
            )
          else if (a.baru)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.permintaanSerialKosong,
                style: theme.textTheme.bodySmall?.copyWith(color: m.awas),
              ),
            ),
          if (a.noIdentifikasi != null)
            _Baris(
              label: l10n.permintaanNoIdentifikasi,
              isi: a.noIdentifikasi!,
              angka: true,
            ),
          if (a.rentang != null)
            _Baris(label: l10n.permintaanRentang, isi: a.rentang!, angka: true),
          if (a.resolusi != null)
            _Baris(
              label: l10n.permintaanResolusi,
              isi: '${a.resolusi}',
              angka: true,
            ),
          if (a.lokasi != null)
            _Baris(label: l10n.permintaanLokasi, isi: a.lokasi!),
          if (a.catatan != null)
            _Baris(label: l10n.permintaanCatatan, isi: a.catatan!),
          if (perluKeputusan && (a.perluKategori || a.perluNomorSeri))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.edit_note, size: 16, color: m.awas),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.permintaanPerluDilengkapi,
                      style: theme.textTheme.bodySmall?.copyWith(color: m.awas),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog alasan penolakan. `TextEditingController`-nya dimiliki `State`
/// dialog ini sendiri, BUKAN dibuat di pemanggil lalu dibuang sesudah
/// `showDialog` kembali — animasi tutup dialog masih membangun `TextField`
/// sesudah `await` selesai, dan controller yang sudah di-`dispose` jatuh
/// ("used after being disposed"). Pola yang sama dengan `_DialogSerahTerima`.
class _DialogTolak extends StatefulWidget {
  const _DialogTolak();

  @override
  State<_DialogTolak> createState() => _DialogTolakState();
}

class _DialogTolakState extends State<_DialogTolak> {
  /// Sama dengan aturan server (`alasan` 5–1000): dibaca PELANGGAN apa adanya,
  /// jadi "-" atau "x" tidak boleh lolos hanya karena kolomnya wajib.
  static const _minimal = 5;

  final _teks = TextEditingController();

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  bool get _cukup => _teks.text.trim().length >= _minimal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.permintaanTolakJudul),
      content: TextField(
        key: const ValueKey('isian-alasan-tolak'),
        controller: _teks,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        maxLength: 1000,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: l10n.permintaanTolakPetunjuk,
          helperText: l10n.permintaanTolakHelper(_minimal),
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.custCancel),
        ),
        TextButton(
          key: const ValueKey('kirim-tolak-permintaan'),
          onPressed: _cukup
              ? () => Navigator.of(context).pop(_teks.text.trim())
              : null,
          child: Text(l10n.permintaanTolakKirim),
        ),
      ],
    );
  }
}

// ── Tab Pesan ────────────────────────────────────────────────────────────────

class _TabPesan extends ConsumerStatefulWidget {
  const _TabPesan({required this.permintaan});

  final PermintaanPelanggan permintaan;

  @override
  ConsumerState<_TabPesan> createState() => _TabPesanState();
}

class _TabPesanState extends ConsumerState<_TabPesan> {
  final _teks = TextEditingController();
  bool _mengirim = false;

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final isi = _teks.text.trim();
    if (isi.isEmpty || _mengirim) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mengirim = true);
    try {
      await ref
          .read(permintaanAksiProvider)
          .kirimPesan(widget.permintaan.id, isi);
      // Dikosongkan HANYA kalau terkirim: pesan yang gagal tetap di kotaknya
      // supaya bisa dicoba lagi, bukan diketik ulang.
      if (mounted) _teks.clear();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final id = widget.permintaan.id;
    final async = ref.watch(pesanPermintaanProvider(id));
    final izin = izinPermintaan(ref);
    final utas = async.value;

    final Widget isi;
    if (utas != null) {
      isi = utas.pesan.isEmpty
          ? Center(
              child: Text(
                l10n.permintaanPesanKosong,
                style: theme.textTheme.bodySmall,
              ),
            )
          // Terlama di atas (server), tapi daftar dibalik + `reverse` supaya
          // pesan terbaru menempel di dasar, dekat kotak ketik.
          : ListView.separated(
              reverse: true,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: utas.pesan.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _Gelembung(pesan: utas.pesan[utas.pesan.length - 1 - i]),
            );
    } else if (async.hasError) {
      isi = _Gagal(
        teks: l10n.permintaanPesanGagal,
        onCobaLagi: () => ref.invalidate(pesanPermintaanProvider(id)),
      );
    } else {
      isi = const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SkeletonBox(height: 64),
      );
    }

    final Widget bawah;
    if (utas != null && !utas.terbuka) {
      bawah = _Catatan(teks: l10n.permintaanPesanDitutup);
    } else if (!izin.balas) {
      bawah = _Catatan(teks: l10n.permintaanBacaSaja);
    } else {
      bawah = _KotakKetik(
        controller: _teks,
        mengirim: _mengirim,
        onKirim: _kirim,
        aktif: utas != null,
      );
    }

    return Column(
      children: [
        Expanded(child: isi),
        bawah,
      ],
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: m.kertas,
          border: Border(top: BorderSide(color: m.garis)),
        ),
        child: Text(teks, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class _KotakKetik extends StatelessWidget {
  const _KotakKetik({
    required this.controller,
    required this.mengirim,
    required this.onKirim,
    required this.aktif,
  });

  final TextEditingController controller;
  final bool mengirim;
  final VoidCallback onKirim;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: m.kertas,
          border: Border(top: BorderSide(color: m.garis)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('isian-pesan-permintaan'),
                controller: controller,
                enabled: aktif,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.permintaanPesanTulis,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SidikTombol(
              key: const ValueKey('kirim-pesan-permintaan'),
              label: l10n.permintaanPesanKirim,
              ikon: Icons.send,
              ragam: RagamTombol.utama,
              sibuk: mengirim,
              onPressed: aktif ? onKirim : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pesan dari lab di kanan (kertas biru tipis), dari pelanggan di kiri.
/// Sisi LAB melihat nama pengirim sebenarnya (kontrak §3.5) — pelanggan tidak.
class _Gelembung extends StatelessWidget {
  const _Gelembung({required this.pesan});

  final PesanPermintaan pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final lab = pesan.dariLab;
    final t = pesan.dibuatPada?.toLocal();
    final waktu = t == null
        ? null
        : '${tanggalPendek(context, t)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t), alwaysUse24HourFormat: true)}';

    return Align(
      alignment: lab ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Kertas(
          warna: lab ? m.biruTipis : null,
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pesan.namaPengirim != null)
                Text(
                  pesan.namaPengirim!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: m.tinta2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Text(pesan.isi, style: theme.textTheme.bodyMedium),
              if (waktu != null) ...[
                const SizedBox(height: 2),
                Text(
                  waktu,
                  style: theme.textTheme.labelSmall?.copyWith(color: m.tinta2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
