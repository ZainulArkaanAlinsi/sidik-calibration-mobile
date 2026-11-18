import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/alat_pelanggan.dart';
import '../../models/customer.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/riwayat_alat_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import 'hak_super_admin.dart';
import 'pilih_pt_tujuan_screen.dart';
import 'pratinjau_pindah_alat_screen.dart';
import 'widgets/kerangka_kursor.dart';
import 'widgets/pemicu_gulir.dart';
import 'widgets/pesan_layar.dart';

/// Pindahkan alat ke PT lain, langkah 1: pilih alat (dari daftar kursor PT
/// asal) dan PT tujuan. Langkah berikutnya = pratinjau, lalu konfirmasi
/// dengan alasan (`PratinjauPindahAlatScreen`).
///
/// Memperbaiki temuan nyata: sertifikat menempel di PT yang tidak punya akun
/// sementara akun ada di PT lain (PT kembar / salah ketik). Yang pindah hanya
/// alat; nomor dan isi sertifikat tidak disentuh.
class PindahkanAlatScreen extends ConsumerStatefulWidget {
  const PindahkanAlatScreen({super.key, required this.asal});

  /// PT asal.
  final Customer asal;

  /// Batas server: 1-100 alat sekali pindah.
  static const maksAlat = 100;

  @override
  ConsumerState<PindahkanAlatScreen> createState() =>
      _PindahkanAlatScreenState();
}

class _PindahkanAlatScreenState extends ConsumerState<PindahkanAlatScreen> {
  final _dipilih = <int>{};
  Customer? _tujuan;

  Future<void> _pilihTujuan() async {
    final hasil = await Navigator.of(context).push<Customer>(
      MaterialPageRoute<Customer>(
        builder: (_) => PilihPtTujuanScreen(asalId: widget.asal.id),
      ),
    );
    if (hasil != null && mounted) setState(() => _tujuan = hasil);
  }

  Future<void> _lihatPratinjau() async {
    final tujuan = _tujuan;
    if (tujuan == null || _dipilih.isEmpty) return;
    final selesai = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PratinjauPindahAlatScreen(
          asal: widget.asal,
          tujuan: tujuan,
          alatIds: _dipilih.toList(),
        ),
      ),
    );
    if (selesai == true && mounted) Navigator.of(context).pop(true);
  }

  void _ganti(int id, bool dipilih) {
    setState(() {
      if (dipilih) {
        if (_dipilih.length < PindahkanAlatScreen.maksAlat) _dipilih.add(id);
      } else {
        _dipilih.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    // Dua izin: memindah dan melihat daftar alat. Tanpa keduanya terkunci dan
    // server tidak ditanya.
    if (!ref.bolehPindahAlat || !ref.bolehLihatAlatPelanggan) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.saPindahJudul)),
        body: PesanLayar(ikon: Icons.lock_outline, teks: l10n.saTanpaIzin),
      );
    }

    final provider = alatPelangganProvider(widget.asal.id);
    final async = ref.watch(provider);
    final ctl = ref.read(provider.notifier);
    final daftar = async.value;
    final siap = _tujuan != null && _dipilih.isNotEmpty;

    final kepala = <Widget>[
      Text(
        l10n.saPindahIntro,
        style: tema.textTheme.bodyMedium?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(l10n.saPindahTujuan, style: tema.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tujuan?.nama ?? l10n.saPindahTujuanKosong,
                key: const Key('tujuan-terpilih'),
                style: _tujuan == null
                    ? tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      )
                    : tema.textTheme.titleSmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                key: const Key('pilih-tujuan'),
                label: _tujuan == null
                    ? l10n.saPindahPilihTujuan
                    : l10n.saPindahGantiTujuan,
                icon: Icons.business_outlined,
                variant: AppButtonVariant.secondary,
                ringkas: true,
                onPressed: _pilihTujuan,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(l10n.saPindahAlatJudul, style: tema.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      if (daftar != null && daftar.items.isNotEmpty)
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            TextButton(
              key: const Key('pilih-semua'),
              onPressed: () => setState(() {
                for (final a in daftar.items) {
                  if (_dipilih.length >= PindahkanAlatScreen.maksAlat) break;
                  _dipilih.add(a.id);
                }
              }),
              child: Text(l10n.saPindahPilihMuat),
            ),
            if (_dipilih.isNotEmpty)
              TextButton(
                key: const Key('kosongkan-pilihan'),
                onPressed: () => setState(_dipilih.clear),
                child: Text(l10n.saPindahKosongkan),
              ),
          ],
        ),
      if (_dipilih.length >= PindahkanAlatScreen.maksAlat)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(l10n.saPindahMaks, style: tema.textTheme.bodySmall),
        ),
    ];

    // Baris isi daftar alat (di bawah kepala).
    final List<Widget> isi;
    if (daftar == null) {
      if (async.hasError) {
        final galat = async.error!;
        isi = [
          PesanInlineKursor(
            key: const Key('alat-galat'),
            teks: galat is TokenHilangException
                ? l10n.historySessionExpired
                : pesanDaftarKursor(l10n, galat, l10n.saAlatGagal),
            saatCoba: ctl.muatUlang,
          ),
        ];
      } else {
        isi = [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: KerangkaKartuKursor(),
            ),
        ];
      }
    } else if (daftar.items.isEmpty) {
      isi = [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text(
            l10n.saPindahAlatKosong,
            key: const Key('pindah-alat-kosong'),
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    } else {
      isi = [
        for (final a in daftar.items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _KartuPilihAlat(
              alat: a,
              dipilih: _dipilih.contains(a.id),
              bisaDipilih:
                  _dipilih.contains(a.id) ||
                  _dipilih.length < PindahkanAlatScreen.maksAlat,
              saatUbah: (v) => _ganti(a.id, v),
            ),
          ),
        KakiDaftarKursor(
          memuatLagi: daftar.memuatLagi,
          galat: daftar.galatLanjut == null
              ? null
              : pesanDaftarKursor(
                  l10n,
                  daftar.galatLanjut!,
                  l10n.saAlatLanjutGagal,
                ),
          adaLagi: daftar.adaLagi,
          saatMuat: () => ctl.muatLebihBanyak(paksa: true),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saPindahJudul)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ReadableWidth(
                maksimum: 720,
                child: PemicuGulir(
                  saatDekatAkhir: ctl.muatLebihBanyak,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [...kepala, ...isi],
                  ),
                ),
              ),
            ),
            // Tindakan di bilah bawah (bukan di ujung daftar): daftar alat
            // dimuat per halaman, jadi ujungnya bisa jauh.
            ReadableWidth(
              maksimum: 720,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.saPindahDipilih(_dipilih.length),
                      key: const Key('jumlah-dipilih'),
                      style: tema.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppButton(
                      key: const Key('lihat-pratinjau'),
                      label: l10n.saPindahLihatPratinjau,
                      icon: Icons.visibility_outlined,
                      onPressed: siap ? _lihatPratinjau : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuPilihAlat extends StatelessWidget {
  const _KartuPilihAlat({
    required this.alat,
    required this.dipilih,
    required this.bisaDipilih,
    required this.saatUbah,
  });

  final AlatRingkas alat;
  final bool dipilih;
  final bool bisaDipilih;
  final ValueChanged<bool> saatUbah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final merkModel = [
      if (alat.merk.trim().isNotEmpty) alat.merk.trim(),
      if (alat.model.trim().isNotEmpty) alat.model.trim(),
    ].join(' · ');
    final seri = alat.nomorSeri.trim().isEmpty
        ? l10n.saAlatTanpaSeri
        : l10n.saAlatSeri(alat.nomorSeri);

    return Card(
      key: Key('pilih-alat-${alat.id}'),
      child: CheckboxListTile(
        value: dipilih,
        onChanged: bisaDipilih ? (v) => saatUbah(v ?? false) : null,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          alat.nama.trim().isEmpty ? '-' : alat.nama,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (merkModel.isNotEmpty) merkModel,
            '$seri · ${l10n.saAlatJumlahSert(alat.jumlahSertifikat)}',
          ].join('\n'),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
