import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_draft.dart';
import '../../models/category.dart';
import '../../models/equipment_lookup.dart';
import '../../models/standard.dart';
import '../../models/skema_dokumen.dart';
import '../../providers/calibration_input_provider.dart';
import '../../services/ambil_foto_tabel.dart';
import '../../services/analisis_dokumen.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/sidik_loader.dart';
import 'peta_kolom_screen.dart';
import 'skema_dinamis_screen.dart';

/// Form input kalibrasi — kategori → alat → standar acuan, lalu titik ukur
/// (target + pembacaan berulang) yang dinamis. Nggak nyoba nyaingin worksheet
/// penuh (CMC per kategori, validasi rentang): mobile kirim data mentah,
/// **backend yang ngitung GUM & keputusan PASS/FAIL** — sesuai
/// `docs/kontrak-api.md` §4.
class CalibrationInputScreen extends ConsumerWidget {
  const CalibrationInputScreen({super.key, this.kategoriAwal});

  /// Kode kategori yang udah dipilih dari [CategoryPickerScreen] /
  /// [InstrumentPickerScreen] — kalau ada, dropdown Kategori di bawah
  /// langsung ke-pre-fill (teknisi nggak milih ulang apa yang udah dia
  /// pilih di layar sebelumnya). Null kalau dibuka langsung (jalur lama).
  final String? kategoriAwal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriAsync = ref.watch(categoryListProvider);
    final standarAsync = ref.watch(standardListProvider);
    final l10n = AppLocalizations.of(context);

    final kategori = kategoriAsync.value;
    final standar = standarAsync.value;

    final Widget isi;
    if (kategori != null && standar != null) {
      isi = _Form(kategoriList: kategori, standarList: standar, kategoriAwal: kategoriAwal);
    } else if (kategoriAsync.hasError || standarAsync.hasError) {
      isi = _Gagal(
        onCobaLagi: () {
          ref.invalidate(categoryListProvider);
          ref.invalidate(standardListProvider);
        },
      );
    } else {
      isi = const Center(child: SidikLoader(size: 88));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibTitle)),
      body: isi,
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.calibLoadPilihanGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.calibRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Titik {
  _Titik() : nilaiTarget = TextEditingController(), satuan = TextEditingController();

  final TextEditingController nilaiTarget;
  final TextEditingController satuan;
  final List<TextEditingController> pembacaan = [
    TextEditingController(),
    TextEditingController(),
  ];

  /// Isi pembacaan dari kertas, menumbuhkan kotaknya kalau pengulangannya
  /// lebih banyak dari dua bawaan.
  ///
  /// Yang lebih dari kotak yang ada NGGAK boleh dibuang: pengulangan ke-5 yang
  /// hilang bikin sebaran Type A dihitung dari empat angka padahal kertasnya
  /// punya lima, dan hasilnya beda tanpa ada yang kelihatan salah.
  void isiPembacaan(List<String> nilai) {
    while (pembacaan.length < nilai.length) {
      pembacaan.add(TextEditingController());
    }
    for (var i = 0; i < nilai.length; i++) {
      pembacaan[i].text = nilai[i];
    }
  }

  void dispose() {
    nilaiTarget.dispose();
    satuan.dispose();
    for (final c in pembacaan) {
      c.dispose();
    }
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.kategoriList, required this.standarList, this.kategoriAwal});

  final List<Category> kategoriList;
  final List<Standard> standarList;
  final String? kategoriAwal;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  String? _kategori;
  EquipmentLookup? _alat;
  Standard? _standar;
  DateTime _tanggal = DateTime.now();
  LokasiKalibrasi _lokasi = LokasiKalibrasi.lab;
  final _suhuRuang = TextEditingController(text: '23.5');
  final _kelembaban = TextEditingController(text: '55');
  final List<_Titik> _titikList = [_Titik()];

  @override
  void initState() {
    super.initState();
    _kategori = widget.kategoriAwal;
  }

  /// Di-generate SEKALI waktu layar dibuka — lihat komentar yang sama di
  /// `ph_calibration_input_screen.dart`.
  final _clientRequestId = generateUuidV4();

  bool _mengirim = false;

  @override
  void dispose() {
    _suhuRuang.dispose();
    _kelembaban.dispose();
    for (final t in _titikList) {
      t.dispose();
    }
    super.dispose();
  }

  void _tambahTitik() => setState(() => _titikList.add(_Titik()));

  void _hapusTitik(int index) {
    if (_titikList.length <= 1) return;
    setState(() {
      _titikList.removeAt(index).dispose();
    });
  }

  void _tambahPembacaan(_Titik titik) =>
      setState(() => titik.pembacaan.add(TextEditingController()));

  bool _membaca = false;

  /// Foto lembar yang **belum dikenal aplikasi** → titik ukur terisi.
  ///
  /// ## Kenapa jalurnya mendarat di sini
  ///
  /// Layar ini yang dibuka waktu alatnya nggak punya profil lembar kerja
  /// (`InstrumentPickerScreen` menjatuhkannya ke sini persis di cabang
  /// `profil == null`). Jadi teknisi yang berdiri di layar ini adalah teknisi
  /// yang memegang kertas yang aplikasinya nggak punya bentuknya — populasi
  /// yang sama persis dengan yang dilayani jalur generik. Sebelum ini, satu-
  /// satunya pilihannya mengetik ulang seluruh tabel dari kertas.
  ///
  /// ## Rantainya, dan di mana manusia masuk
  ///
  ///   kamera → OCR di perangkat → `AnalisisDokumen` (baris → pasangan &
  ///   tabel) → `PembuatSkema` → **teknisi mengoreksi bacaannya** →
  ///   **teknisi menetapkan arti kolom** → titik ukur terisi → backend hitung
  ///
  /// Dua langkah manusia itu nggak boleh dihapus buat "mempercepat". Yang
  /// pertama karena OCR tulisan tangan nggak pernah dianggap pasti di repo ini;
  /// yang kedua karena arti kolom mustahil ditebak tanpa menanam daftar ejaan
  /// kepala kolom — dan menebaknya terbalik bikin koreksi di sertifikat kebalik
  /// tandanya.
  ///
  /// Yang mendarat di form tetap **bacaan mentah**. Perhitungan GUM,
  /// ketidakpastian, dan keputusan PASS/FAIL tetap punya backend dengan profil
  /// alat yang sah — jalur ini nggak bisa menerbitkan sertifikat lewat pintu
  /// belakang.
  Future<void> _bacaDariFoto() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _membaca = true);

    try {
      final foto = await ambilDanBacaTabel(ref);
      if (!mounted || foto.dibatalkan) return;

      if (foto.terbaca == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.calibBacaFotoGagal)),
        );
        return;
      }

      final dibaca = const AnalisisDokumen().bacaDokumen(foto.terbaca!);
      final skema = const PembuatSkema().susun(
        pasangan: dibaca.pasangan,
        tabel: dibaca.tabel,
      );

      // Layar review-nya dibuka SEKALIPUN tabelnya nggak ketemu. Teknisi
      // berhak lihat apa yang sebenarnya kebaca dari kertasnya sebelum
      // disuruh jepret ulang — pesan "nggak ada tabel" tanpa buktinya bikin
      // dia mengulang jepretan yang sama.
      final dikoreksi = await navigator.push<SkemaDokumen>(
        MaterialPageRoute(builder: (_) => SkemaDinamisScreen(skema: skema)),
      );

      if (!mounted || dikoreksi == null) return;

      if (dikoreksi.tabel.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(l10n.calibBacaFotoTanpaTabel),
          ),
        );
        return;
      }

      final tabel = await _pilihTabel(dikoreksi.tabel, l10n);
      if (!mounted || tabel == null) return;

      final peta = await navigator.push<PetaKolomTerpakai>(
        MaterialPageRoute(builder: (_) => PetaKolomScreen(tabel: tabel)),
      );

      if (!mounted || peta == null || peta.titik.isEmpty) return;

      _isiTitik(peta);

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.calibBacaFotoSelesai(peta.titik.length))),
      );
    } finally {
      if (mounted) setState(() => _membaca = false);
    }
  }

  /// Dokumen boleh punya beberapa tabel; yang milih teknisi, bukan urutan.
  ///
  /// Diambil yang pertama diam-diam, lembar yang tabel identitasnya kebaca
  /// duluan bakal dipetakan sebagai titik ukur — dan yang salah nggak
  /// kelihatan sampai angkanya sudah masuk.
  ///
  /// Judulnya punya kunci SENDIRI, bukan menumpang judul layar peta kolom.
  /// Dua pertanyaan ini beda dan berurutan: yang di sini "tabel yang mana",
  /// yang di sana "kolomnya berarti apa". Menumpang, teknisi membaca
  /// "Kolom mana artinya apa" di atas dialog yang isinya cuma daftar tabel —
  /// pertanyaan yang belum ditanyakan, di layar yang belum sampai ke situ.
  Future<TabelSkema?> _pilihTabel(
    List<TabelSkema> tabel,
    AppLocalizations l10n,
  ) async {
    if (tabel.length == 1) return tabel.single;

    return showDialog<TabelSkema>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.pilihTabelJudul),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              l10n.pilihTabelPengantar,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (var i = 0; i < tabel.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(tabel[i]),
              child: Text(
                tabel[i].kepala.isEmpty
                    ? l10n.skemaDinamisTabel(i + 1)
                    : tabel[i].kepala.where((k) => k.trim().isNotEmpty).join(' · '),
              ),
            ),
        ],
      ),
    );
  }

  /// Ganti isi form dengan titik yang dipetakan dari kertas.
  ///
  /// MENGGANTI, bukan menambah: yang ada sebelumnya baris kosong bawaan layar,
  /// dan menyisakannya bikin submit ditolak karena ada titik tanpa nilai —
  /// dengan pesan yang nunjuk ke isian kosong, bukan ke fotonya.
  void _isiTitik(PetaKolomTerpakai peta) {
    setState(() {
      for (final t in _titikList) {
        t.dispose();
      }
      _titikList
        ..clear()
        ..addAll([
          for (final d in peta.titik)
            _Titik()
              ..nilaiTarget.text = d.nilaiAcuan
              ..satuan.text = peta.satuan
              ..isiPembacaan(d.pembacaan),
        ]);
    });
  }

  double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _submit({required bool draft}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_kategori == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiKategori)));
      return;
    }
    if (_alat == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiAlat)));
      return;
    }
    if (_standar == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiStandar)));
      return;
    }

    // Mulai dari sini penjagaannya BERSYARAT — dan `draft` yang jadi syaratnya.
    //
    // Sebelum ini seluruh blok di bawah berjalan tanpa syarat, dan `draft` baru
    // dibaca jauh di bawah waktu menyusun `CalibrationDraft`. Artinya tombol
    // "Simpan Draft" menuntut lembar yang LENGKAP — persis yang tidak
    // dijanjikannya. Teknisi yang baru mengukur sebagian titik (baterai
    // menipis, alat pelanggan belum siap) cuma punya dua pilihan: tunggu
    // sampai lengkap, atau kehilangan seluruh isian.
    //
    // Layar lembar kerja utama sudah benar sejak awal — `lembar_kerja_screen`
    // membungkus penjagaannya dengan `if (!draft)` dan menulis alasannya di
    // tempat: *"Draft tetap boleh disimpan setengah jadi."* Model ini juga
    // sudah menyatakan niat yang sama: `simpanSebagaiDraft` didokumentasikan
    // sebagai *"simpan dulu, lanjut nanti"*.
    //
    // Backend pun sudah siap: `suhu_ruang`/`kelembaban` `nullable`,
    // `measurements` `sometimes`, `pembacaan` `nullable`. Jadi yang bolong cuma
    // layar ini.
    //
    // Tiga penjagaan di atas TIDAK ikut dilonggarkan. Kategori, alat dan
    // standar bukan "kolom wajib" — tanpa ketiganya tidak ada yang bisa
    // dikirim sama sekali, dan `CalibrationDraft` sendiri menuntutnya
    // non-null. Sama seperti alat di lembar kerja utama.
    final suhu = _parse(_suhuRuang.text);
    final lembab = _parse(_kelembaban.text);
    if (!draft && (suhu == null || lembab == null)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiAngka)));
      return;
    }

    final measurements = <MeasurementPoint>[];

    // Baris yang tidak bisa ikut tersimpan — dihitung, bukan didiamkan. Lihat
    // di bawah loop.
    var titikTanpaAcuan = 0;

    for (final titik in _titikList) {
      final target = _parse(titik.nilaiTarget.text);
      final satuan = titik.satuan.text.trim();

      final pembacaan = <double>[];
      for (final c in titik.pembacaan) {
        final nilai = _parse(c.text);
        if (nilai != null) pembacaan.add(nilai);
      }

      if (!draft) {
        if (target == null || satuan.isEmpty) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.calibValidasiAngka)));
          return;
        }
        if (pembacaan.length < 2) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.calibValidasiPembacaan)),
          );
          return;
        }
      }

      // Satu hal yang TIDAK bisa dilonggarkan walau ini draft:
      // `measurements.*.titik_ukur` `required` di backend, jadi baris tanpa
      // nilai acuan bakal ditolak seluruh request-nya — bukan cuma barisnya.
      // Jadi barisnya dilewat di sini.
      //
      // Waktu `draft` false, cabang ini tidak pernah kena: penjagaan di atas
      // sudah memulangkan lebih dulu.
      if (target == null) {
        // Dihitung CUMA kalau memang ada yang hilang. Baris yang kosong
        // melompong tidak kehilangan apa pun, dan melaporkannya bikin
        // peringatan yang isinya tidak benar — dan peringatan palsu melatih
        // orang mengabaikan yang asli.
        if (satuan.isNotEmpty || pembacaan.isNotEmpty) titikTanpaAcuan++;
        continue;
      }

      measurements.add(
        MeasurementPoint(
          titikUkur: target,
          satuan: satuan,
          pembacaan: pembacaan,
        ),
      );
    }

    setState(() => _mengirim = true);

    final hasil = await ref.read(calibrationSubmitProvider.notifier).submit(
      CalibrationDraft(
        equipmentId: _alat!.id,
        kategori: _kategori!,
        standardId: _standar!.id,
        tanggalKalibrasi: _tanggal,
        suhuRuang: suhu,
        kelembaban: lembab,
        lokasi: _lokasi,
        clientRequestId: _clientRequestId,
        measurements: measurements,
        simpanSebagaiDraft: draft,
      ),
    );

    if (!mounted) return;
    setState(() => _mengirim = false);

    if (hasil != null) {
      // Baris yang dilewat HARUS diomongin — draft yang balik dengan tabel
      // bolong tanpa ada yang bilang itu persis cara sesi kekirim ke admin
      // dengan titik yang ilang diam-diam. Aturan yang sama sudah dipegang
      // penjaga `kebuang` di `lembar_kerja_screen`, berikut durasi 8 detiknya:
      // pesan yang lewat dalam empat detik sama saja dengan tidak ada.
      //
      // Digabung ke pesan sukses, bukan ditampilkan sebelumnya: SnackBar
      // berikutnya menggusur yang sedang tampil, jadi peringatan yang
      // ditampilkan lebih dulu justru yang paling mungkin tidak terbaca.
      final adaYangDilewat = draft && titikTanpaAcuan > 0;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            adaYangDilewat
                ? l10n.calibDraftTitikDilewat(titikTanpaAcuan)
                : (draft ? l10n.calibBerhasilDraft : l10n.calibBerhasilApproval),
          ),
          duration: Duration(seconds: adaYangDilewat ? 8 : 4),
        ),
      );
      Navigator.of(context).pop();
    } else {
      final error = ref.read(calibrationSubmitProvider).error;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.calibGagal(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final equipmentAsync = ref.watch(equipmentLookupProvider(_kategori));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.calibKategori.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: _kategori,
          isExpanded: true,
          hint: Text(l10n.calibKategoriHint),
          items: widget.kategoriList
              .map((k) => DropdownMenuItem(value: k.kode, child: Text(k.nama)))
              .toList(),
          onChanged: (value) => setState(() {
            _kategori = value;
            _alat = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(l10n.calibAlat.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        equipmentAsync.when(
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(l10n.calibAlatKosong),
          data: (list) => DropdownButtonFormField<EquipmentLookup>(
            initialValue: _alat,
            isExpanded: true,
            hint: Text(list.isEmpty ? l10n.calibAlatKosong : l10n.calibAlatHint),
            items: list
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text('${e.namaAlat} · ${e.serialNumber}'),
                  ),
                )
                .toList(),
            onChanged: list.isEmpty ? null : (value) => setState(() => _alat = value),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(l10n.calibStandar.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<Standard>(
          initialValue: _standar,
          isExpanded: true,
          hint: Text(l10n.calibStandarHint),
          items: widget.standarList
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  enabled: s.masihBerlaku,
                  child: Text(
                    s.masihBerlaku ? s.nama : '${s.nama} (${l10n.calibStandarKadaluarsa})',
                    style: s.masihBerlaku
                        ? null
                        : TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _standar = value),
        ),
        const SizedBox(height: AppSpacing.md),

        InkWell(
          onTap: () async {
            final dipilih = await showDatePicker(
              context: context,
              initialDate: _tanggal,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (dipilih != null) setState(() => _tanggal = dipilih);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.calibTanggal.toUpperCase(),
              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            child: Text(
              '${_tanggal.day}/${_tanggal.month}/${_tanggal.year}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(l10n.calibLokasi.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<LokasiKalibrasi>(
          initialValue: _lokasi,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: LokasiKalibrasi.lab, child: Text(l10n.calibLokasiLab)),
            DropdownMenuItem(
              value: LokasiKalibrasi.onsite,
              child: Text(l10n.calibLokasiOnsite),
            ),
          ],
          onChanged: (value) => setState(() => _lokasi = value!),
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: AppTextField.measurement(
                label: l10n.calibSuhuRuang,
                controller: _suhuRuang,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField.measurement(
                label: l10n.calibKelembaban,
                controller: _kelembaban,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        AppButton(
          label: l10n.calibBacaFoto,
          icon: Icons.document_scanner_outlined,
          variant: AppButtonVariant.secondary,
          isLoading: _membaca,
          onPressed: _membaca ? null : _bacaDariFoto,
        ),
        const SizedBox(height: AppSpacing.md),

        for (var i = 0; i < _titikList.length; i++) ...[
          _TitikCard(
            index: i,
            titik: _titikList[i],
            bisaHapus: _titikList.length > 1,
            onHapus: () => _hapusTitik(i),
            onTambahPembacaan: () => _tambahPembacaan(_titikList[i]),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: l10n.calibTambahTitik,
          icon: Icons.add,
          variant: AppButtonVariant.secondary,
          onPressed: _tambahTitik,
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: l10n.calibKirimApproval,
          isLoading: _mengirim,
          onPressed: _mengirim ? null : () => _submit(draft: false),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.calibSimpanDraft,
          variant: AppButtonVariant.secondary,
          isLoading: _mengirim,
          onPressed: _mengirim ? null : () => _submit(draft: true),
        ),
      ],
    );
  }
}

class _TitikCard extends StatelessWidget {
  const _TitikCard({
    required this.index,
    required this.titik,
    required this.bisaHapus,
    required this.onHapus,
    required this.onTambahPembacaan,
  });

  final int index;
  final _Titik titik;
  final bool bisaHapus;
  final VoidCallback onHapus;
  final VoidCallback onTambahPembacaan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.calibTitikUkur(index + 1),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (bisaHapus)
                  IconButton(
                    tooltip: l10n.calibHapusTitik,
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: onHapus,
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: AppTextField.measurement(
                    label: l10n.calibNilaiTarget,
                    controller: titik.nilaiTarget,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: l10n.calibSatuan,
                    controller: titik.satuan,
                    hint: 'mm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < titik.pembacaan.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppTextField.measurement(
                  label: l10n.calibPembacaan(i + 1),
                  controller: titik.pembacaan[i],
                ),
              ),
            ],
            TextButton(
              onPressed: onTambahPembacaan,
              child: Text(l10n.calibTambahPembacaan),
            ),
          ],
        ),
      ),
    );
  }
}
