import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/super_admin_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import 'widgets/pesan_layar.dart';

/// Pilih PT tujuan pemindahan alat: cari nama, ketuk satu PT. PT asal tidak
/// ikut daftar (server pun menolaknya: `pt_tujuan_sama`). Mengembalikan
/// [Customer] terpilih lewat `Navigator.pop`.
///
/// Daftar hidup di state layar ini (bukan provider bersama) supaya pencarian
/// di sini tidak mengubah daftar di layar "Pelanggan & anggota".
class PilihPtTujuanScreen extends ConsumerStatefulWidget {
  const PilihPtTujuanScreen({super.key, required this.asalId});

  final int asalId;

  @override
  ConsumerState<PilihPtTujuanScreen> createState() =>
      _PilihPtTujuanScreenState();
}

class _PilihPtTujuanScreenState extends ConsumerState<PilihPtTujuanScreen> {
  final _cari = TextEditingController();
  Timer? _debounce;

  List<Customer> _items = const [];
  int _halaman = 1;
  bool _adaLagi = false;
  bool _memuat = true;
  bool _memuatLagi = false;
  Object? _galat;

  /// Nomor permintaan terakhir: jawaban pencarian lama yang pulang belakangan
  /// tidak boleh menimpa pencarian yang lebih baru.
  int _nomor = 0;

  @override
  void initState() {
    super.initState();
    _muat(1);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat(int halaman) async {
    final nomor = ++_nomor;
    setState(() {
      if (halaman == 1) {
        _memuat = true;
      } else {
        _memuatLagi = true;
      }
      _galat = null;
    });

    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();
      final hasil = await ref
          .read(anggotaPelangganServiceProvider)
          .daftarPelanggan(token, cari: _cari.text, halaman: halaman);
      if (!mounted || nomor != _nomor) return;
      setState(() {
        final baru = hasil.items.where((c) => c.id != widget.asalId);
        _items = halaman == 1 ? baru.toList() : [..._items, ...baru];
        _halaman = hasil.halaman;
        _adaLagi = hasil.adaLagi;
        _memuat = false;
        _memuatLagi = false;
      });
    } catch (e) {
      if (!mounted || nomor != _nomor) return;
      setState(() {
        _galat = e;
        _memuat = false;
        _memuatLagi = false;
      });
    }
  }

  void _cariBerubah(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _muat(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    final Widget isi;
    if (_memuat) {
      isi = ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SkeletonBox(height: 16, width: 200),
                ),
              ),
            ),
        ],
      );
    } else if (_galat != null && _items.isEmpty) {
      isi = PesanLayar(
        ikon: Icons.cloud_off_outlined,
        galat: true,
        teks: _galat is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.saPelGagal,
        aksi: AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: () => _muat(1),
        ),
      );
    } else if (_items.isEmpty) {
      isi = PesanLayar(
        ikon: Icons.business_outlined,
        teks: l10n.saPilihPtKosong,
      );
    } else {
      isi = ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _items.length + (_adaLagi || _galat != null ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(
                child: AppButton(
                  label: _galat != null ? l10n.saCobaLagi : l10n.saMuatLagi,
                  icon: _galat != null ? Icons.refresh : Icons.expand_more,
                  variant: AppButtonVariant.secondary,
                  ringkas: true,
                  isLoading: _memuatLagi,
                  onPressed: () => _muat(_halaman + 1),
                ),
              ),
            );
          }
          final c = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Card(
              child: InkWell(
                key: Key('tujuan-${c.id}'),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                onTap: () => Navigator.of(context).pop(c),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.nama,
                                style: tema.textTheme.titleSmall,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (c.anggotaAktifCount != null)
                                Text(
                                  l10n.saPratinjauAnggotaPt(
                                    c.anggotaAktifCount!,
                                  ),
                                  style: tema.textTheme.bodySmall?.copyWith(
                                    color: tema.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saPilihPtJudul)),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          maksimum: 720,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Semantics(
                  label: l10n.saPilihPtCari,
                  child: TextField(
                    key: const Key('cari-tujuan'),
                    controller: _cari,
                    onChanged: _cariBerubah,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.saPilihPtCari,
                    ),
                  ),
                ),
              ),
              Expanded(child: isi),
            ],
          ),
        ),
      ),
    );
  }
}
