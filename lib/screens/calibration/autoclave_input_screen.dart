import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../models/equipment_lookup.dart';
import '../../models/standard.dart';
import '../../providers/auth_provider.dart' show tokenStorageProvider;
import '../../providers/autoclave_provider.dart';
import '../../providers/calibration_input_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/autoclave_hasil_panel.dart';

/// Lembar Kerja Autoklaf (SIDIK-FM-CAL-0539_Rev.4 / LK-285-IDN) — layar input
/// teknisi.
///
/// Susunannya dibikin SEBARIS-SEBARIS ngikut kertasnya: panel General
/// Information, lalu panel Data Result yang isinya SATU tabel (Set Point +
/// lima kolom waktu × tujuh baris), lalu Standard Used, Catatan, dan tanda
/// tangan. Bukan kemiripan gaya — teknisi ngisi layar ini sambil megang kertas
/// yang barusan dia tulis di lapangan, dan matanya lompat baris per baris.
/// Versi sebelumnya numpang bentuk lembar pH: bagian bernomor, suhu & tekanan
/// kepisah dua kartu, dan dua baris kertas (`Indikator Pressure`, `Tekanan atm
/// awal`) nggak ada tempatnya sama sekali. Baris ke-5 di kertas itu Indikator
/// Pressure, di layar lama baris ke-5 itu Suhu Ruang — kalau nyalinnya keburu,
/// tekanan manometer masuk ke kolom suhu, dan angka itu jalan terus sampai
/// sertifikat.
///
/// Autoklaf punya layar sendiri (bukan `LembarKerjaScreen` generik) karena satu
/// sesi mengukur DUA besaran sekaligus dan tabelnya matriks, bukan "titik ukur
/// × pengulangan".
///
/// **Nggak ada rumus di layar ini.** Rata-rata, koreksi, Kestabilan/Keseragaman/
/// Variasi, konversi satuan, dan U95 semua dari backend
/// (`POST /calibrations/autoclave/preview`). Layar cuma ngumpulin angka.
class AutoclaveInputScreen extends ConsumerStatefulWidget {
  const AutoclaveInputScreen({super.key, this.judulTambahan, this.kategori});

  /// Nama alat, buat subjudul app bar (mis. "Autoclave").
  final String? judulTambahan;

  /// Kode kategori alat — nyaring picker Equipment biar cuma alat relevan.
  final String? kategori;

  @override
  ConsumerState<AutoclaveInputScreen> createState() =>
      _AutoclaveInputScreenState();
}

class _AutoclaveInputScreenState extends ConsumerState<AutoclaveInputScreen> {
  static const String _kodeDokumen = 'SIDIK-FM-CAL-0539_Rev.4';
  static const String _kodeLembar = 'LK-285-IDN';

  static const int _jumlahDisk = 3;
  static const int _jumlahTitikWaktu = 5;
  static const int _jumlahPembacaanTekanan = 5;

  static const List<String> _satuanTekanan = [
    'Bar',
    'MPa',
    'kPa',
    'Psi',
    'kg/cm2',
    'inHg',
    'mmHg',
    'Pa',
  ];
  static const List<String> _displayTekanan = [
    'Digital',
    'Analog 1',
    'Analog 2',
    'Analog 3',
  ];

  /// Kotak centang "Standard Used:" — dua baris, persis kayak yang tercetak.
  static const List<String> _standarTercetak = [
    'Temperature Calibrator -Technosoft (Disk 1,2,3)',
    'Pressure Disk Logger-Technosoft',
  ];

  /// Unit thermohygro yang TERCETAK di kertas Autoklaf. Unit lain tetap bisa
  /// dipilih lewat daftar "unit lain" — kertas yang nggak nyetak satu unit
  /// bukan bukti unit itu nggak pernah dibawa ke lapangan.
  static const List<String> _thermohygroTercetak = ['TH-2', 'TH-6', 'TH-7'];

  // ---- General Information ----
  DateTime? _tanggalTerima;
  DateTime _tanggalKalibrasi = DateTime.now();
  final _customerCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();

  String _lokasi = 'onsite';
  final _suhuAwalCtrl = TextEditingController();
  final _suhuAkhirCtrl = TextEditingController();
  final _rhAwalCtrl = TextEditingController();
  final _rhAkhirCtrl = TextEditingController();
  int? _thermohygroId;

  int? _equipmentId;
  final _merkCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  final _rangeSuhuCtrl = TextEditingController();
  final _resolusiSuhuCtrl = TextEditingController();
  final _rangeTekananCtrl = TextEditingController();
  final _resolusiTekananCtrl = TextEditingController();
  String _satuan = 'MPa';

  // ---- Data Result ----
  final _setPointCtrl = TextEditingController(text: '121');
  late final List<TextEditingController> _waktu;
  late final List<List<TextEditingController>> _disk;
  late final List<TextEditingController> _indikatorSuhu;
  late final List<TextEditingController> _indikatorPressure;
  late final List<TextEditingController> _tekananAtm;
  late final List<TextEditingController> _suhuRuang;

  // Di luar kertas: angkanya diunduh dari Pressure Disk Logger.
  late final List<TextEditingController> _pembacaanTekanan;
  String _display = 'Digital';

  final List<bool> _standarDicek = List.filled(_standarTercetak.length, false);
  final _catatanCtrl = TextEditingController();

  bool _menyimpan = false;
  String? _errorInput;

  @override
  void initState() {
    super.initState();
    List<TextEditingController> kolom() =>
        List.generate(_jumlahTitikWaktu, (_) => TextEditingController());

    _waktu = kolom();
    _disk = List.generate(_jumlahDisk, (_) => kolom());
    _indikatorSuhu = kolom();
    _indikatorPressure = kolom();
    _tekananAtm = kolom();
    _suhuRuang = kolom();
    _pembacaanTekanan = List.generate(
      _jumlahPembacaanTekanan,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final c in [
      _setPointCtrl,
      _customerCtrl,
      _alamatCtrl,
      _suhuAwalCtrl,
      _suhuAkhirCtrl,
      _rhAwalCtrl,
      _rhAkhirCtrl,
      _merkCtrl,
      _typeCtrl,
      _snCtrl,
      _rangeSuhuCtrl,
      _resolusiSuhuCtrl,
      _rangeTekananCtrl,
      _resolusiTekananCtrl,
      _catatanCtrl,
      ..._waktu,
      ..._indikatorSuhu,
      ..._indikatorPressure,
      ..._tekananAtm,
      ..._suhuRuang,
      ..._pembacaanTekanan,
      for (final baris in _disk) ...baris,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- Perakitan payload ----

  double? _num(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  List<double?> _kolom(List<TextEditingController> ctrls) =>
      ctrls.map(_num).toList();

  bool _adaIsi(Iterable<double?> xs) => xs.any((x) => x != null);

  List<String?> _jam() =>
      _waktu.map((c) => c.text.trim().isEmpty ? null : c.text.trim()).toList();

  /// Rakit payload `POST /calibrations/autoclave/preview`.
  ///
  /// `uut_setting` SENGAJA nggak dikirim: di kertas angka itu ada di baris
  /// Indikator Pressure, dan backend yang mutusin (kalau kelima kolomnya sama,
  /// itu yang kepakai; kalau beda, kirimannya ditolak dengan pesan jelas).
  /// Ngerata-rata di layar bakal bikin angka yang nggak pernah ditulis siapa
  /// pun ikut ke sertifikat.
  Map<String, dynamic>? _payload() {
    setState(() => _errorInput = null);

    final setPoint = _num(_setPointCtrl);
    if (setPoint == null) {
      setState(() => _errorInput = 'Set Point wajib diisi.');
      return null;
    }

    final payload = <String, dynamic>{'set_point': setPoint};

    final jam = _jam();
    if (jam.any((x) => x != null)) payload['waktu'] = jam;

    final disk = _disk.map(_kolom).toList();
    final indikatorSuhu = _kolom(_indikatorSuhu);
    final suhuRuang = _kolom(_suhuRuang);
    final adaSuhu = disk.any(_adaIsi) || _adaIsi(indikatorSuhu);
    if (adaSuhu) {
      payload['suhu'] = {
        'disk': disk,
        'indikator': indikatorSuhu,
        'suhu_ruang': suhuRuang,
      };
    }

    final indikatorPressure = _kolom(_indikatorPressure);
    final tekananAtm = _kolom(_tekananAtm);
    final bacaanStandar = _kolom(_pembacaanTekanan);
    final adaTekanan =
        _adaIsi(indikatorPressure) ||
        _adaIsi(tekananAtm) ||
        _adaIsi(bacaanStandar);
    if (adaTekanan) {
      payload['tekanan'] = {
        'indikator_pressure': indikatorPressure,
        'tekanan_atm_awal': tekananAtm,
        'satuan': _satuan,
        'display': _display,
        'pembacaan_standar': bacaanStandar,
      };
    }

    if (!adaSuhu && !adaTekanan) {
      setState(
        () => _errorInput =
            'Isi minimal satu blok: data Suhu (disk/indikator) atau Tekanan.',
      );
      return null;
    }

    return payload;
  }

  Future<void> _hitung() async {
    FocusScope.of(context).unfocus();
    final payload = _payload();
    if (payload == null) return;
    await ref.read(autoclavePratinjauProvider.notifier).hitung(payload);
  }

  /// Payload simpan = data ukur + identitas lembar. Equipment & tanggal wajib
  /// buat kirim; sisanya opsional — kolom yang belum keisi di lapangan nggak
  /// boleh nahan kiriman.
  Map<String, dynamic>? _payloadSimpan() {
    final ukur = _payload();
    if (ukur == null) return null;

    if (_equipmentId == null) {
      setState(
        () => _errorInput = 'Pilih Alat (Equipment) dulu sebelum menyimpan.',
      );
      return null;
    }

    String? teks(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    return {
      ...ukur,
      'equipment_id': _equipmentId,
      'tanggal_kalibrasi': _tanggalKalibrasi.toIso8601String().substring(0, 10),
      if (_tanggalTerima != null)
        'tanggal_terima': _tanggalTerima!.toIso8601String().substring(0, 10),
      if (teks(_customerCtrl) != null) 'pemilik_nama': teks(_customerCtrl),
      if (teks(_alamatCtrl) != null) 'pemilik_alamat': teks(_alamatCtrl),
      'lokasi': _lokasi,
      if (_thermohygroId != null) 'thermohygro_standard_id': _thermohygroId,
      if (_num(_suhuAwalCtrl) != null) 'suhu_awal': _num(_suhuAwalCtrl),
      if (_num(_suhuAkhirCtrl) != null) 'suhu_akhir': _num(_suhuAkhirCtrl),
      if (_num(_rhAwalCtrl) != null) 'kelembaban_awal': _num(_rhAwalCtrl),
      if (_num(_rhAkhirCtrl) != null) 'kelembaban_akhir': _num(_rhAkhirCtrl),
      if (teks(_merkCtrl) != null) 'alat_merk': teks(_merkCtrl),
      if (teks(_typeCtrl) != null) 'alat_model': teks(_typeCtrl),
      if (teks(_snCtrl) != null) 'alat_serial_number': teks(_snCtrl),
      if (teks(_catatanCtrl) != null) 'catatan_teknisi': teks(_catatanCtrl),
    };
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    final payload = _payloadSimpan();
    if (payload == null) return;

    setState(() => _menyimpan = true);
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw Exception('Sesi login habis, masuk lagi.');
      await ref.read(autoclaveServiceProvider).simpan(token, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi Autoklaf terkirim ke admin.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorInput = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _pilihTanggal({required bool terima}) async {
    final awal = terima
        ? (_tanggalTerima ?? DateTime.now())
        : _tanggalKalibrasi;
    final hasil = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (hasil == null) return;
    setState(() {
      if (terima) {
        _tanggalTerima = hasil;
      } else {
        _tanggalKalibrasi = hasil;
      }
    });
  }

  // ---- Tampilan ----

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(autoclavePratinjauProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration Worksheet - Autoclave'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              [
                'PT. SIDIK',
                _kodeDokumen,
                _kodeLembar,
                if (widget.judulTambahan != null) widget.judulTambahan!,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _panel('General Information', [
            _blokPenerimaan(theme),
            const Divider(height: AppSpacing.lg),
            _blokKondisi(theme),
            const Divider(height: AppSpacing.lg),
            _blokIdentitasAlat(theme),
          ]),
          const SizedBox(height: AppSpacing.md),
          _panel('Data Result', [
            Text(
              'Calibration Result for Temperature & Pressure',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            _tabelHasil(theme),
            const SizedBox(height: AppSpacing.md),
            _blokDiLuarKertas(theme),
          ]),
          const SizedBox(height: AppSpacing.md),
          _panel('Standard Used:', [_blokStandar(theme)]),
          const SizedBox(height: AppSpacing.md),
          _panel('Catatan:', [_blokPenutup(theme)]),
          const SizedBox(height: AppSpacing.lg),
          if (_errorInput != null) ...[
            Text(
              _errorInput!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Hitung',
                  variant: AppButtonVariant.secondary,
                  isLoading: status.menghitung,
                  onPressed: _hitung,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Simpan & Kirim',
                  isLoading: _menyimpan,
                  onPressed: _simpan,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (status.gagal != null) ...[
            _KotakError(pesan: '${status.gagal}'),
            const SizedBox(height: AppSpacing.md),
          ],
          if (status.hasil != null)
            AutoclaveHasilPanel(hasil: status.hasil!, judul: 'Hasil Olah Data'),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  /// Empat baris teratas kertas: Receive Date / Customer / Addresss /
  /// Calibration Date. "Addresss" emang tiga huruf s — ditulis apa adanya biar
  /// bisa diadu langsung sama formulirnya.
  Widget _blokPenerimaan(ThemeData theme) {
    return Column(
      children: [
        _baris(
          'Receive Date',
          _kotakTanggal(
            _tanggalTerima,
            kosong: 'belum diisi',
            onTap: () => _pilihTanggal(terima: true),
          ),
        ),
        _baris(
          'Customer',
          _fieldTeks(_customerCtrl, fieldKey: const Key('ac_customer')),
        ),
        _baris('Addresss', _fieldTeks(_alamatCtrl, barisBanyak: true)),
        _baris(
          'Calibration Date',
          _kotakTanggal(
            _tanggalKalibrasi,
            onTap: () => _pilihTanggal(terima: false),
          ),
        ),
      ],
    );
  }

  /// Kolom KIRI blok kedua kertas: lokasi, kondisi lingkungan, thermohygro.
  Widget _blokKondisi(ThemeData theme) {
    return Column(
      children: [
        _baris(
          'Location of Calibration',
          DropdownButtonFormField<String>(
            initialValue: _lokasi,
            isExpanded: true,
            decoration: _dekorasi(),
            items: const [
              DropdownMenuItem(value: 'lab', child: Text('In lab')),
              DropdownMenuItem(value: 'onsite', child: Text('Insitu')),
            ],
            onChanged: (v) => setState(() => _lokasi = v ?? _lokasi),
          ),
        ),
        _baris('T awal', _fieldAngka(_suhuAwalCtrl, akhiran: '°C')),
        _baris('T akhir', _fieldAngka(_suhuAkhirCtrl, akhiran: '°C')),
        _baris('RH awal', _fieldAngka(_rhAwalCtrl, akhiran: '%RH')),
        _baris('RH akhir', _fieldAngka(_rhAkhirCtrl, akhiran: '%RH')),
        const SizedBox(height: AppSpacing.sm),
        _blokThermohygro(theme),
      ],
    );
  }

  /// Kotak centang Thermohygro. Yang digambar sebagai kotak = yang TERCETAK di
  /// kertas (TH-2/TH-6/TH-7); unit lain tetap kepilih lewat dropdown di
  /// bawahnya. Id-nya diambil dari bentuk lembar backend, bukan dipetakan di
  /// sini — nomor unit itu label, `standard_id` yang nentuin tabel koreksi mana
  /// yang kepakai.
  Widget _blokThermohygro(ThemeData theme) {
    final master = ref.watch(standardListProvider);

    // Unit thermohygro = standar yang punya `parameterKondisi` (tabel koreksi
    // suhu/kelembaban). Diambil dari master, BUKAN dipetakan di layar: nomor
    // unit itu label, `standard_id` yang nentuin tabel koreksi mana yang
    // kepakai — dan Env. Condition pernah meleset gara-gara unit ketuker.
    final unit = master.maybeWhen(
      data: (list) => list.where((s) => s.parameterKondisi != null).toList(),
      orElse: () => const <Standard>[],
    );

    Standard? cari(String label) =>
        unit.where((s) => s.nama == label).firstOrNull;

    final lainnya = unit
        .where((s) => !_thermohygroTercetak.contains(s.nama))
        .toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thermohygro used', style: theme.textTheme.bodySmall),
          for (final label in _thermohygroTercetak)
            Builder(
              builder: (_) {
                final unitIni = cari(label);
                return CheckboxListTile(
                  key: Key('ac_th_$label'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(label),
                  // Kotak yang unitnya belum keseed di master tetap KELIHATAN
                  // (kertasnya nyetak dia), cuma nggak bisa dicentang — biar
                  // bedanya "belum kedaftar di master" vs "nggak ada di
                  // formulir" kebaca.
                  value: unitIni != null && _thermohygroId == unitIni.id,
                  onChanged: unitIni == null
                      ? null
                      : (pilih) => setState(
                          () => _thermohygroId = pilih == true
                              ? unitIni.id
                              : null,
                        ),
                );
              },
            ),
          if (lainnya.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DropdownButtonFormField<int>(
                initialValue: lainnya.any((s) => s.id == _thermohygroId)
                    ? _thermohygroId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Unit lain (di luar yang tercetak)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final s in lainnya)
                    DropdownMenuItem(value: s.id, child: Text(s.nama)),
                ],
                onChanged: (v) => setState(() => _thermohygroId = v),
              ),
            ),
        ],
      ),
    );
  }

  /// Kolom KANAN blok kedua kertas. Empat baris terakhir punya kurung satuan
  /// kosong `( )` di kertas — satuannya ditulis teknisi, bukan dipatok
  /// formulir, karena range autoklaf datang dalam MPa, bar, atau psi tergantung
  /// mereknya.
  Widget _blokIdentitasAlat(ThemeData theme) {
    final alatAsync = ref.watch(equipmentLookupProvider(widget.kategori));

    return Column(
      children: [
        _baris(
          'Equipment Name',
          alatAsync.when(
            data: (list) => DropdownButtonFormField<int>(
              key: const Key('ac_equipment'),
              initialValue: list.any((a) => a.id == _equipmentId)
                  ? _equipmentId
                  : null,
              isExpanded: true,
              decoration: _dekorasi(petunjuk: 'pilih alat'),
              items: [
                for (final EquipmentLookup a in list)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(
                      '${a.namaAlat} — ${a.serialNumber}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _equipmentId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Gagal muat daftar alat: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
        _baris('Manufacturer', _fieldTeks(_merkCtrl)),
        _baris('Type', _fieldTeks(_typeCtrl)),
        _baris('SN', _fieldTeks(_snCtrl)),
        _baris('Range Temp.', _fieldAngka(_rangeSuhuCtrl, akhiran: '( °C )')),
        _baris(
          'Resolution Temp.',
          _fieldAngka(_resolusiSuhuCtrl, akhiran: '( °C )'),
        ),
        _baris(
          'Range Pressure',
          _fieldAngka(_rangeTekananCtrl, akhiran: '( $_satuan )'),
        ),
        _baris(
          'Resolution Pressure',
          _fieldAngka(_resolusiTekananCtrl, akhiran: '( $_satuan )'),
        ),
        _baris(
          'Pressure Unit',
          DropdownButtonFormField<String>(
            initialValue: _satuan,
            isExpanded: true,
            decoration: _dekorasi(),
            items: [
              for (final s in _satuanTekanan)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _satuan = v ?? _satuan),
          ),
        ),
      ],
    );
  }

  /// SATU tabel, persis kayak kertas: Set Point di pojok kiri, banner
  /// "Pengukuran Berulang UUT Selama Proses Sterilisasi" di atas lima kolom
  /// waktu, lalu tujuh baris — Disk 1/2/3 → Indikator Suhu → Indikator
  /// Pressure → Tekanan atm awal → Suhu Ruang.
  Widget _tabelHasil(ThemeData theme) {
    const lebarLabel = 148.0;
    const lebarKolom = 96.0;

    Widget selLabel(String teks, {bool tebal = false}) => Container(
      width: lebarLabel,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        teks,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: tebal ? FontWeight.w600 : null,
        ),
      ),
    );

    Widget barisAngka(
      String label,
      List<TextEditingController> ctrls, {
      String? satuan,
      Key? kunciPertama,
    }) {
      // IntrinsicHeight: sel label diwarnai penuh setinggi barisnya (garis
      // tabel kertas), dan `stretch` butuh tinggi terbatas — di dalam ListView
      // tingginya tak terbatas.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            selLabel(satuan == null ? label : '$label ($satuan)'),
            for (final (i, c) in ctrls.indexed)
              SizedBox(
                width: lebarKolom,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _fieldAngka(
                    c,
                    rapat: true,
                    fieldKey: i == 0 ? kunciPertama : null,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Set Point + banner kolom.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                selLabel('Set Point (°C)', tebal: true),
                SizedBox(
                  width: lebarKolom,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: _fieldAngka(
                      _setPointCtrl,
                      rapat: true,
                      fieldKey: const Key('ac_setpoint'),
                    ),
                  ),
                ),
                Container(
                  width: lebarKolom * (_jumlahTitikWaktu - 1),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Text(
                    'Pengukuran Berulang UUT Selama Proses Sterilisasi',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          // Baris "Time" — jam beneran (kertas nulis __:__:__:__), bukan nomor
          // urut. Tanpa jamnya, lima kolom angka nggak bisa diadu balik ke
          // rekaman disk waktu sertifikatnya diperiksa.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                selLabel('Time', tebal: true),
                for (final (i, c) in _waktu.indexed)
                  SizedBox(
                    width: lebarKolom,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: TextField(
                        key: i == 0 ? const Key('ac_waktu0') : null,
                        controller: c,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.datetime,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: const InputDecoration(
                          hintText: '--:--:--',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var d = 0; d < _jumlahDisk; d++)
            barisAngka(
              'Temp. Disk ${d + 1}',
              _disk[d],
              satuan: '°C',
              kunciPertama: d == 0 ? const Key('ac_disk1_0') : null,
            ),
          barisAngka('Indikator Suhu', _indikatorSuhu, satuan: '°C'),
          barisAngka(
            'Indikator Pressure',
            _indikatorPressure,
            satuan: _satuan,
            kunciPertama: const Key('ac_indikator_p0'),
          ),
          barisAngka('Tekanan atm awal', _tekananAtm, satuan: _satuan),
          barisAngka('Suhu Ruang', _suhuRuang, satuan: '°C'),
        ],
      ),
    );
  }

  /// Blok yang MEMANG nggak ada di kertas — dipisah dan diberi label supaya
  /// nggak kebaca sebagai baris formulir waktu lembarnya diadu ke aslinya.
  Widget _blokDiLuarKertas(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Di luar kertas — unduhan Pressure Disk Logger',
            style: theme.textTheme.labelLarge,
          ),
          Text(
            'Angkanya diunduh dari disk logger, bukan ditulis di lapangan. '
            'Boleh dikosongin: lembarnya tetap kekirim, olah data tekanannya '
            'nunggu angka ini lengkap.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Standar Reading (Bar)', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final (i, c) in _pembacaanTekanan.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: _fieldAngka(
                      c,
                      rapat: true,
                      fieldKey: i == 0 ? const Key('ac_p0') : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _display,
            decoration: const InputDecoration(
              labelText: 'Tipe Display (Pressure)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final s in _displayTekanan)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _display = v ?? _display),
          ),
        ],
      ),
    );
  }

  Widget _blokStandar(ThemeData theme) {
    return Column(
      children: [
        for (final (i, label) in _standarTercetak.indexed)
          CheckboxListTile(
            key: Key('ac_standar_$i'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(label, style: theme.textTheme.bodySmall),
            value: _standarDicek[i],
            onChanged: (v) => setState(() => _standarDicek[i] = v ?? false),
          ),
      ],
    );
  }

  Widget _blokPenutup(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _catatanCtrl,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calibrated by:', style: theme.textTheme.labelLarge),
                  // Diisi server dari akun teknisi yang ngirim. SENGAJA nggak
                  // baca `authProvider` di sini: nge-`watch` provider itu
                  // mancing pemeriksaan sesi, dan sesi yang lagi bermasalah
                  // bakal ngebuang token di tengah teknisi ngisi lembar.
                  Text(
                    'Name: (otomatis dari akun teknisi)',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text('Sign: —', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Corrected by:', style: theme.textTheme.labelLarge),
                  // Diisi admin waktu memeriksa, bukan teknisi.
                  Text('Name: —', style: theme.textTheme.bodySmall),
                  Text('Sign: —', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Potongan tampilan ----

  /// Panel berjudul — padanan banner biru di kertas.
  Widget _panel(String judul, List<Widget> anak) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              judul,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: anak,
            ),
          ),
        ],
      ),
    );
  }

  /// Satu baris kertas: `Label  :  ______`.
  Widget _baris(String label, Widget isian) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const Text(':  '),
          Expanded(child: isian),
        ],
      ),
    );
  }

  InputDecoration _dekorasi({String? petunjuk, String? akhiran}) =>
      InputDecoration(
        hintText: petunjuk,
        suffixText: akhiran,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: const OutlineInputBorder(),
      );

  Widget _kotakTanggal(
    DateTime? nilai, {
    required VoidCallback onTap,
    String kosong = '—',
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _dekorasi(),
        child: Text(
          nilai == null ? kosong : nilai.toIso8601String().substring(0, 10),
        ),
      ),
    );
  }

  Widget _fieldTeks(
    TextEditingController c, {
    bool barisBanyak = false,
    Key? fieldKey,
  }) {
    return TextField(
      key: fieldKey,
      controller: c,
      minLines: barisBanyak ? 2 : 1,
      maxLines: barisBanyak ? 3 : 1,
      decoration: _dekorasi(),
    );
  }

  Widget _fieldAngka(
    TextEditingController c, {
    String? akhiran,
    bool rapat = false,
    Key? fieldKey,
  }) {
    return TextField(
      key: fieldKey,
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      textAlign: rapat ? TextAlign.center : TextAlign.start,
      style: rapat ? const TextStyle(fontSize: 13) : null,
      decoration: rapat
          ? const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              border: OutlineInputBorder(),
            )
          : _dekorasi(akhiran: akhiran),
    );
  }
}

class _KotakError extends StatelessWidget {
  const _KotakError({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Gagal menghitung: $pesan',
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
