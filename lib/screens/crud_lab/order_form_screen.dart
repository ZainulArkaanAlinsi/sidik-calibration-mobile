import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../models/order_kelola.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/order_kelola_provider.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../super_admin/widgets/format_sa.dart';
import '../super_admin/widgets/pesan_layar.dart';
import 'hak_crud_lab.dart';
import 'widgets/baris_item_order.dart';
import 'widgets/kolom_pilih_crud.dart';
import 'widgets/pesan_galat_crud.dart';
import 'widgets/pilih_alat_sheet.dart';
import 'widgets/pilih_pelanggan_sheet.dart';
import 'widgets/pilih_teknisi_sheet.dart';

/// Buat order baru, atau ubah order yang ada ([orderId]).
///
/// - **Buat**: PT dipilih dari daftar pelanggan lab; alat yang ditawarkan HANYA
///   milik PT itu (server menolak alat PT lain dengan `422`). Nomor order
///   dibuat server — tidak ada kolomnya di sini.
/// - **Ubah**: nomor dan PT tetap (server tidak menerima ganti PT bila alatnya
///   sudah bersesi). `items` dikirim lengkap; alat yang sudah masuk kalibrasi
///   dipertahankan server walau dibuang dari daftar (ada catatannya di layar).
///
/// Hanya yang berizin ([HakCrudLab.bolehKelolaOrder]) melihat formulirnya;
/// server tetap menolak yang tidak berhak (403).
class OrderFormScreen extends ConsumerWidget {
  const OrderFormScreen({super.key, this.orderId});

  /// `null` = buat order baru.
  final int? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final judul = orderId == null
        ? l10n.crudOrderFormBuat
        : l10n.crudOrderFormUbah;

    if (!ref.bolehKelolaOrder) {
      return Scaffold(
        appBar: AppBar(title: Text(judul)),
        body: SafeArea(
          top: false,
          child: PesanLayar(ikon: Icons.lock_outline, teks: l10n.crudTanpaIzin),
        ),
      );
    }
    final id = orderId;
    if (id == null) return const _OrderFormIsi();

    return ref
        .watch(orderKelolaDetailProvider(id))
        .when(
          data: (order) => _OrderFormIsi(awal: order),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(judul)),
            body: const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    SkeletonBox(height: 56),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(height: 56),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: Text(judul)),
            body: SafeArea(
              top: false,
              child: PesanLayar(
                ikon: Icons.cloud_off_outlined,
                galat: true,
                teks: e is TokenHilangException
                    ? l10n.historySessionExpired
                    : l10n.crudOrderDetailGagal,
                aksi: AppButton(
                  label: l10n.saCobaLagi,
                  icon: Icons.refresh,
                  variant: AppButtonVariant.secondary,
                  onPressed: () =>
                      ref.invalidate(orderKelolaDetailProvider(id)),
                ),
              ),
            ),
          ),
        );
  }
}

class _OrderFormIsi extends ConsumerStatefulWidget {
  const _OrderFormIsi({this.awal});

  final OrderKalibrasi? awal;

  @override
  ConsumerState<_OrderFormIsi> createState() => _OrderFormIsiState();
}

class _OrderFormIsiState extends ConsumerState<_OrderFormIsi> {
  late final _catatan = TextEditingController(text: widget.awal?.catatan ?? '');

  int? _pelangganId;
  String _pelangganNama = '';
  late DateTime? _masuk;
  DateTime? _janji;
  late String _status;
  late List<ItemOrderForm> _items;

  /// Galat per kolom: pelanggan, masuk, janji, status, catatan, items.
  Map<String, String> _galat = {};

  /// Galat per baris alat (`items.N.*`).
  Map<int, String> _galatItem = {};
  String? _galatUmum;
  bool _menyimpan = false;

  bool get _ubah => widget.awal != null;

  @override
  void initState() {
    super.initState();
    final a = widget.awal;
    _pelangganId = a?.pelangganId;
    _pelangganNama = a?.namaPelanggan ?? '';
    _masuk = a == null
        ? DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          )
        : tanggalDariServer(a.tanggalMasuk);
    _janji = tanggalDariServer(a?.tanggalJanjiSelesai);
    _status = a?.status ?? StatusOrder.baru;
    _items = [for (final i in a?.items ?? const <OrderItem>[]) ItemOrderForm.dariItem(i)];
  }

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _pilihPelanggan() async {
    final l10n = AppLocalizations.of(context);
    final pt = await pilihPelangganCrud(context);
    if (pt == null || !mounted) return;
    final berganti = _pelangganId != pt.id;
    final adaAlat = _items.isNotEmpty;
    setState(() {
      _pelangganId = pt.id;
      _pelangganNama = pt.nama;
      _galat = {..._galat}..remove('pelanggan');
      // Alat milik PT lama tidak sah untuk PT baru: dikosongkan, dan orang
      // diberi tahu (bukan hilang diam-diam).
      if (berganti && _items.isNotEmpty) {
        _items = [];
        _galatItem = {};
      }
    });
    if (berganti && adaAlat && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.crudOrderAlatDikosongkan)));
    }
  }

  Future<DateTime?> _ambilTanggal(DateTime? awal) {
    final sekarang = DateTime.now();
    final batasAwal = DateTime(sekarang.year - 3);
    final batasAkhir = DateTime(sekarang.year + 5);
    var mulai = awal ?? DateTime(sekarang.year, sekarang.month, sekarang.day);
    if (mulai.isBefore(batasAwal)) mulai = batasAwal;
    if (mulai.isAfter(batasAkhir)) mulai = batasAkhir;
    return showDatePicker(
      context: context,
      initialDate: mulai,
      firstDate: batasAwal,
      lastDate: batasAkhir,
    );
  }

  Future<void> _pilihMasuk() async {
    final t = await _ambilTanggal(_masuk);
    if (t == null || !mounted) return;
    setState(() {
      _masuk = t;
      _galat = {..._galat}..remove('masuk');
    });
  }

  Future<void> _pilihJanji() async {
    final t = await _ambilTanggal(_janji ?? _masuk);
    if (t == null || !mounted) return;
    setState(() {
      _janji = t;
      _galat = {..._galat}..remove('janji');
    });
  }

  Future<void> _tambahAlat() async {
    final id = _pelangganId;
    if (id == null) return;
    final dipilih = await pilihAlatPelangganCrud(
      context,
      pelangganId: id,
      namaPelanggan: _pelangganNama,
      sudahDipilih: {for (final i in _items) i.alatId},
    );
    if (dipilih == null || dipilih.isEmpty || !mounted) return;
    setState(() {
      for (final a in dipilih) {
        if (_items.any((i) => i.alatId == a.id)) continue;
        _items = [
          ..._items,
          ItemOrderForm(
            alatId: a.id,
            namaAlat: a.namaAlat,
            serialNumber: a.serialNumber,
          ),
        ];
      }
      _galat = {..._galat}..remove('items');
    });
  }

  Future<void> _pilihTeknisi(int indeks) async {
    final hasil = await pilihTeknisiCrud(
      context,
      terpilihId: _items[indeks].teknisiId,
    );
    if (hasil == null || !mounted) return;
    setState(() {
      _items = [
        for (var i = 0; i < _items.length; i++)
          if (i == indeks) _items[i].salin(teknisi: hasil) else _items[i],
      ];
    });
  }

  bool _valid() {
    final l10n = AppLocalizations.of(context);
    final galat = <String, String>{
      if (!_ubah && _pelangganId == null)
        'pelanggan': l10n.crudOrderPelangganWajib,
      if (_masuk == null) 'masuk': l10n.crudOrderTanggalMasukWajib,
      if (_masuk != null && _janji != null && _janji!.isBefore(_masuk!))
        'janji': l10n.crudOrderJanjiSebelumMasuk,
      if (_catatan.text.trim().length > 1000)
        'catatan': l10n.crudOrderCatatanPanjang,
      if (_items.isEmpty) 'items': l10n.crudOrderAlatWajib,
    };
    setState(() {
      _galat = galat;
      _galatItem = {};
      _galatUmum = galat.isEmpty ? null : l10n.crudOrderGalatUmum;
    });
    return galat.isEmpty;
  }

  /// Memetakan `errors` 422 Laravel ke kolom: `customer_id`, `tanggal_*`,
  /// `status`, `catatan`, `items`, dan `items.N.*` (per baris alat).
  void _petakan422(ApiException e) {
    final l10n = AppLocalizations.of(context);
    final errors = e.body['errors'];
    final kolom = <String, String>{};
    final baris = <int, String>{};

    if (errors is Map) {
      const peta = {
        'customer_id': 'pelanggan',
        'tanggal_masuk': 'masuk',
        'tanggal_janji_selesai': 'janji',
        'status': 'status',
        'catatan': 'catatan',
        'items': 'items',
      };
      for (final MapEntry(:key, :value) in errors.entries) {
        final pesan = value is List && value.isNotEmpty
            ? '${value.first}'
            : (value is String ? value : null);
        if (pesan == null) continue;
        final k = '$key';
        final m = RegExp(r'^items\.(\d+)\.').firstMatch(k);
        if (m != null) {
          baris.putIfAbsent(int.parse(m.group(1)!), () => pesan);
        } else if (peta.containsKey(k)) {
          kolom[peta[k]!] = pesan;
        }
      }
    }

    setState(() {
      _galat = kolom;
      _galatItem = baris;
      _galatUmum = kolom.isEmpty && baris.isEmpty
          ? pesanGalatCrud(l10n, e)
          : l10n.crudOrderGalatUmum;
    });
  }

  Future<void> _simpan() async {
    if (_menyimpan || !_valid()) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _menyimpan = true;
      _galatUmum = null;
    });

    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      final form = FormOrder(
        pelangganId: _pelangganId ?? widget.awal?.pelangganId ?? 0,
        tanggalMasuk: _masuk!,
        tanggalJanjiSelesai: _janji,
        status: _ubah ? _status : null,
        catatan: _catatan.text,
        items: _items,
      );
      final layanan = ref.read(orderKelolaServiceProvider);
      final hasil = _ubah
          ? await layanan.ubah(token, widget.awal!.id, form)
          : await layanan.buat(token, form);

      // Daftar dan detail diambil ulang dari server (nomor & status milik
      // server), bukan ditambal di state lokal.
      ref.read(orderKelolaProvider.notifier).muatUlang();
      if (_ubah) ref.invalidate(orderKelolaDetailProvider(widget.awal!.id));

      if (!mounted) return;
      Navigator.of(context).pop(hasil);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 422) {
        _petakan422(e);
      } else {
        if (e.status == 404) ref.read(orderKelolaProvider.notifier).muatUlang();
        setState(() => _galatUmum = pesanGalatCrud(l10n, e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _galatUmum = pesanGalatCrud(l10n, e, simpanBaru: !_ubah),
      );
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final awal = widget.awal;

    return Scaffold(
      appBar: AppBar(
        title: Text(_ubah ? l10n.crudOrderFormUbah : l10n.crudOrderFormBuat),
      ),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          maksimum: 640,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                _ubah
                    ? l10n.crudOrderIntroUbah(awal!.nomor)
                    : l10n.crudOrderIntroBuat,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LabelKolomCrud(
                label: l10n.crudOrderPelanggan,
                child: KotakPilihCrud(
                  key: const Key('kotak-pelanggan'),
                  label: l10n.crudOrderPelanggan,
                  petunjuk: l10n.crudOrderPilihPelanggan,
                  nilai: _pelangganNama,
                  galat: _galat['pelanggan'],
                  ikon: _ubah ? Icons.lock_outline : Icons.expand_more,
                  aktif: !_ubah && !_menyimpan,
                  saatTekan: _pilihPelanggan,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LabelKolomCrud(
                label: l10n.crudOrderTanggalMasuk,
                child: KotakPilihCrud(
                  key: const Key('kotak-masuk'),
                  label: l10n.crudOrderTanggalMasuk,
                  petunjuk: l10n.crudOrderPilihTanggal,
                  nilai: _masuk == null ? null : tanggalSa(context, _masuk),
                  galat: _galat['masuk'],
                  ikon: Icons.calendar_today_outlined,
                  aktif: !_menyimpan,
                  saatTekan: _pilihMasuk,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LabelKolomCrud(
                label: l10n.crudOrderTanggalJanji,
                child: KotakPilihCrud(
                  key: const Key('kotak-janji'),
                  label: l10n.crudOrderTanggalJanji,
                  petunjuk: l10n.crudOrderPilihTanggal,
                  nilai: _janji == null ? null : tanggalSa(context, _janji),
                  galat: _galat['janji'],
                  ikon: Icons.event_outlined,
                  aktif: !_menyimpan,
                  saatTekan: _pilihJanji,
                  aksiTambahan: _janji == null
                      ? null
                      : IconButton(
                          key: const Key('kosongkan-janji'),
                          tooltip: l10n.crudOrderKosongkanTanggal,
                          icon: const Icon(Icons.clear),
                          onPressed: _menyimpan
                              ? null
                              : () => setState(() => _janji = null),
                        ),
                ),
              ),
              if (_ubah) ...[
                const SizedBox(height: AppSpacing.md),
                LabelKolomCrud(
                  label: l10n.crudOrderStatus,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final s in StatusOrder.semua)
                        ChoiceChip(
                          key: Key('status-$s'),
                          label: Text(StatusBadge.labelApi(s, l10n)),
                          selected: _status == s,
                          onSelected: _menyimpan
                              ? null
                              : (_) => setState(() => _status = s),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              LabelKolomCrud(
                label: l10n.crudOrderCatatanLabel,
                child: Semantics(
                  label: l10n.crudOrderCatatanLabel,
                  child: TextField(
                    key: const Key('isi-catatan'),
                    controller: _catatan,
                    enabled: !_menyimpan,
                    minLines: 2,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    inputFormatters: [LengthLimitingTextInputFormatter(1050)],
                    decoration: InputDecoration(
                      errorText: _galat['catatan'],
                      errorMaxLines: 3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.crudOrderAlatBagian(_items.length),
                  style: tema.textTheme.titleSmall,
                ),
              ),
              if (_ubah) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.crudOrderCatatanSesi,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: BarisItemOrder(
                    key: ValueKey('item-${_items[i].alatId}'),
                    item: _items[i],
                    aktif: !_menyimpan,
                    galat: _galatItem[i],
                    saatUbah: (baru) => _items[i] = baru,
                    saatBuang: () => setState(() {
                      _items = [..._items]..removeAt(i);
                      _galatItem = {};
                    }),
                    saatPilihTeknisi: () => _pilihTeknisi(i),
                  ),
                ),
              if (_galat['items'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _galat['items']!,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              if (_pelangganId == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    l10n.crudOrderAlatPilihPtDulu,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              AppButton(
                key: const Key('tambah-alat'),
                label: l10n.crudOrderTambahAlat,
                icon: Icons.add,
                variant: AppButtonVariant.secondary,
                onPressed: _pelangganId == null || _menyimpan
                    ? null
                    : _tambahAlat,
              ),
              if (_galatUmum != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _galatUmum!,
                    key: const Key('galat-form'),
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                key: const Key('simpan-order'),
                label: l10n.crudSimpan,
                icon: Icons.save_outlined,
                isLoading: _menyimpan,
                onPressed: _menyimpan ? null : _simpan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
