import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/equipment_lookup.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../../providers/order_kelola_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/skeleton.dart';
import '../../super_admin/widgets/kerangka_kursor.dart';
import '../../super_admin/widgets/pemicu_gulir.dart';
import '../../super_admin/widgets/pesan_layar.dart';
import 'kerangka_sheet_pilih.dart';
import 'pesan_galat_crud.dart';

/// Pemilih alat MILIK satu PT (`GET /equipments?customer_id=`): bisa dicari,
/// dipaginasi, dan memilih beberapa alat sekaligus. [sudahDipilih] = id alat
/// yang sudah ada di order (tampil tercentang dan tidak bisa dipilih lagi).
/// Mengembalikan alat BARU yang dipilih, atau `null` bila ditutup.
Future<List<EquipmentLookup>?> pilihAlatPelangganCrud(
  BuildContext context, {
  required int pelangganId,
  required String namaPelanggan,
  required Set<int> sudahDipilih,
}) => bukaSheetPilih<List<EquipmentLookup>>(
  context,
  bangun: (_) => _PilihAlatSheet(
    pelangganId: pelangganId,
    namaPelanggan: namaPelanggan,
    sudahDipilih: sudahDipilih,
  ),
);

class _PilihAlatSheet extends ConsumerStatefulWidget {
  const _PilihAlatSheet({
    required this.pelangganId,
    required this.namaPelanggan,
    required this.sudahDipilih,
  });

  final int pelangganId;
  final String namaPelanggan;
  final Set<int> sudahDipilih;

  @override
  ConsumerState<_PilihAlatSheet> createState() => _PilihAlatSheetState();
}

class _PilihAlatSheetState extends ConsumerState<_PilihAlatSheet> {
  final _cari = TextEditingController();
  Timer? _debounce;

  final List<EquipmentLookup> _items = [];
  final Map<int, EquipmentLookup> _dipilih = {};
  int _halaman = 1;
  int _halamanTerakhir = 1;
  bool _memuat = true;
  bool _memuatLagi = false;
  Object? _galat;
  Object? _galatLagi;

  /// Nomor permintaan terakhir: balasan yang ketinggalan (kata cari sudah
  /// berganti) dibuang, bukan menimpa hasil yang lebih baru.
  int _nomor = 0;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return token;
  }

  Future<void> _muat() async {
    final nomor = ++_nomor;
    setState(() {
      _memuat = true;
      _galat = null;
      _galatLagi = null;
    });
    try {
      final hasil = await ref
          .read(orderKelolaServiceProvider)
          .alatPelanggan(
            await _token(),
            widget.pelangganId,
            cari: _cari.text,
          );
      if (!mounted || nomor != _nomor) return;
      setState(() {
        _items
          ..clear()
          ..addAll(hasil.items);
        _halaman = hasil.halaman;
        _halamanTerakhir = hasil.halamanTerakhir;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted || nomor != _nomor) return;
      setState(() {
        _galat = e;
        _memuat = false;
      });
    }
  }

  Future<void> _muatLagi() async {
    if (_memuatLagi || _memuat || _halaman >= _halamanTerakhir) return;
    final nomor = _nomor;
    setState(() {
      _memuatLagi = true;
      _galatLagi = null;
    });
    try {
      final hasil = await ref
          .read(orderKelolaServiceProvider)
          .alatPelanggan(
            await _token(),
            widget.pelangganId,
            cari: _cari.text,
            halaman: _halaman + 1,
          );
      if (!mounted || nomor != _nomor) return;
      setState(() {
        _items.addAll(hasil.items);
        _halaman = hasil.halaman;
        _halamanTerakhir = hasil.halamanTerakhir;
        _memuatLagi = false;
      });
    } catch (e) {
      if (!mounted || nomor != _nomor) return;
      setState(() {
        _galatLagi = e;
        _memuatLagi = false;
      });
    }
  }

  void _cariBerubah(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _muat();
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
              child: SkeletonBox(height: 56),
            ),
        ],
      );
    } else if (_galat != null) {
      isi = PesanLayar(
        ikon: Icons.cloud_off_outlined,
        galat: true,
        teks: _galat is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.crudPilihAlatGagal,
        aksi: AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: _muat,
        ),
      );
    } else if (_items.isEmpty) {
      isi = PesanLayar(
        ikon: Icons.precision_manufacturing_outlined,
        teks: l10n.crudPilihAlatKosong,
      );
    } else {
      isi = PemicuGulir(
        saatDekatAkhir: _muatLagi,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: _items.length + 1,
          itemBuilder: (context, i) {
            if (i == _items.length) {
              return KakiDaftarKursor(
                memuatLagi: _memuatLagi,
                galat: _galatLagi == null
                    ? null
                    : pesanGalatCrud(l10n, _galatLagi!),
                adaLagi: _halaman < _halamanTerakhir,
                saatMuat: _muatLagi,
              );
            }
            final alat = _items[i];
            final sudah = widget.sudahDipilih.contains(alat.id);
            final terpilih = sudah || _dipilih.containsKey(alat.id);
            final detail = [
              if (alat.serialNumber.isNotEmpty) alat.serialNumber,
              if (alat.merk.isNotEmpty) alat.merk,
              if (alat.model.isNotEmpty) alat.model,
            ].join(' · ');
            return CheckboxListTile(
              key: Key('alat-${alat.id}'),
              value: terpilih,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: sudah
                  ? null
                  : (nilai) => setState(() {
                      if (nilai == true) {
                        _dipilih[alat.id] = alat;
                      } else {
                        _dipilih.remove(alat.id);
                      }
                    }),
              title: Text(
                alat.namaAlat,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                sudah
                    ? [
                        l10n.crudPilihAlatSudah,
                        if (detail.isNotEmpty) detail,
                      ].join(' · ')
                    : detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodySmall,
              ),
            );
          },
        ),
      );
    }

    return KerangkaSheetPilih(
      judul: l10n.crudPilihAlatJudul(widget.namaPelanggan),
      cari: _cari,
      saatCari: _cariBerubah,
      petunjukCari: l10n.crudPilihAlatCari,
      isi: isi,
      bawah: AppButton(
        key: const Key('tambah-alat-terpilih'),
        label: _dipilih.isEmpty
            ? l10n.crudPilihAlatPilihDulu
            : l10n.crudPilihAlatTambah(_dipilih.length),
        icon: Icons.add,
        onPressed: _dipilih.isEmpty
            ? null
            : () => Navigator.of(context).pop(_dipilih.values.toList()),
      ),
    );
  }
}
