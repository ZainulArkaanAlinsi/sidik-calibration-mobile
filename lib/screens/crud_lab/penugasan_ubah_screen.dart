import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/penugasan.dart';
import '../../models/penugasan_kelola.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/order_kelola_provider.dart' show teknisiAktifProvider;
import '../../providers/penugasan_kelola_provider.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/kode_galat.dart' show kodeDariBadan;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../super_admin/widgets/format_sa.dart';
import '../super_admin/widgets/kolom_berlabel.dart';
import '../super_admin/widgets/pesan_layar.dart';
import 'hak_crud_lab.dart';
import 'widgets/kolom_pilih_crud.dart';
import 'widgets/pesan_galat_crud.dart';

/// Ubah penugasan AKTIF (kontrak CRUD lengkap §4.1): judul, target, catatan,
/// teknisi (yang pertama = ketua), dan baris jenis-alat.
///
/// Hal yang dijaga di sini karena server menjaganya juga:
/// - baris lama dikirim dengan `id` (progres teknisi tidak hilang) dan TANPA
///   `catatan` (kolom itu juga dipakai teknisi untuk catatan progres);
/// - baris yang sudah ada progresnya tidak punya tombol buang
///   (`422 item_sudah_dikerjakan`);
/// - target hanya dikirim bila berubah, dan tanggal BARU tidak boleh sebelum
///   hari ini (tanggal lama yang sudah lewat tetap sah).
class PenugasanUbahScreen extends ConsumerStatefulWidget {
  const PenugasanUbahScreen({super.key, required this.penugasan});

  final Penugasan penugasan;

  @override
  ConsumerState<PenugasanUbahScreen> createState() =>
      _PenugasanUbahScreenState();
}

class _Baris {
  _Baris(this.nilai) : kunci = UniqueKey();

  final Key kunci;
  BarisUbahPenugasan nilai;
}

class _PenugasanUbahScreenState extends ConsumerState<PenugasanUbahScreen> {
  late final _judul = TextEditingController(text: widget.penugasan.judul);
  late final _catatan = TextEditingController(
    text: widget.penugasan.catatan ?? '',
  );
  late DateTime? _target = widget.penugasan.tanggalTarget;
  late final List<int> _teknisi = [
    for (final t in widget.penugasan.teknisi) t.id,
  ];
  late List<_Baris> _baris = [
    for (final b in widget.penugasan.baris) _Baris(BarisUbahPenugasan.dari(b)),
  ];

  /// Kunci: judul, tanggal, catatan, teknisi, item.
  Map<String, String> _galat = {};
  Map<int, String> _galatBaris = {};
  String? _galatUmum;
  bool _menyimpan = false;

  @override
  void dispose() {
    _judul.dispose();
    _catatan.dispose();
    super.dispose();
  }

  DateTime _hariIni() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pilihTarget() async {
    final sekarang = _hariIni();
    final awal = _target ?? sekarang;
    final t = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(
        awal.isBefore(sekarang) ? awal.year : sekarang.year - 1,
      ),
      lastDate: DateTime(sekarang.year + 5),
    );
    if (t == null || !mounted) return;
    setState(() {
      _target = t;
      _galat = {..._galat}..remove('tanggal');
    });
  }

  void _alihTeknisi(int id) {
    setState(() {
      if (!_teknisi.remove(id)) _teknisi.add(id);
      _galat = {..._galat}..remove('teknisi');
    });
  }

  void _tambahBaris() {
    setState(() {
      _baris = [
        ..._baris,
        _Baris(const BarisUbahPenugasan(jenisAlat: '', jumlah: 1)),
      ];
      _galat = {..._galat}..remove('item');
    });
  }

  bool _valid() {
    final l10n = AppLocalizations.of(context);
    final judul = _judul.text.trim();
    final galat = <String, String>{
      if (judul.isEmpty)
        'judul': l10n.crudPenugasanJudulWajib
      else if (judul.length > 150)
        'judul': l10n.crudPenugasanJudulPanjang,
      if (_target != null &&
          _form().tanggalBerubah &&
          _target!.isBefore(_hariIni()))
        'tanggal': l10n.crudPenugasanTanggalLewat,
      if (_catatan.text.trim().length > 1000)
        'catatan': l10n.crudPenugasanCatatanPanjang,
      if (_teknisi.isEmpty)
        'teknisi': l10n.crudPenugasanTeknisiWajib
      else if (_teknisi.length > 20)
        'teknisi': l10n.crudPenugasanTeknisiMaks,
      if (_baris.isEmpty)
        'item': l10n.crudPenugasanBarisWajib
      else if (_baris.length > 50)
        'item': l10n.crudPenugasanBarisMaks,
    };
    final galatBaris = <int, String>{};
    for (var i = 0; i < _baris.length; i++) {
      final b = _baris[i].nilai;
      final jenis = b.jenisAlat.trim();
      if (jenis.isEmpty) {
        galatBaris[i] = l10n.crudPenugasanJenisWajib;
      } else if (jenis.length > 120) {
        galatBaris[i] = l10n.crudPenugasanJenisPanjang;
      } else if (b.jumlah < 1 || b.jumlah > 999) {
        galatBaris[i] = l10n.crudPenugasanJumlahSalah;
      }
    }
    setState(() {
      _galat = galat;
      _galatBaris = galatBaris;
      _galatUmum = galat.isEmpty && galatBaris.isEmpty
          ? null
          : l10n.crudPenugasanGalatUmum;
    });
    return galat.isEmpty && galatBaris.isEmpty;
  }

  FormUbahPenugasan _form() => FormUbahPenugasan(
    judul: _judul.text,
    teknisi: List.of(_teknisi),
    baris: [for (final b in _baris) b.nilai],
    tanggalTarget: _target,
    catatan: _catatan.text,
    awal: widget.penugasan,
  );

  /// Memetakan `errors` 422 Laravel: `judul`, `tanggal_target`, `catatan`,
  /// `teknisi`/`teknisi.N`, `item`, `item.N.*`.
  void _petakan422(ApiException e) {
    final l10n = AppLocalizations.of(context);
    final errors = e.body['errors'];
    final kolom = <String, String>{};
    final baris = <int, String>{};

    if (errors is Map) {
      for (final MapEntry(:key, :value) in errors.entries) {
        final pesan = value is List && value.isNotEmpty
            ? '${value.first}'
            : (value is String ? value : null);
        if (pesan == null) continue;
        final k = '$key';
        final m = RegExp(r'^item\.(\d+)\.').firstMatch(k);
        if (m != null) {
          baris.putIfAbsent(int.parse(m.group(1)!), () => pesan);
        } else if (k == 'judul') {
          kolom['judul'] = pesan;
        } else if (k == 'tanggal_target') {
          kolom['tanggal'] = pesan;
        } else if (k == 'catatan') {
          kolom['catatan'] = pesan;
        } else if (k == 'teknisi' || k.startsWith('teknisi.')) {
          kolom.putIfAbsent('teknisi', () => pesan);
        } else if (k == 'item') {
          kolom['item'] = pesan;
        }
      }
    }

    setState(() {
      _galat = kolom;
      _galatBaris = baris;
      _galatUmum = kolom.isEmpty && baris.isEmpty
          ? pesanGalatCrud(l10n, e)
          : l10n.crudPenugasanGalatUmum;
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

      final hasil = await ref
          .read(penugasanKelolaServiceProvider)
          .ubah(token, widget.penugasan.id, _form());
      ref.read(penugasanKelolaProvider.notifier).muatUlang();

      if (!mounted) return;
      Navigator.of(context).pop(hasil);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (perluMuatUlangCrud(e)) {
        ref.read(penugasanKelolaProvider.notifier).muatUlang();
      }
      if (e.status == 422 && kodeDariBadan(e.body) == null) {
        _petakan422(e);
      } else {
        setState(() => _galatUmum = pesanGalatCrud(l10n, e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _galatUmum = pesanGalatCrud(l10n, e));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final boleh = ref.bolehUbahPenugasan;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.crudPenugasanUbahJudul)),
      body: SafeArea(
        top: false,
        child: !boleh
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.crudTanpaIzin)
            : ReadableWidth(
                maksimum: 640,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Text(
                      l10n.crudPenugasanUbahIntro,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    KolomBerlabel(
                      label: l10n.crudPenugasanJudulLabel,
                      controller: _judul,
                      enabled: !_menyimpan,
                      errorText: _galat['judul'],
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(170)],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LabelKolomCrud(
                      label: l10n.crudPenugasanTanggalTarget,
                      child: KotakPilihCrud(
                        key: const Key('kotak-target'),
                        label: l10n.crudPenugasanTanggalTarget,
                        petunjuk: l10n.crudOrderPilihTanggal,
                        nilai: _target == null
                            ? null
                            : tanggalSa(context, _target),
                        galat: _galat['tanggal'],
                        ikon: Icons.event_outlined,
                        aktif: !_menyimpan,
                        saatTekan: _pilihTarget,
                        aksiTambahan: _target == null
                            ? null
                            : IconButton(
                                key: const Key('kosongkan-target'),
                                tooltip: l10n.crudPenugasanKosongkanTarget,
                                icon: const Icon(Icons.clear),
                                onPressed: _menyimpan
                                    ? null
                                    : () => setState(() => _target = null),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LabelKolomCrud(
                      label: l10n.crudPenugasanCatatanLabel,
                      child: Semantics(
                        label: l10n.crudPenugasanCatatanLabel,
                        child: TextField(
                          key: const Key('isi-catatan-penugasan'),
                          controller: _catatan,
                          enabled: !_menyimpan,
                          minLines: 2,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1050),
                          ],
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
                        l10n.crudPenugasanTeknisiBagian,
                        style: tema.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.crudPenugasanTeknisiIntro,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PilihTeknisi(
                      terpilih: _teknisi,
                      awal: widget.penugasan.teknisi,
                      aktif: !_menyimpan,
                      saatAlih: _alihTeknisi,
                    ),
                    if (_galat['teknisi'] != null)
                      _GalatKecil(_galat['teknisi']!),
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.crudPenugasanBarisBagian(_baris.length),
                        style: tema.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < _baris.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _EditorBaris(
                          key: _baris[i].kunci,
                          nilai: _baris[i].nilai,
                          aktif: !_menyimpan,
                          galat: _galatBaris[i],
                          saatUbah: (baru) => _baris[i].nilai = baru,
                          saatBuang: () => setState(() {
                            _baris = [..._baris]..removeAt(i);
                            _galatBaris = {};
                          }),
                        ),
                      ),
                    if (_galat['item'] != null) _GalatKecil(_galat['item']!),
                    AppButton(
                      key: const Key('tambah-baris'),
                      label: l10n.crudPenugasanTambahBaris,
                      icon: Icons.add,
                      variant: AppButtonVariant.secondary,
                      onPressed: _menyimpan ? null : _tambahBaris,
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
                      key: const Key('simpan-penugasan'),
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

class _GalatKecil extends StatelessWidget {
  const _GalatKecil(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: Text(
          teks,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

/// Pilihan teknisi: yang aktif lab ini + anggota lama yang kini nonaktif
/// (ditandai, boleh dilepas). Urutan terpilih bermakna: yang pertama ketua.
class _PilihTeknisi extends ConsumerWidget {
  const _PilihTeknisi({
    required this.terpilih,
    required this.awal,
    required this.aktif,
    required this.saatAlih,
  });

  final List<int> terpilih;
  final List<AnggotaPenugasan> awal;
  final bool aktif;
  final ValueChanged<int> saatAlih;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(teknisiAktifProvider);

    return async.when(
      loading: () => const Column(
        children: [
          SkeletonBox(height: 40),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(height: 40),
        ],
      ),
      error: (e, _) => PesanLayar(
        ikon: Icons.cloud_off_outlined,
        galat: true,
        teks: e is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.crudPenugasanTeknisiGagal,
        aksi: AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: () => ref.invalidate(teknisiAktifProvider),
        ),
      ),
      data: (teknisi) {
        final pilihan = <({int id, String nama, bool nonaktif})>[
          for (final t in teknisi)
            (id: t.id, nama: t.nama.trim().isEmpty ? t.email : t.nama, nonaktif: false),
          for (final a in awal)
            if (!teknisi.any((t) => t.id == a.id))
              (id: a.id, nama: a.nama, nonaktif: true),
        ];
        if (pilihan.isEmpty) {
          return Text(l10n.crudItemTeknisiKosong);
        }
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final t in pilihan)
              FilterChip(
                key: Key('teknisi-${t.id}'),
                label: Text(
                  [
                    t.nonaktif
                        ? l10n.crudPenugasanTeknisiNonaktif(t.nama)
                        : t.nama,
                    if (terpilih.isNotEmpty && terpilih.first == t.id)
                      l10n.crudPenugasanKetua,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: terpilih.contains(t.id),
                onSelected: aktif ? (_) => saatAlih(t.id) : null,
              ),
          ],
        );
      },
    );
  }
}

/// Satu baris jenis-alat: nama jenis, jumlah, dan (baris baru) catatan.
/// Controller hidup di sini; pemanggil mengunci widget dengan kunci unik.
class _EditorBaris extends StatefulWidget {
  const _EditorBaris({
    super.key,
    required this.nilai,
    required this.aktif,
    required this.saatUbah,
    required this.saatBuang,
    this.galat,
  });

  final BarisUbahPenugasan nilai;
  final bool aktif;
  final ValueChanged<BarisUbahPenugasan> saatUbah;
  final VoidCallback saatBuang;
  final String? galat;

  @override
  State<_EditorBaris> createState() => _EditorBarisState();
}

class _EditorBarisState extends State<_EditorBaris> {
  late final _jenis = TextEditingController(text: widget.nilai.jenisAlat);
  late final _jumlah = TextEditingController(text: '${widget.nilai.jumlah}');
  late final _catatan = TextEditingController(text: widget.nilai.catatan);

  @override
  void initState() {
    super.initState();
    // Pendengar pada controller (KolomBerlabel tidak punya `onChanged`): nilai
    // baris selalu terbaru di induk, tanpa menyentuh widget bersama itu.
    _jenis.addListener(_berubah);
    _jumlah.addListener(_berubah);
    _catatan.addListener(_berubah);
  }

  @override
  void dispose() {
    _jenis.dispose();
    _jumlah.dispose();
    _catatan.dispose();
    super.dispose();
  }

  void _berubah() => widget.saatUbah(
    widget.nilai.salin(
      jenisAlat: _jenis.text,
      // Kosong/tidak terbaca = 0 → ditolak validasi, bukan diam-diam jadi 1.
      jumlah: int.tryParse(_jumlah.text) ?? 0,
      catatan: _catatan.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final b = widget.nilai;
    final terkunci = b.sudahDikerjakan;
    final nama = b.jenisAlat.trim().isEmpty ? '-' : b.jenisAlat.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (b.sudahDikerjakan)
                          l10n.crudPenugasanSelesaiN(b.jumlahSelesai),
                        if ((b.paket ?? '').isNotEmpty)
                          l10n.crudPenugasanPaket(b.paket!),
                      ].join(' · '),
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                // Baris berprogres tidak bisa dibuang: tombolnya nonaktif dan
                // alasannya jadi tooltip (server juga menolak 422).
                IconButton(
                  tooltip: terkunci
                      ? l10n.crudPenugasanBarisTerkunci
                      : l10n.crudPenugasanBuangBaris(nama),
                  icon: const Icon(Icons.close),
                  onPressed: widget.aktif && !terkunci ? widget.saatBuang : null,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KolomBerlabel(
                    label: l10n.crudPenugasanJenisAlat,
                    controller: _jenis,
                    enabled: widget.aktif,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(140)],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  KolomBerlabel(
                    label: l10n.crudPenugasanJumlah,
                    controller: _jumlah,
                    enabled: widget.aktif,
                    keyboardType: TextInputType.number,
                    textInputAction: b.baru
                        ? TextInputAction.next
                        : TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                  if (b.baru) ...[
                    const SizedBox(height: AppSpacing.sm),
                    KolomBerlabel(
                      label: l10n.crudPenugasanBarisCatatan,
                      controller: _catatan,
                      enabled: widget.aktif,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [LengthLimitingTextInputFormatter(500)],
                      ),
                  ],
                  if (widget.galat != null)
                    _GalatKecil(widget.galat!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
