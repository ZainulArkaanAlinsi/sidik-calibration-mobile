import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/data_acuan/alur_versi_acuan_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart';

import '../../data/pemilih_berkas.dart';
import '../../data/workbook_model.dart';
import '../../data/workbook_provider.dart';
import '../../inti/sesi_studio.dart';
import '../../l10n/studio_l10n.dart';
import '../../tema/tema_studio.dart';
import '../../tema/warna_studio.dart';

/// Buka layar "Unggah master" di navigator akar (pola [bukaWorkbook]).
void bukaUnggahMaster(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const UnggahMasterScreen()));
}

/// Unggah master `.xlsm/.xlsx/.csv` -> `POST /studio/workbook/impor`
/// (K-50-12). Sandi berkas hanya hidup di isian ini: dikirim sekali, dikosongkan
/// begitu unggahan selesai (berhasil atau tidak), tidak masuk provider mana pun.
/// Server yang menegakkan izin (ability `studio`); layar ini tidak menyaring
/// peran.
class UnggahMasterScreen extends ConsumerStatefulWidget {
  const UnggahMasterScreen({super.key});

  @override
  ConsumerState<UnggahMasterScreen> createState() => _UnggahMasterScreenState();
}

class _UnggahMasterScreenState extends ConsumerState<UnggahMasterScreen> {
  final _sandi = TextEditingController();
  final _alasan = TextEditingController();
  BerkasDipilih? _berkas;
  int? _gantikan;
  bool _sibuk = false;
  bool _sandiTerlihat = false;
  String? _galatBerkas;
  String? _galatAlasan;
  String? _galatSandi;
  String? _galatUmum;
  String? _sukses;
  HasilUnggahMaster? _hasil;
  ({String kepala, List<String> butir})? _galatStruktur;
  late final int? _akun;

  @override
  void initState() {
    super.initState();
    _akun = ref.read(authProvider).value?.id;
  }

  @override
  void dispose() {
    _sandi.dispose();
    _alasan.dispose();
    super.dispose();
  }

  Future<void> _pilih() async {
    final l10n = StudioL10n.of(context);
    final b = await ref.read(pemilihBerkasMasterProvider)();
    if (b == null || !mounted) return;
    setState(() {
      _sukses = null;
      _hasil = null;
      _galatUmum = null;
      _galatStruktur = null;
      if (ekstensiMasterSah(b.nama)) {
        _berkas = b;
        _galatBerkas = null;
      } else {
        _berkas = null;
        _galatBerkas = l10n.unggahMasterFormatBerkas;
      }
    });
  }

  String _pesanAtauCadangan(AuthException e, StudioL10n l10n) =>
      e.message.isNotEmpty ? e.message : l10n.unggahMasterGagal;

  Future<void> _kirim() async {
    final l10n = StudioL10n.of(context);
    final alasan = _alasan.text.trim();
    setState(() {
      _sukses = null;
      _hasil = null;
      _galatUmum = null;
      _galatStruktur = null;
      _galatSandi = null;
      _galatBerkas = _berkas == null ? l10n.unggahMasterBerkasWajib : null;
      _galatAlasan = alasan.isEmpty ? l10n.unggahMasterAlasanWajib : null;
    });
    final berkas = _berkas;
    if (berkas == null || alasan.isEmpty) return;

    setState(() => _sibuk = true);
    final sandi = _sandi.text;
    try {
      final hasil = await ref.read(unggahMasterProvider)(
        jalurBerkas: berkas.jalur,
        alasan: alasan,
        sandi: sandi.isEmpty ? null : sandi,
        gantikanId: _gantikan,
      );
      if (!mounted) return;
      setState(() {
        _sukses = hasil.pesan ?? l10n.unggahMasterBerhasil;
        _hasil = hasil;
        _berkas = null;
        _gantikan = null;
        _alasan.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.status == 422) {
          switch (GalatUnggahMaster.dari(e.body, e.message)) {
            case GalatUnggahMaster.strukturBerubah:
              _galatStruktur = uraiStrukturBerubah(e.message);
            case GalatUnggahMaster.sandiSalah:
              _galatSandi = l10n.unggahMasterSandiSalah;
            case GalatUnggahMaster.sandiDiperlukan:
              _galatSandi = l10n.unggahMasterSandiDiperlukan;
            case GalatUnggahMaster.formatTidakDikenal:
              _galatBerkas = l10n.unggahMasterFormatTidakDikenal;
            case GalatUnggahMaster.lain:
              _galatUmum = _pesanAtauCadangan(e, l10n);
          }
        } else {
          _galatUmum = _pesanAtauCadangan(e, l10n);
        }
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _galatUmum = _pesanAtauCadangan(e, l10n));
    } catch (_) {
      if (!mounted) return;
      setState(() => _galatUmum = l10n.unggahMasterGagal);
    } finally {
      // Sandi tidak bertahan sesudah satu kali kirim, apa pun hasilnya.
      _sandi.clear();
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((a) => a.value?.id), (_, id) {
      if (id != _akun && mounted) Navigator.of(context).maybePop();
    });
    ref.listen(klienKedaluwarsaProvider, (_, usang) {
      if (usang && mounted) Navigator.of(context).maybePop();
    });

    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final daftar = ref.watch(
      daftarWorkbookProvider((kodeProfil: null, cari: '')),
    );

    return Scaffold(
      backgroundColor: w.latar,
      appBar: AppBar(title: Text(l10n.unggahMasterJudul)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(UkuranStudio.j6),
            children: [
              Text(
                l10n.unggahMasterKet,
                style: teks.bodyMedium?.copyWith(color: w.teks2),
              ),
              const SizedBox(height: UkuranStudio.j4),
              Row(
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('unggah-pilih'),
                    onPressed: _sibuk ? null : _pilih,
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: Text(l10n.unggahMasterPilihBerkas),
                  ),
                  const SizedBox(width: UkuranStudio.j3),
                  Expanded(
                    child: Text(
                      _berkas?.nama ?? l10n.unggahMasterBelumDipilih,
                      key: const ValueKey('unggah-nama-berkas'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_galatBerkas != null)
                _Galat(kunci: 'unggah-galat-berkas', teks: _galatBerkas!),
              const SizedBox(height: UkuranStudio.j4),
              TextField(
                key: const ValueKey('unggah-sandi'),
                controller: _sandi,
                enabled: !_sibuk,
                obscureText: !_sandiTerlihat,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.unggahMasterSandi,
                  helperText: l10n.unggahMasterSandiKet,
                  errorText: _galatSandi,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _sandiTerlihat ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _sandiTerlihat = !_sandiTerlihat),
                  ),
                ),
              ),
              const SizedBox(height: UkuranStudio.j4),
              TextField(
                key: const ValueKey('unggah-alasan'),
                controller: _alasan,
                enabled: !_sibuk,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.unggahMasterAlasan,
                  helperText: l10n.unggahMasterAlasanKet,
                  errorText: _galatAlasan,
                ),
              ),
              const SizedBox(height: UkuranStudio.j4),
              DropdownButtonFormField<int?>(
                key: ValueKey('unggah-gantikan-${_gantikan ?? '-'}'),
                initialValue: _gantikan,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.unggahMasterGantikan,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l10n.unggahMasterGantikanTidak),
                  ),
                  for (final wb in daftar.value ?? const <WorkbookRingkas>[])
                    DropdownMenuItem<int?>(
                      value: wb.id,
                      child: Text(wb.nama, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _sibuk ? null : (v) => setState(() => _gantikan = v),
              ),
              const SizedBox(height: UkuranStudio.j6),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('unggah-kirim'),
                  onPressed: _sibuk ? null : _kirim,
                  icon: _sibuk
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file, size: 18),
                  label: Text(
                    _sibuk ? l10n.unggahMasterMengirim : l10n.unggahMasterKirim,
                  ),
                ),
              ),
              if (_galatUmum != null)
                _Galat(kunci: 'unggah-galat-umum', teks: _galatUmum!),
              if (_galatStruktur != null) _GalatStruktur(_galatStruktur!),
              if (_sukses != null)
                Padding(
                  padding: const EdgeInsets.only(top: UkuranStudio.j4),
                  child: Text(
                    _sukses!,
                    key: const ValueKey('unggah-sukses'),
                    style: teks.bodyMedium,
                  ),
                ),
              if (_hasil != null) _HasilPetaSel(hasil: _hasil!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Galat extends StatelessWidget {
  const _Galat({required this.kunci, required this.teks});

  final String kunci;
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: UkuranStudio.j2),
    child: Text(
      teks,
      key: ValueKey(kunci),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

/// 422 `struktur_master_berubah`: kepala + daftar persis apa yang
/// hilang/bergeser (teks server, dipecah per butir bernomor).
class _GalatStruktur extends StatelessWidget {
  const _GalatStruktur(this.galat);

  final ({String kepala, List<String> butir}) galat;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final merah = Theme.of(context).colorScheme.error;
    final teks = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey('unggah-galat-struktur'),
      margin: const EdgeInsets.only(top: UkuranStudio.j4),
      padding: const EdgeInsets.all(UkuranStudio.j3),
      decoration: BoxDecoration(
        border: Border.all(color: merah),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.unggahMasterStrukturJudul,
            style: teks.titleSmall?.copyWith(color: merah),
          ),
          if (galat.kepala.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: UkuranStudio.j2),
              child: SelectableText(galat.kepala, style: teks.bodySmall),
            ),
          for (var i = 0; i < galat.butir.length; i++)
            Padding(
              key: ValueKey('unggah-struktur-butir-$i'),
              padding: const EdgeInsets.only(top: UkuranStudio.j2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}.')),
                  Expanded(
                    child: SelectableText(
                      galat.butir[i],
                      style: teks.bodyMedium,
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

/// Hasil peta sel & draf data acuan dari impor yang berhasil, plus pintu ke
/// layar alur versi profilnya (baca saja di Studio).
class _HasilPetaSel extends StatelessWidget {
  const _HasilPetaSel({required this.hasil});

  final HasilUnggahMaster hasil;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final acuan = hasil.acuan;
    final kode = hasil.kodeProfil;

    final baris = <Widget>[
      if (hasil.sudahAda)
        Text(
          l10n.unggahMasterSudahAda,
          key: const ValueKey('unggah-sudah-ada'),
        ),
      if (hasil.petaSel == 'tervalidasi')
        Text(
          l10n.unggahMasterPetaTervalidasi,
          key: const ValueKey('unggah-peta-tervalidasi'),
        ),
      if (hasil.belumTerpetakan)
        Text(
          l10n.unggahMasterBelumTerpetakan,
          key: const ValueKey('unggah-belum-terpetakan'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (acuan != null)
        Text(switch (acuan.status) {
          'draf_dibuat' => l10n.unggahMasterDrafDibuat(
            acuan.nomorVersi ?? 0,
            acuan.selBerubah ?? 0,
          ),
          'draf_sudah_ada' => l10n.unggahMasterDrafSudahAda(
            acuan.nomorVersi != null
                ? 'v${acuan.nomorVersi}'
                : '#${acuan.versiId ?? '?'}',
          ),
          'sama_dengan_dasar' => l10n.unggahMasterSamaDasar,
          'paket_belum_ada' => l10n.unggahMasterPaketBelumAda,
          _ => acuan.status,
        }, key: const ValueKey('unggah-acuan')),
    ];
    if (baris.isEmpty) return const SizedBox.shrink();

    final bisaBuka =
        kode != null &&
        acuan != null &&
        (acuan.status == 'draf_dibuat' || acuan.status == 'draf_sudah_ada');

    return Container(
      key: const ValueKey('unggah-hasil-peta'),
      margin: const EdgeInsets.only(top: UkuranStudio.j4),
      padding: const EdgeInsets.all(UkuranStudio.j3),
      decoration: BoxDecoration(
        border: Border.all(color: w.garis),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DefaultTextStyle.merge(
        style: teks.bodyMedium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final b in baris)
              Padding(
                padding: const EdgeInsets.only(bottom: UkuranStudio.j2),
                child: b,
              ),
            if (bisaBuka)
              OutlinedButton.icon(
                key: const ValueKey('unggah-buka-alur'),
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: Text(l10n.unggahMasterBukaAlur),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlurVersiAcuanScreen(kode: kode),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
