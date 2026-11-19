import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/tanggal_pendek.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer_lookup.dart';
import '../../models/equipment_lookup.dart';
import '../../models/lembar_kerja.dart' show BekalAlatBaru;
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart'
    show equipmentLookupProfilProvider, equipmentLookupServiceProvider;
import '../../providers/equipment_provider.dart'
    show equipmentProvider, equipmentServiceProvider;
import '../../providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import '../../services/auth_service.dart' show AuthException;
import '../../services/buat_alat_dari_kertas.dart';
import '../../services/cocokkan_alat.dart';
import '../../services/identitas_kertas.dart';
import '../calibration/lembar_kerja_state.dart'
    show LembarKerjaState, kuningPerluDicek;
import 'identitas_foto_isian.dart';

/// Blok identitas di atas lembar yang dibuka dari foto: mencocokkan alat dan PT
/// yang TERTULIS di kertas ke yang terdaftar, atau membukakan panel "Alat baru"
/// yang diisi dari kertas. Semua hasil baca adalah SARAN (kuning) dan setiap
/// keputusan butuh ketukan teknisi:
///
///  - cocok persis (nomor seri): "Alat terdaftar: ..." + selisih terhadap kertas,
///    dan "Pakai alat ini";
///  - mirip: "Maksud Anda?" (maks 3 pilihan) atau "alat baru";
///  - tidak ada: panel "Alat baru" (nama, merk, model, seri, pemilik) dengan
///    "Buat dan lanjut". Nomor seri WAJIB (server mewajibkan seri unik per lab);
///    tidak pernah membuat alat tanpa seri;
///  - tidak ada yang terbaca / server tidak terjangkau: pesan jujur, lembar tetap
///    bisa dipakai lewat pilihan alat manual di bawahnya.
///
/// Tidak pernah memilih alat sendiri, tidak pernah menimpa data master alat, dan
/// tidak membuat alat/PT tanpa "Buat dan lanjut" (idempoten: lihat
/// `PembuatAlatDariKertas`). Data master yang tampil hanya dibaca. Hanya token
/// tema; tidak ada warna sendiri selain kuning "perlu dicek" yang sudah dipakai
/// lembar.
class BlokIdentitasFoto extends ConsumerStatefulWidget {
  const BlokIdentitasFoto({
    super.key,
    required this.identitas,
    required this.isian,
    required this.profil,
    required this.bekalAlatBaru,
    required this.onBerubah,
    required this.tinggiMaks,
  });

  final IdentitasKertas identitas;
  final LembarKerjaState isian;

  /// Kode lembar: mencocokkan hanya ke alat berjenis ini.
  final String profil;

  /// Kategori dan jenis alat yang ditentukan LEMBAR (dari server). `null` atau
  /// tanpa kategori = alat tidak bisa dibuat dari sini.
  final BekalAlatBaru? bekalAlatBaru;

  /// Alat atau isian berubah: lembar digambar ulang dan bentuknya ditarik ulang.
  final VoidCallback onBerubah;

  /// Tinggi jatah lembar tempat blok ini duduk (di atas lembar). Kartu pendek
  /// dibatasi setengahnya; panel "Alat baru" (satu langkah keputusan, ada
  /// "Batal") boleh memakai seluruh jatah selama terbuka. Sisanya digulir di
  /// dalam blok; lembar di bawahnya mendapat sisa jatah.
  final double tinggiMaks;

  static const kunci = ValueKey('blok-identitas');
  static const kunciMencocokkan = ValueKey('identitas-mencocokkan');
  static const kunciCocok = ValueKey('identitas-cocok');
  static const kunciPakaiAlat = ValueKey('identitas-pakai-alat');
  static const kunciMirip = ValueKey('identitas-mirip');
  static const kunciMiripBaru = ValueKey('identitas-mirip-baru');
  static const kunciTerpilih = ValueKey('identitas-terpilih');
  static const kunciPanelBaru = ValueKey('identitas-panel-baru');
  static const kunciBuatLanjut = ValueKey('identitas-buat-lanjut');
  static const kunciBatalBaru = ValueKey('identitas-batal-baru');
  static const kunciTidakTerbaca = ValueKey('identitas-tidak-terbaca');
  static const kunciGagalCocok = ValueKey('identitas-gagal-cocok');
  static const kunciUlangCocok = ValueKey('identitas-ulang-cocok');
  static const kunciTutup = ValueKey('identitas-tutup');
  static const kunciGalat = ValueKey('identitas-galat');
  static const kunciPtMirip = ValueKey('identitas-pt-mirip');
  static const kunciPtBaru = ValueKey('identitas-pt-baru');
  static const kunciKategoriKosong = ValueKey('identitas-kategori-kosong');
  static ValueKey<String> kunciPilihMirip(int id) =>
      ValueKey('identitas-pilih-mirip-$id');
  static ValueKey<String> kunciPilihPt(int id) =>
      ValueKey('identitas-pilih-pt-$id');
  static ValueKey<String> kunciBeda(String kode) =>
      ValueKey('identitas-beda-$kode');
  static ValueKey<String> kunciPakaiTerdaftar(String kode) =>
      ValueKey('identitas-pakai-terdaftar-$kode');
  static const kunciTanggalKalibrasi = ValueKey('identitas-tanggal-kalibrasi');
  static const kunciTanggalTerima = ValueKey('identitas-tanggal-terima');
  static const kunciKotakNama = ValueKey('identitas-kotak-nama');
  static const kunciKotakMerk = ValueKey('identitas-kotak-merk');
  static const kunciKotakModel = ValueKey('identitas-kotak-model');
  static const kunciKotakSeri = ValueKey('identitas-kotak-seri');
  static const kunciKotakPemilik = ValueKey('identitas-kotak-pemilik');
  static const kunciKotakAlamat = ValueKey('identitas-kotak-alamat');

  @override
  ConsumerState<BlokIdentitasFoto> createState() => _BlokIdentitasFotoState();
}

enum _Fase {
  mencocokkan,
  cocok,
  mirip,
  baru,
  tidakTerbaca,
  gagalCocok,
  ditutup,
}

class _BlokIdentitasFotoState extends ConsumerState<BlokIdentitasFoto> {
  _Fase _fase = _Fase.mencocokkan;
  EquipmentLookup? _alatCocok;
  List<EquipmentLookup> _mirip = const [];

  /// Seri kertas kosong / tidak terbaca: kotak seri di panel disorot.
  bool _seriKosong = false;

  // ---- panel "Alat baru" ------------------------------------------------------
  late final _nama = TextEditingController();
  late final _merk = TextEditingController();
  late final _model = TextEditingController();
  late final _seri = TextEditingController();
  late final _pemilik = TextEditingController();
  late final _alamat = TextEditingController();

  /// Nilai awal dari KERTAS per kotak: kotak yang masih persis sama tampil
  /// kuning (saran), yang diubah teknisi tidak.
  final _dariKertas = <TextEditingController, String>{};

  bool _membuat = false;
  String? _galat;
  String? _errNama;
  String? _errSeri;
  String? _errPemilik;
  List<CustomerLookup>? _ptKandidat;

  PembuatAlatDariKertas? _pembuat;

  /// Akun yang sedang masuk (`null` = belum diketahui, atau tidak ada) dan
  /// "generasi" akun: naik tiap akun berganti, supaya hasil pencocokan atau
  /// pembuatan milik akun lama yang datang terlambat dibuang.
  int? _idAkun;
  int _generasi = 0;
  bool _selesaiMemuat = false;

  List<TextEditingController> get _semuaKotak => [
    _nama,
    _merk,
    _model,
    _seri,
    _pemilik,
    _alamat,
  ];

  @override
  void initState() {
    super.initState();

    final id = widget.identitas;
    void awal(TextEditingController c, String? kertas, {String? cadangan}) {
      final v = kertas?.trim() ?? '';
      if (v.isNotEmpty) {
        c.text = v;
        _dariKertas[c] = v;
      } else if (cadangan != null) {
        c.text = cadangan;
      }
    }

    awal(
      _nama,
      id.namaAlat,
      // Jenis alat dari lembar: nama yang masuk akal bila kertas tak memuatnya.
      cadangan: widget.bekalAlatBaru?.namaAlatKemampuan,
    );
    awal(_merk, id.merk);
    awal(_model, id.model);
    awal(_seri, id.seri);
    awal(_pemilik, id.pemilik);
    awal(_alamat, id.alamat);
    for (final c in _semuaKotak) {
      c.addListener(_kotakBerubah);
    }

    if (!id.adaIsi) {
      _fase = _Fase.tidakTerbaca;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cocokkan());
    }
  }

  @override
  void dispose() {
    for (final c in _semuaKotak) {
      c
        ..removeListener(_kotakBerubah)
        ..dispose();
    }
    super.dispose();
  }

  void _kotakBerubah() {
    if (mounted) setState(() {});
  }

  /// Ganti akun di tengah lembar: apa pun yang sudah dicocokkan milik akun lama.
  /// Dibuang, dan blok tidak menawarkan apa-apa lagi (lembar tetap bisa dipakai
  /// lewat pilihan alat manual).
  void _periksaAkun(int? id) {
    // Akun baru diketahui (provider auth baru selesai dimuat): bukan pergantian.
    if (_idAkun == null && id != null) {
      _idAkun = id;
      return;
    }
    if (id == _idAkun) return;

    _idAkun = id;
    _generasi++;
    _pembuat = null;
    _alatCocok = null;
    _mirip = const [];
    _ptKandidat = null;
    _fase = _Fase.ditutup;
  }

  // ---- mencocokkan --------------------------------------------------------------

  Future<void> _cocokkan() async {
    if (!mounted) return;
    setState(() => _fase = _Fase.mencocokkan);

    final generasi = _generasi;
    final token = await ref.read(tokenStorageProvider).read();
    if (!mounted || generasi != _generasi) return;
    if (token == null) {
      setState(() => _fase = _Fase.gagalCocok);
      return;
    }

    final hasil = await cocokkanAlat(
      layanan: ref.read(equipmentLookupServiceProvider),
      token: token,
      kertas: widget.identitas,
      profil: widget.profil,
    );
    // Akun berganti selagi menunggu: hasilnya milik akun lama.
    if (!mounted || generasi != _generasi) return;

    setState(() {
      _selesaiMemuat = true;
      switch (hasil) {
        case CocokPersis(:final alat):
          _alatCocok = alat;
          _fase = _Fase.cocok;
        case CocokMirip(:final kandidat):
          _mirip = kandidat;
          _fase = _Fase.mirip;
        case AlatBaru(:final seriKosong):
          _seriKosong = seriKosong;
          _fase = _Fase.baru;
        case CocokGagal():
          _fase = _Fase.gagalCocok;
      }
    });
  }

  /// Teknisi mengonfirmasi alat ini. SATU-SATUNYA tempat alat dipasang dan
  /// identitas master disalin: kotak yang sudah berisi (saran kertas atau ketikan
  /// teknisi) tidak ditimpa, hanya yang kosong diisi dari master.
  void _pakai(EquipmentLookup alat) {
    widget.isian.alat = alat;
    widget.isian.isiDariAlat();
    widget.onBerubah();
  }

  // ---- membuat ------------------------------------------------------------------

  PembuatAlatDariKertas get _pembuatAlat => _pembuat ??= PembuatAlatDariKertas(
    pelanggan: ref.read(customerLookupServiceProvider),
    cariAlat: ref.read(equipmentLookupServiceProvider),
    layananAlat: ref.read(equipmentServiceProvider),
    token: () async {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const AuthException('Sesi berakhir.');

      return token;
    },
  );

  DataAlatBaru? _dataPanel() {
    final l10n = AppLocalizations.of(context);
    final bekal = widget.bekalAlatBaru;
    final kategori = bekal?.kategori;

    setState(() {
      _errNama = _nama.text.trim().isEmpty ? l10n.custFieldRequired : null;
      _errSeri = _seri.text.trim().isEmpty ? l10n.identitasSeriWajib : null;
      _errPemilik = _pemilik.text.trim().isEmpty
          ? l10n.custFieldRequired
          : null;
    });
    if (_errNama != null ||
        _errSeri != null ||
        _errPemilik != null ||
        kategori == null) {
      return null;
    }

    return DataAlatBaru(
      namaAlat: _nama.text.trim(),
      seri: _seri.text.trim(),
      pemilik: _pemilik.text.trim(),
      alamat: _alamat.text.trim(),
      merk: _merk.text.trim(),
      model: _model.text.trim(),
      noIdentifikasi: widget.identitas.idAlat ?? '',
      kategori: kategori,
      namaAlatKemampuan: bekal?.namaAlatKemampuan,
    );
  }

  Future<void> _buatLanjut({
    CustomerLookup? ptDipilih,
    bool tetapBuatPt = false,
  }) async {
    if (_membuat) return;
    final data = _dataPanel();
    if (data == null) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final generasi = _generasi;

    setState(() {
      _membuat = true;
      _galat = null;
    });

    final hasil = await _pembuatAlat.jalankan(
      data,
      ptDipilih: ptDipilih,
      tetapBuatPt: tetapBuatPt,
    );
    if (!mounted || generasi != _generasi) return;

    switch (hasil) {
      case AlatSiap(:final alat, :final sudahAda):
        _selaraskanLembar(data);
        // Daftar alat lembar ini dan daftar Master Alat memuat alat baru.
        ref.invalidate(equipmentLookupProfilProvider(widget.profil));
        ref.invalidate(equipmentProvider);
        _pakai(alat);
        setState(() {
          _membuat = false;
          _ptKandidat = null;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              sudahAda
                  ? l10n.identitasSeriSudahAda(alat.namaAlat)
                  : l10n.lkAlatBaruTersimpan(alat.namaAlat),
            ),
          ),
        );
      case PtPerluDipilih(:final kandidat):
        setState(() {
          _membuat = false;
          _ptKandidat = kandidat;
        });
      case SeriMilikAlatLain(:final alat):
        setState(() {
          _membuat = false;
          _errSeri = l10n.identitasSeriJenisLain(alat.namaAlat);
        });
      case GagalBuatAlat(:final galat):
        setState(() {
          _membuat = false;
          _galat = galat is AuthException
              ? l10n.identitasGagalBuat(galat.message)
              : l10n.identitasGagalUmum;
        });
    }
  }

  /// Nilai yang teknisi tetapkan di panel menjadi nilai lembar: hanya bila kotak
  /// lembar kosong atau masih saran kertas. Yang diketik teknisi di lembar tidak
  /// pernah ditimpa.
  void _selaraskanLembar(DataAlatBaru d) {
    void tulis(String kode, String panel) {
      final isian = widget.isian;
      final nilai = panel.trim();
      if (nilai.isEmpty || isian.teks[kode] == null) return;

      final kini = isian.teks[kode]!.text.trim();
      if (nilai == kini) return;
      if (kini.isNotEmpty && !isian.isianDariFoto.contains(kode)) return;

      isian.tetapkanIdentitasOlehTeknisi(kode, nilai);
    }

    tulis('alat_model', d.model);
    tulis('alat_serial_number', d.seri);
    tulis('alat_merk', d.merk);
    tulis('pemilik_nama', d.pemilik);
    tulis('pemilik_alamat', d.alamat);
  }

  // ---- tampilan -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _periksaAkun(ref.watch(authProvider.select((a) => a.value?.id)));
    final l10n = AppLocalizations.of(context);
    final alat = widget.isian.alat;

    final Widget isi;
    if (alat != null) {
      isi = _KartuTerpilih(
        key: BlokIdentitasFoto.kunciTerpilih,
        alat: alat,
        selisih: [
          for (final s in selisihIdentitas(widget.identitas, alat))
            if (widget.isian.identitasMasihSaran(s.kode, s.kertas)) s,
        ],
        label: _labelKolom,
        onPakaiTerdaftar: (s) {
          widget.isian.tetapkanIdentitasOlehTeknisi(s.kode, s.terdaftar);
          widget.onBerubah();
        },
      );
    } else {
      isi = switch (_fase) {
        _Fase.mencocokkan => _kartu(
          BlokIdentitasFoto.kunciMencocokkan,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.identitasMencocokkan)),
              ],
            ),
          ],
        ),
        _Fase.cocok => _kartuCocok(l10n),
        _Fase.mirip => _kartuMirip(l10n),
        _Fase.baru => _panelBaru(l10n),
        _Fase.tidakTerbaca => _kartuPesan(
          l10n,
          kunci: BlokIdentitasFoto.kunciTidakTerbaca,
          pesan: l10n.identitasTidakTerbaca,
          aksi: _tombolAlatBaru(l10n),
        ),
        _Fase.gagalCocok => _kartuPesan(
          l10n,
          kunci: BlokIdentitasFoto.kunciGagalCocok,
          pesan: l10n.identitasGagalCocok,
          aksi: TextButton.icon(
            key: BlokIdentitasFoto.kunciUlangCocok,
            onPressed: _cocokkan,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.dashRetry),
          ),
        ),
        _Fase.ditutup => const SizedBox.shrink(),
      };
    }

    // Digulirkan di dalam jatahnya sendiri: lembar di bawahnya tidak boleh
    // terdesak habis oleh panel yang tinggi (HP 320 dp, huruf besar, papan ketik
    // terbuka). Tingginya dibatasi [BlokIdentitasFoto.tinggiMaks].
    final panel = alat == null && _fase == _Fase.baru;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.tinggiMaks * (panel ? 1.0 : 0.5),
      ),
      child: SingleChildScrollView(
        key: BlokIdentitasFoto.kunci,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isi is! SizedBox) isi,
            if (_fase != _Fase.ditutup || alat != null) ..._barisTanggal(l10n),
          ],
        ),
      ),
    );
  }

  String _labelKolom(String kode) {
    final l10n = AppLocalizations.of(context);

    return switch (kode) {
      'alat_merk' => l10n.equipMerk,
      'alat_model' => l10n.equipModel,
      'alat_serial_number' => l10n.equipSerialNumber,
      'pemilik_nama' => l10n.equipPelanggan,
      'pemilik_alamat' => l10n.identitasAlamat,
      _ => widget.isian.labelFieldIsian(kode) ?? kode,
    };
  }

  // Satu kartu: tepi tipis, tanpa warna sendiri.
  Widget _kartu(Key kunci, {required List<Widget> children, Widget? tutup}) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Container(
        key: kunci,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          border: Border.all(color: tema.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
            ?tutup,
          ],
        ),
      ),
    );
  }

  Widget _tombolTutup(AppLocalizations l10n) => IconButton(
    key: BlokIdentitasFoto.kunciTutup,
    tooltip: l10n.identitasTutup,
    onPressed: () => setState(() => _fase = _Fase.ditutup),
    icon: const Icon(Icons.close, size: 18),
  );

  Widget _kartuPesan(
    AppLocalizations l10n, {
    required Key kunci,
    required String pesan,
    required Widget aksi,
  }) => _kartu(
    kunci,
    tutup: _tombolTutup(l10n),
    children: [
      Text(pesan, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: AppSpacing.xs),
      Align(alignment: Alignment.centerLeft, child: aksi),
    ],
  );

  Widget _tombolAlatBaru(AppLocalizations l10n) => TextButton.icon(
    onPressed: () => setState(() => _fase = _Fase.baru),
    icon: const Icon(Icons.add, size: 18),
    label: Text(l10n.lkAlatBaru),
  );

  String _ringkasAlat(EquipmentLookup a) => [
    a.namaAlat,
    if (a.serialNumber.isNotEmpty) a.serialNumber,
    if (a.pelangganNama.isNotEmpty) a.pelangganNama,
  ].join(' · ');

  Widget _kartuCocok(AppLocalizations l10n) {
    final alat = _alatCocok!;
    final tema = Theme.of(context);
    final selisih = selisihIdentitas(widget.identitas, alat);

    return _kartu(
      BlokIdentitasFoto.kunciCocok,
      tutup: _tombolTutup(l10n),
      children: [
        Text(
          l10n.identitasAlatTerdaftar(alat.namaAlat),
          style: tema.textTheme.titleSmall,
        ),
        Text(_ringkasAlat(alat), style: tema.textTheme.bodySmall),
        ..._barisSelisih(l10n, selisih, tombol: false),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: BlokIdentitasFoto.kunciPakaiAlat,
            onPressed: () => _pakai(alat),
            icon: const Icon(Icons.check, size: 18),
            label: Text(l10n.identitasPakaiAlat),
          ),
        ),
      ],
    );
  }

  List<Widget> _barisSelisih(
    AppLocalizations l10n,
    List<SelisihIdentitas> selisih, {
    required bool tombol,
    void Function(SelisihIdentitas s)? onPakai,
  }) {
    if (selisih.isEmpty) return const [];

    return [
      const SizedBox(height: AppSpacing.xs),
      for (final s in selisih)
        Padding(
          key: BlokIdentitasFoto.kunciBeda(s.kode),
          padding: const EdgeInsets.only(top: 2),
          child: _BarisBeda(
            teks: l10n.identitasBedaBaris(
              _labelKolom(s.kode),
              s.kertas,
              s.terdaftar,
            ),
            tombol: tombol
                ? TextButton(
                    key: BlokIdentitasFoto.kunciPakaiTerdaftar(s.kode),
                    onPressed: () => onPakai?.call(s),
                    child: Text(l10n.identitasPakaiTerdaftar),
                  )
                : null,
          ),
        ),
    ];
  }

  Widget _kartuMirip(AppLocalizations l10n) {
    final tema = Theme.of(context);

    return _kartu(
      BlokIdentitasFoto.kunciMirip,
      tutup: _tombolTutup(l10n),
      children: [
        Text(l10n.identitasMaksudAnda, style: tema.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final a in _mirip)
              ActionChip(
                key: BlokIdentitasFoto.kunciPilihMirip(a.id),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    _ringkasAlat(a),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                onPressed: () => _pakai(a),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: BlokIdentitasFoto.kunciMiripBaru,
            onPressed: () => setState(() => _fase = _Fase.baru),
            child: Text(l10n.identitasBukanSatuPun),
          ),
        ),
      ],
    );
  }

  // ---- panel "Alat baru" -------------------------------------------------------

  Widget _kotak(
    Key kunci,
    TextEditingController c,
    String label, {
    String? galat,
    bool wajib = false,
    int maxBaris = 1,
  }) {
    final dariKertas =
        _dariKertas[c] != null && c.text.trim() == _dariKertas[c];
    final tema = Theme.of(context);

    return TextField(
      key: kunci,
      controller: c,
      enabled: !_membuat,
      minLines: 1,
      maxLines: maxBaris,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        isDense: true,
        labelText: wajib ? '$label *' : label,
        errorText: galat,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
        filled: dariKertas,
        // Saran dari kertas: kuning, sama dengan isian "perlu dicek" di lembar.
        fillColor: dariKertas ? kuningPerluDicek.withValues(alpha: 0.16) : null,
        enabledBorder: dariKertas
            ? OutlineInputBorder(
                borderSide: const BorderSide(color: kuningPerluDicek),
              )
            : null,
        labelStyle: tema.textTheme.bodyMedium,
      ),
    );
  }

  Widget _panelBaru(AppLocalizations l10n) {
    final tema = Theme.of(context);
    final bekal = widget.bekalAlatBaru;

    // Lembar ini belum punya jenis alat terdaftar di master (kategori kosong):
    // alat tidak bisa dibuat dari sini; form Alat baru di bawah yang menanyakan
    // kategorinya.
    if (bekal?.kategori == null) {
      return _kartuPesan(
        l10n,
        kunci: BlokIdentitasFoto.kunciKategoriKosong,
        pesan: l10n.lkAlatKosongAjakan,
        aksi: const SizedBox.shrink(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Container(
        key: BlokIdentitasFoto.kunciPanelBaru,
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          border: Border.all(color: tema.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.lkAlatBaru,
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                _tombolTutup(l10n),
              ],
            ),
            Text(
              l10n.identitasAlatBaruPetunjuk,
              style: tema.textTheme.bodySmall,
            ),
            Text(
              l10n.identitasJenisAlat(bekal!.namaAlatKemampuan),
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _kotak(
              BlokIdentitasFoto.kunciKotakNama,
              _nama,
              l10n.equipNamaAlat,
              galat: _errNama,
              wajib: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _kotak(BlokIdentitasFoto.kunciKotakMerk, _merk, l10n.equipMerk),
            const SizedBox(height: AppSpacing.sm),
            _kotak(BlokIdentitasFoto.kunciKotakModel, _model, l10n.equipModel),
            const SizedBox(height: AppSpacing.sm),
            _kotak(
              BlokIdentitasFoto.kunciKotakSeri,
              _seri,
              l10n.equipSerialNumber,
              galat:
                  _errSeri ??
                  (_seriKosong && _seri.text.trim().isEmpty
                      ? l10n.identitasSeriWajib
                      : null),
              wajib: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _kotak(
              BlokIdentitasFoto.kunciKotakPemilik,
              _pemilik,
              l10n.equipPelanggan,
              galat: _errPemilik,
              wajib: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _kotak(
              BlokIdentitasFoto.kunciKotakAlamat,
              _alamat,
              l10n.identitasAlamat,
              maxBaris: 3,
            ),
            if (_ptKandidat case final kandidat?) ...[
              const SizedBox(height: AppSpacing.sm),
              _PanelPtMirip(
                kandidat: kandidat,
                sibuk: _membuat,
                onPilih: (c) => _buatLanjut(ptDipilih: c),
                onTetapBuat: () => _buatLanjut(tetapBuatPt: true),
              ),
            ],
            if (_galat case final g?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                g,
                key: BlokIdentitasFoto.kunciGalat,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.identitasLengkapiNanti, style: tema.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton(
                  key: BlokIdentitasFoto.kunciBatalBaru,
                  onPressed: _membuat
                      ? null
                      : () => setState(() {
                          _fase = _selesaiMemuat && _mirip.isNotEmpty
                              ? _Fase.mirip
                              : _Fase.ditutup;
                        }),
                  child: Text(l10n.identitasBatal),
                ),
                FilledButton(
                  key: BlokIdentitasFoto.kunciBuatLanjut,
                  onPressed: _membuat ? null : () => _buatLanjut(),
                  child: _membuat
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(l10n.identitasSedangMembuat),
                          ],
                        )
                      : Text(l10n.identitasBuatLanjut),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- tanggal dari kertas -----------------------------------------------------

  /// Tanggal yang tertulis di kertas dan BEDA dari yang ada di lembar: saran
  /// yang dipakai dengan satu ketukan. Tidak diterapkan diam-diam (tanggal
  /// kalibrasi bawaan = hari ini).
  List<Widget> _barisTanggal(AppLocalizations l10n) {
    final id = widget.identitas;
    final isian = widget.isian;

    bool sama(DateTime? a, DateTime b) =>
        a != null && a.year == b.year && a.month == b.month && a.day == b.day;

    final baris = <Widget>[];

    void tambah(
      Key kunci,
      String kode,
      DateTime? kertas,
      String Function(String) teks,
    ) {
      if (kertas == null) return;
      // Lembar ini tidak punya kolom tanggal itu.
      if (kode != 'tanggal_kalibrasi' && isian.labelFieldIsian(kode) == null) {
        return;
      }
      if (sama(isian.tanggal[kode], kertas)) return;

      baris.add(
        Padding(
          key: kunci,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: kuningPerluDicek.withValues(alpha: 0.14),
              border: Border.all(color: kuningPerluDicek),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: kuningPerluDicek,
                ),
                Text(teks(tanggalPendek(context, kertas))),
                OutlinedButton(
                  onPressed: () {
                    isian.tanggal[kode] = kertas;
                    widget.onBerubah();
                  },
                  child: Text(l10n.identitasPakaiTanggal),
                ),
              ],
            ),
          ),
        ),
      );
    }

    tambah(
      BlokIdentitasFoto.kunciTanggalKalibrasi,
      'tanggal_kalibrasi',
      id.tanggalKalibrasi,
      l10n.identitasTanggalKalibrasi,
    );
    tambah(
      BlokIdentitasFoto.kunciTanggalTerima,
      'tanggal_terima',
      id.tanggalTerima,
      l10n.identitasTanggalTerima,
    );

    return baris;
  }
}

/// Satu selisih kertas lawan data terdaftar: ikon kuning + kalimat, dan
/// (opsional) tombol "Pakai yang terdaftar".
class _BarisBeda extends StatelessWidget {
  const _BarisBeda({required this.teks, this.tombol});

  final String teks;
  final Widget? tombol;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: kuningPerluDicek,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(teks, style: tema.textTheme.bodySmall),
              ?tombol,
            ],
          ),
        ),
      ],
    );
  }
}

/// Alat yang dipakai lembar ini (dipilih lewat blok ini atau lewat pilihan alat
/// manual), dengan selisih terhadap kertas yang masih berlaku.
class _KartuTerpilih extends StatelessWidget {
  const _KartuTerpilih({
    super.key,
    required this.alat,
    required this.selisih,
    required this.label,
    required this.onPakaiTerdaftar,
  });

  final EquipmentLookup alat;
  final List<SelisihIdentitas> selisih;
  final String Function(String kode) label;
  final void Function(SelisihIdentitas s) onPakaiTerdaftar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          border: Border.all(color: tema.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.identitasAlatTerdaftar(
                      [
                        alat.namaAlat,
                        if (alat.serialNumber.isNotEmpty) alat.serialNumber,
                      ].join(' · '),
                    ),
                    style: tema.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (selisih.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              for (final s in selisih)
                Padding(
                  key: BlokIdentitasFoto.kunciBeda(s.kode),
                  padding: const EdgeInsets.only(top: 2),
                  child: _BarisBeda(
                    teks: l10n.identitasBedaBaris(
                      label(s.kode),
                      s.kertas,
                      s.terdaftar,
                    ),
                    tombol: TextButton(
                      key: BlokIdentitasFoto.kunciPakaiTerdaftar(s.kode),
                      onPressed: () => onPakaiTerdaftar(s),
                      child: Text(l10n.identitasPakaiTerdaftar),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// PT yang MIRIP: pilih yang sudah ada, atau tegaskan ini PT lain.
class _PanelPtMirip extends StatelessWidget {
  const _PanelPtMirip({
    required this.kandidat,
    required this.sibuk,
    required this.onPilih,
    required this.onTetapBuat,
  });

  final List<CustomerLookup> kandidat;
  final bool sibuk;
  final void Function(CustomerLookup c) onPilih;
  final VoidCallback onTetapBuat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    return Container(
      key: BlokIdentitasFoto.kunciPtMirip,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: kuningPerluDicek.withValues(alpha: 0.14),
        border: Border.all(color: kuningPerluDicek),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.identitasPtMirip, style: tema.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final c in kandidat)
                ActionChip(
                  key: BlokIdentitasFoto.kunciPilihPt(c.id),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      [
                        c.nama,
                        if ((c.alamat ?? '').isNotEmpty) c.alamat!,
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  onPressed: sibuk ? null : () => onPilih(c),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: BlokIdentitasFoto.kunciPtBaru,
              onPressed: sibuk ? null : onTetapBuat,
              child: Text(l10n.identitasPtBaru),
            ),
          ),
        ],
      ),
    );
  }
}
