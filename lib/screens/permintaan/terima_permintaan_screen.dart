import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/permintaan_pelanggan.dart';
import '../../providers/calibration_input_provider.dart'
    show categoryListProvider;
import '../../providers/jam_provider.dart';
import '../../providers/permintaan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_tombol.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;

/// Kunci galat server untuk satu alat baru (kontrak §3.3).
String _kunciKategori(int itemId) => 'alat_baru.$itemId.equipment_category_id';
String _kunciSerial(int itemId) => 'alat_baru.$itemId.serial_number';

/// Layar Terima. Menerima permintaan melahirkan Order dan MENDAFTARKAN alat
/// baru atas perusahaan pelanggan, jadi admin melengkapi dua hal yang tidak
/// bisa diisi pelanggan dari aplikasinya: **kategori** dan (kalau pelanggan
/// mengosongkannya) **nomor seri**.
///
/// Layar penuh, bukan dialog: satu permintaan bisa membawa puluhan alat baru,
/// dan `TextEditingController` tiap nomor seri harus hidup selama form dibuka
/// — di sini dimiliki `State` layar ini, jadi tidak ada yang dibuang sebelum
/// waktunya.
///
/// Semua-atau-tidak-sama-sekali di server: kalau satu nomor seri bentrok, TIDAK
/// ada alat yang terdaftar dan tidak ada order yang lahir. Jawaban 422-nya
/// dipilah per kunci supaya galatnya muncul di bawah kolom alat yang salah.
class TerimaPermintaanScreen extends ConsumerStatefulWidget {
  const TerimaPermintaanScreen({super.key, required this.permintaan});

  final PermintaanPelanggan permintaan;

  @override
  ConsumerState<TerimaPermintaanScreen> createState() =>
      _TerimaPermintaanScreenState();
}

class _TerimaPermintaanScreenState
    extends ConsumerState<TerimaPermintaanScreen> {
  late final List<AlatPermintaan> _baru;
  final Map<int, TextEditingController> _serial = {};
  final Map<int, int?> _kategori = {};
  final _catatan = TextEditingController();
  late DateTime _tanggalMasuk;
  DateTime? _janji;

  /// kunci galat → pesan. Diisi validasi lokal DAN jawaban 422 server, dengan
  /// kunci yang sama, supaya satu tempat yang menampilkannya.
  Map<String, String> _galat = {};
  List<String> _galatLain = [];
  bool _mengirim = false;

  @override
  void initState() {
    super.initState();
    _baru = [
      for (final a in widget.permintaan.alat)
        if (a.baru && a.equipmentId == null) a,
    ];
    for (final a in _baru) {
      _serial[a.id] = TextEditingController(text: a.serialNumber ?? '');
      _kategori[a.id] = null;
    }
    final hariIni = ref.read(jamProvider)();
    _tanggalMasuk = DateTime(hariIni.year, hariIni.month, hariIni.day);
  }

  @override
  void dispose() {
    for (final c in _serial.values) {
      c.dispose();
    }
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool janji}) async {
    final awal = janji ? (_janji ?? _tanggalMasuk) : _tanggalMasuk;
    final dipilih = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: janji
          ? _tanggalMasuk
          : _tanggalMasuk.subtract(const Duration(days: 30)),
      lastDate: _tanggalMasuk.add(const Duration(days: 730)),
    );
    if (dipilih == null || !mounted) return;
    setState(() {
      if (janji) {
        _janji = dipilih;
      } else {
        _tanggalMasuk = dipilih;
        // Janji yang jatuh sebelum tanggal masuk tidak masuk akal.
        if (_janji != null && _janji!.isBefore(dipilih)) _janji = null;
      }
    });
  }

  /// Validasi lokal: menghemat satu putaran ke server untuk yang pasti 422,
  /// dan memakai kunci galat yang sama dengan server.
  Map<String, String> _periksa() {
    final l10n = AppLocalizations.of(context);
    final hasil = <String, String>{};
    for (final a in _baru) {
      if (_kategori[a.id] == null) {
        hasil[_kunciKategori(a.id)] = l10n.permintaanKategoriWajib;
      }
      if (a.perluNomorSeri && _serial[a.id]!.text.trim().isEmpty) {
        hasil[_kunciSerial(a.id)] = l10n.permintaanSerialWajib;
      }
    }
    return hasil;
  }

  Future<void> _terima() async {
    final awal = _periksa();
    if (awal.isNotEmpty) {
      setState(() {
        _galat = awal;
        _galatLain = [];
      });
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _mengirim = true;
      _galat = {};
      _galatLain = [];
    });

    try {
      final hasil = await ref
          .read(permintaanAksiProvider)
          .terima(
            widget.permintaan.id,
            tanggalMasuk: _tanggalMasuk,
            tanggalJanjiSelesai: _janji,
            catatan: _catatan.text,
            alatBaru: [
              for (final a in _baru)
                LengkapiAlatBaru(
                  itemId: a.id,
                  kategoriId: _kategori[a.id]!,
                  // Nomor seri dikirim hanya kalau admin mengubahnya atau
                  // pelanggan mengosongkannya: mengirim ulang ketikan
                  // pelanggan apa adanya cuma menambah peluang bentrok.
                  serialNumber:
                      _serial[a.id]!.text.trim() ==
                          (a.serialNumber ?? '').trim()
                      ? null
                      : _serial[a.id]!.text,
                ),
            ],
          );
      if (mounted) navigator.pop(hasil);
    } on GalatPermintaan catch (e) {
      if (!mounted) return;
      if (e.status != null) {
        // Admin lain lebih dulu, atau pelanggan membatalkan: formulir ini
        // sudah tidak relevan. Pesan server dibaca apa adanya, lalu kembali
        // ke detail yang sudah disegarkan.
        ref.invalidate(detailPermintaanProvider(widget.permintaan.id));
        ref.invalidate(antreanPermintaanProvider);
        messenger.showSnackBar(SnackBar(content: Text(e.status!)));
        navigator.pop();
        return;
      }
      final cocok = <String, String>{};
      final lain = <String>[];
      e.errors.forEach((kunci, pesan) {
        final dikenal = _baru.any(
          (a) => kunci == _kunciKategori(a.id) || kunci == _kunciSerial(a.id),
        );
        if (dikenal) {
          cocok[kunci] = pesan.first;
        } else {
          lain.addAll(pesan);
        }
      });
      setState(() {
        _galat = cocok;
        _galatLain = lain;
        _mengirim = false;
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
      setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final kategori = ref.watch(categoryListProvider);
    final daftarKategori = [
      for (final c in kategori.value ?? const <Category>[])
        if (c.id != null) c,
    ];
    // Server belum mengirim id kategori: dropdown tidak bisa menghasilkan
    // `equipment_category_id`. Dikatakan terus terang, bukan dibiarkan kosong.
    final idKosong =
        _baru.isNotEmpty && kategori.hasValue && daftarKategori.isEmpty;
    final adaBentrokSerial = _galat.keys.any(
      (k) => k.endsWith('.serial_number'),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.permintaanTerimaJudul)),
      body: ReadableWidth(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    l10n.permintaanTerimaInfo,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_galatLain.isNotEmpty || adaBentrokSerial) ...[
                    const SizedBox(height: AppSpacing.md),
                    Kertas(
                      warna: m.gagalTipis,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _galatLain.isEmpty
                                ? l10n.permintaanSerialBentrokSaran
                                : l10n.permintaanGalatLain,
                            key: const ValueKey('banner-galat-terima'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: m.gagal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          for (final s in _galatLain)
                            Text('• $s', style: theme.textTheme.bodySmall),
                          if (_galatLain.isNotEmpty && adaBentrokSerial)
                            Text(
                              l10n.permintaanSerialBentrokSaran,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_baru.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.permintaanLengkapiAlatBaru,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (idKosong) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.permintaanKategoriIdKosong,
                        key: const ValueKey('kategori-id-kosong'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: m.gagal,
                        ),
                      ),
                    ] else if (kategori.hasError) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.permintaanKategoriGagal,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: m.gagal,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    for (final a in _baru) ...[
                      _FormAlatBaru(
                        alat: a,
                        kategori: daftarKategori,
                        serial: _serial[a.id]!,
                        terpilih: _kategori[a.id],
                        galatKategori: _galat[_kunciKategori(a.id)],
                        galatSerial: _galat[_kunciSerial(a.id)],
                        onKategori: (v) => setState(() {
                          _kategori[a.id] = v;
                          _galat = {..._galat}..remove(_kunciKategori(a.id));
                        }),
                        onSerial: () => setState(() {
                          _galat = {..._galat}..remove(_kunciSerial(a.id));
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _BarisTanggal(
                    key: const ValueKey('tanggal-masuk'),
                    label: l10n.permintaanTanggalMasuk,
                    nilai: tanggalPendek(context, _tanggalMasuk),
                    onTap: () => _pilihTanggal(janji: false),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _BarisTanggal(
                    key: const ValueKey('tanggal-janji'),
                    label: l10n.permintaanJanjiSelesai,
                    nilai: _janji == null
                        ? '—'
                        : tanggalPendek(context, _janji),
                    onTap: () => _pilihTanggal(janji: true),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('isian-catatan-order'),
                    controller: _catatan,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: l10n.permintaanCatatanOrder,
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: m.kertas,
                  border: Border(top: BorderSide(color: m.garis)),
                ),
                child: SidikTombol(
                  key: const ValueKey('kirim-terima-permintaan'),
                  label: l10n.permintaanTerimaKirim,
                  ikon: Icons.check,
                  ragam: RagamTombol.utama,
                  penuh: true,
                  sibuk: _mengirim,
                  onPressed: idKosong ? null : _terima,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisTanggal extends StatelessWidget {
  const _BarisTanggal({
    super.key,
    required this.label,
    required this.nilai,
    required this.onTap,
  });

  final String label;
  final String nilai;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Kertas(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(nilai, style: theme.textTheme.titleSmall),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.event_outlined, size: 18),
        ],
      ),
    );
  }
}

class _FormAlatBaru extends StatelessWidget {
  const _FormAlatBaru({
    required this.alat,
    required this.kategori,
    required this.serial,
    required this.terpilih,
    required this.galatKategori,
    required this.galatSerial,
    required this.onKategori,
    required this.onSerial,
  });

  final AlatPermintaan alat;
  final List<Category> kategori;
  final TextEditingController serial;
  final int? terpilih;
  final String? galatKategori;
  final String? galatSerial;
  final ValueChanged<int?> onKategori;
  final VoidCallback onSerial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final merkModel = [
      if (alat.merk != null && alat.merk!.isNotEmpty) alat.merk!,
      if (alat.model != null && alat.model!.isNotEmpty) alat.model!,
    ].join(' · ');

    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alat.namaAlat, style: theme.textTheme.titleSmall),
          if (merkModel.isNotEmpty)
            Text(merkModel, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            key: ValueKey('kategori-${alat.id}'),
            initialValue: terpilih,
            isExpanded: true,
            items: [
              for (final c in kategori)
                DropdownMenuItem<int>(value: c.id, child: Text(c.nama)),
            ],
            onChanged: onKategori,
            decoration: InputDecoration(
              labelText: l10n.permintaanKategori,
              errorText: galatKategori,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: ValueKey('serial-${alat.id}'),
            controller: serial,
            // Nomor seri = angka ukur: lebar digit tetap, bisa diadu ke pelat.
            style: SidikTheme.gayaAngka(ukuran: 15, berat: FontWeight.w500),
            onChanged: (_) => onSerial(),
            decoration: InputDecoration(
              labelText: l10n.permintaanSerial,
              errorText: galatSerial,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
