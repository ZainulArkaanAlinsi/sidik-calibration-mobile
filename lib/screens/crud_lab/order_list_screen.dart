import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../models/order_kelola.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/order_kelola_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import 'aksi_order.dart';
import 'hak_crud_lab.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import '../super_admin/widgets/pesan_layar.dart';
import 'widgets/kartu_order.dart';

/// Daftar order lab (semua status, berpaginasi) dengan cari + saringan status,
/// dan aksi Buat / Ubah / Hapus bagi yang berizin ([HakCrudLab.bolehKelolaOrder]).
///
/// Semua aksi mengambil ulang daftar dari server sesudah sukses (nomor dan
/// status milik server), tidak menambal state lokal. Daftar dibangun malas
/// (`ListView.builder`), jadi ratusan baris tidak membangun kartu di luar layar.
class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _cari = TextEditingController();
  Timer? _debounce;
  bool _memuatLagi = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  OrderKelolaController get _ctl => ref.read(orderKelolaProvider.notifier);

  void _cariBerubah(String kata) {
    _debounce?.cancel();
    // 400 ms: mencari tiap ketikan menembak API tiap huruf.
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _ctl.saring(_ctl.filter.salin(cari: kata));
    });
  }

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

  Future<void> _buat() async {
    final hasil = await Navigator.of(context).push<OrderKalibrasi>(
      MaterialPageRoute<OrderKalibrasi>(
        builder: (_) => const OrderFormScreen(),
      ),
    );
    if (hasil != null && mounted) {
      _kabari(AppLocalizations.of(context).crudOrderBerhasilBuat(hasil.nomor));
    }
  }

  Future<void> _ubah(OrderKalibrasi order) async {
    final hasil = await Navigator.of(context).push<OrderKalibrasi>(
      MaterialPageRoute<OrderKalibrasi>(
        builder: (_) => OrderFormScreen(orderId: order.id),
      ),
    );
    if (hasil != null && mounted) {
      _kabari(AppLocalizations.of(context).crudOrderBerhasilUbah);
    }
  }

  Future<void> _hapus(OrderKalibrasi order) async {
    final ok = await hapusOrderCrud(context, ref, order);
    if (ok && mounted) {
      _kabari(AppLocalizations.of(context).crudOrderHapusBerhasil);
    }
  }

  Future<void> _buka(OrderKalibrasi order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(orderId: order.id),
      ),
    );
    // Detail bisa mengubah atau menghapus order: daftar selalu disegarkan.
    if (mounted) _ctl.muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehKelolaOrder;
    final papanKetikTerbuka = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.crudOrderJudul)),
      body: SafeArea(
        top: false,
        child: !boleh
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.crudTanpaIzin)
            : Column(
                children: [
                  Expanded(
                    child: ReadableWidth(
                      maksimum: 720,
                      child: _Daftar(
                        cari: _cari,
                        saatCari: _cariBerubah,
                        memuatLagi: _memuatLagi,
                        saatMuatLagi: _muatLagi,
                        saatBuka: _buka,
                        saatUbah: _ubah,
                        saatHapus: _hapus,
                      ),
                    ),
                  ),
                  // Tombol dilepas saat papan ketik terbuka supaya tidak
                  // memakan tinggi layar yang sudah sempit.
                  if (!papanKetikTerbuka)
                    SafeArea(
                      top: false,
                      child: ReadableWidth(
                        maksimum: 720,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: AppButton(
                            key: const Key('buat-order'),
                            label: l10n.crudOrderBuat,
                            icon: Icons.add,
                            onPressed: _buat,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Daftar extends ConsumerWidget {
  const _Daftar({
    required this.cari,
    required this.saatCari,
    required this.memuatLagi,
    required this.saatMuatLagi,
    required this.saatBuka,
    required this.saatUbah,
    required this.saatHapus,
  });

  final TextEditingController cari;
  final ValueChanged<String> saatCari;
  final bool memuatLagi;
  final VoidCallback saatMuatLagi;
  final ValueChanged<OrderKalibrasi> saatBuka;
  final ValueChanged<OrderKalibrasi> saatUbah;
  final ValueChanged<OrderKalibrasi> saatHapus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(orderKelolaProvider);
    final ctl = ref.read(orderKelolaProvider.notifier);
    final data = async.value;
    final adaCari = ctl.filter.cari.isNotEmpty || ctl.filter.status != null;

    // Satu `ListView.builder` MALAS untuk semua keadaan: kepala (cari +
    // saringan) selalu item 0, sisanya mengikuti keadaan data.
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
        final order = data.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: KartuOrder(
            key: Key('kartu-order-${order.id}'),
            order: order,
            saatBuka: () => saatBuka(order),
            saatUbah: () => saatUbah(order),
            saatHapus: () => saatHapus(order),
          ),
        );
      };
    } else if (data != null) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 280,
        child: PesanLayar(
          ikon: Icons.receipt_long_outlined,
          teks: adaCari ? l10n.crudOrderKosongCari : l10n.crudOrderKosong,
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
              : l10n.crudOrderGagal,
          aksi: AppButton(
            label: l10n.saCobaLagi,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: ctl.muatUlang,
          ),
        ),
      );
    } else {
      isi = 4;
      bangunIsi = (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: _KerangkaKartu(),
      );
    }

    return RefreshIndicator(
      onRefresh: ctl.muatUlang,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: isi + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _Kepala(cari: cari, saatCari: saatCari);
          return bangunIsi(context, i - 1);
        },
      ),
    );
  }
}

class _Kepala extends ConsumerWidget {
  const _Kepala({required this.cari, required this.saatCari});

  final TextEditingController cari;
  final ValueChanged<String> saatCari;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.watch(orderKelolaProvider);
    final ctl = ref.read(orderKelolaProvider.notifier);
    final f = ctl.filter;

    final pilihan = <(String?, String)>[
      (null, l10n.crudOrderSemua),
      for (final s in StatusOrder.semua) (s, StatusBadge.labelApi(s, l10n)),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: l10n.crudOrderCari,
            child: TextField(
              key: const Key('cari-order'),
              controller: cari,
              onChanged: saatCari,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.crudOrderCari,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (nilai, label) in pilihan)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      key: Key('saring-${nilai ?? 'semua'}'),
                      label: Text(label),
                      selected: f.status == nilai,
                      onSelected: (_) => ctl.saring(f.salin(status: nilai)),
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
            SkeletonBox(height: 16, width: 160),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 220),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 100),
          ],
        ),
      ),
    );
  }
}
