import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/data_acuan.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/screens/data_acuan/widgets/keadaan_acuan.dart';

import '../../data/workbook_model.dart';
import '../../data/workbook_provider.dart';
import '../../l10n/studio_l10n.dart';
import '../../tema/tema_studio.dart';
import '../../tema/warna_studio.dart';
import '../../widget/bilah_status.dart';
import '../seksi_studio.dart';

/// ST-02 Beranda — "tahu apa yang menunggu saya" (FR-STU-014).
///
/// Dasar S1: kartu cuma untuk data yang SUDAH ada servernya. Kartu ST-02
/// lain (menunggu keputusan, pekerjaan berjalan, status paritas, draf saya,
/// standar mendekati `berlaku_sampai`) lahir bersama tahap yang membangun
/// datanya — bukan kartu tiruan sekarang.
///
/// Kartu yang izinnya tidak dimiliki TIDAK tampil (dan servernya tidak
/// ditembak).
class BerandaScreen extends ConsumerWidget {
  const BerandaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final akun = ref.watch(authProvider).value;
    final peran = labelPeranStudio(peranAkunStudio(ref), l10n);

    final kartu = <Widget>[
      if (bolehBukaDataAcuan(ref)) const _KartuDataAcuan(),
      if (bolehBukaWorkbook(ref)) const _KartuWorkbook(),
    ];

    return ColoredBox(
      color: w.latar,
      child: ListView(
        padding: const EdgeInsets.all(UkuranStudio.j6),
        children: [
          if (akun != null)
            Text(
              l10n.berandaMasukSebagai(akun.nama, peran),
              style: teks.bodyMedium?.copyWith(color: w.teks2),
            ),
          const SizedBox(height: UkuranStudio.j4),
          if (kartu.isEmpty)
            _Kosong(
              judul: l10n.berandaKosong,
              keterangan: l10n.berandaKosongKet,
            )
          else
            for (final k in kartu)
              Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: UkuranStudio.j4),
                    child: k,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Ringkasan paket data acuan: versi yang berlaku hari ini per paket.
class _KartuDataAcuan extends ConsumerWidget {
  const _KartuDataAcuan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final l10nBersama = AppLocalizations.of(context);
    final daftar = ref.watch(daftarPaketAcuanProvider);

    void buka() => ref
        .read(pilihanSeksiStudioProvider.notifier)
        .pilih(SeksiStudio.dataAcuan);

    return _Kartu(
      ikon: SeksiStudio.dataAcuan.ikon,
      judul: l10n.seksiDataAcuan,
      aksi: TextButton(onPressed: buka, child: Text(l10n.kartuBuka)),
      isi: daftar.when(
        loading: () => const _KerangkaBaris(),
        error: (e, _) => _GalatKartu(
          pesan: pesanGalatAcuan(e, l10nBersama),
          onCobaLagi: () => ref.invalidate(daftarPaketAcuanProvider),
        ),
        data: (paket) => paket.isEmpty
            ? _Kosong(judul: l10n.kartuDataAcuanKosong)
            : _TabelPaket(paket: paket, onBuka: buka),
      ),
    );
  }
}

/// Ringkasan Workbook Alat (S1b): berapa workbook, berapa yang belum
/// tersambung ke profil alat, dan dari sumber apa.
class _KartuWorkbook extends ConsumerWidget {
  const _KartuWorkbook();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    const KunciDaftarWorkbook kunci = (kodeProfil: null, cari: '');
    final daftar = ref.watch(daftarWorkbookProvider(kunci));

    void buka() => ref
        .read(pilihanSeksiStudioProvider.notifier)
        .pilih(SeksiStudio.workbookAlat);

    return _Kartu(
      key: const ValueKey('kartu-workbook'),
      ikon: SeksiStudio.workbookAlat.ikon,
      judul: l10n.seksiWorkbookAlat,
      aksi: TextButton(onPressed: buka, child: Text(l10n.kartuBuka)),
      isi: switch (daftar) {
        AsyncData(:final value) when value.isEmpty => _Kosong(
          judul: l10n.workbookKosong,
        ),
        AsyncData(:final value) => Padding(
          padding: const EdgeInsets.all(UkuranStudio.j4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.kartuWorkbookRingkas(
                  value.length,
                  value.where((x) => !x.dipetakan).length,
                ),
                style: teks.bodyMedium,
              ),
              const SizedBox(height: UkuranStudio.j1),
              Text(
                l10n.kartuWorkbookSumber(
                  value.where((x) => x.sumber == SumberWorkbook.csv).length,
                  value.where((x) => x.sumber == SumberWorkbook.xlsm).length,
                ),
                style: teks.bodySmall?.copyWith(color: w.teks2),
              ),
            ],
          ),
        ),
        AsyncError() => _GalatKartu(
          pesan: l10n.workbookGagalMuat,
          onCobaLagi: () => ref.invalidate(daftarWorkbookProvider(kunci)),
        ),
        _ => const _KerangkaBaris(),
      },
    );
  }
}

class _TabelPaket extends StatelessWidget {
  const _TabelPaket({required this.paket, required this.onBuka});

  final List<PaketAcuan> paket;
  final VoidCallback onBuka;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    // Teknisi tidak menerima kunci `jumlah_draf` (null, BUKAN nol): kolomnya
    // tidak ditulis sama sekali, bukan diisi "0".
    final adaDraf = paket.any((p) => p.jumlahDraf != null);
    final kepala = teks.labelMedium?.copyWith(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: w.permukaanRendah,
          padding: const EdgeInsets.symmetric(
            horizontal: UkuranStudio.j4,
            vertical: UkuranStudio.j2,
          ),
          child: Row(
            children: [
              Expanded(child: Text(l10n.kolomPaket, style: kepala)),
              SizedBox(
                width: 220,
                child: Text(l10n.kolomVersiAktif, style: kepala),
              ),
              if (adaDraf)
                SizedBox(
                  width: 64,
                  child: Text(
                    l10n.kolomDraf,
                    style: kepala,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        ),
        for (final (i, p) in paket.indexed) ...[
          if (i > 0) Divider(color: w.garis),
          _BarisPaket(paket: p, adaDraf: adaDraf, onTap: onBuka),
        ],
      ],
    );
  }
}

class _BarisPaket extends StatelessWidget {
  const _BarisPaket({
    required this.paket,
    required this.adaDraf,
    required this.onTap,
  });

  final PaketAcuan paket;
  final bool adaDraf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final l10nBersama = AppLocalizations.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final aktif = paket.versiAktif;

    final Widget versi;
    if (!paket.diimpor) {
      versi = Text(
        l10n.belumDiimpor,
        style: teks.bodyMedium?.copyWith(color: w.teksRedup),
      );
    } else if (aktif == null) {
      versi = Text(
        l10n.tanpaVersiAktif,
        style: teks.bodyMedium?.copyWith(color: w.teksRedup),
      );
    } else {
      versi = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'v${aktif.nomor}',
              style: TipografiStudio.angka(warna: w.teks),
            ),
            TextSpan(
              text:
                  '  ${teksBerlakuAcuan(aktif.berlakuMulai, aktif.berlakuSampai, l10nBersama, locale)}',
              style: teks.bodySmall,
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UkuranStudio.j4,
          vertical: UkuranStudio.j3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                paket.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: teks.bodyMedium?.copyWith(
                  color: paket.diimpor ? w.teks : w.teksRedup,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 220, child: versi),
            if (adaDraf)
              SizedBox(
                width: 64,
                child: Text(
                  paket.jumlahDraf == null ? '' : '${paket.jumlahDraf}',
                  textAlign: TextAlign.end,
                  style: TipografiStudio.angka(warna: w.teks),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── kerangka kartu

class _Kartu extends StatelessWidget {
  const _Kartu({
    super.key,
    required this.ikon,
    required this.judul,
    required this.isi,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
  final Widget isi;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UkuranStudio.j4,
              UkuranStudio.j2,
              UkuranStudio.j2,
              UkuranStudio.j2,
            ),
            child: Row(
              children: [
                Icon(ikon, size: 18, color: w.teks2),
                const SizedBox(width: UkuranStudio.j2),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      judul,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                ?aksi,
              ],
            ),
          ),
          Divider(color: w.garis),
          isi,
        ],
      ),
    );
  }
}

/// Kerangka baris setinggi baris tabel — bukan spinner (ST-90 "Memuat").
class _KerangkaBaris extends StatelessWidget {
  const _KerangkaBaris();

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    return Semantics(
      label: l10n.memuat,
      child: Padding(
        padding: const EdgeInsets.all(UkuranStudio.j4),
        child: Column(
          children: [
            for (final lebar in const [0.6, 0.45, 0.52])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: UkuranStudio.j2),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: lebar,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: w.permukaanRendah,
                      borderRadius: BorderRadius.circular(UkuranStudio.sudut),
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

/// Galat per kartu — kartu lain tetap (ST-90 matriks, baris ST-02).
class _GalatKartu extends StatelessWidget {
  const _GalatKartu({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    return Padding(
      padding: const EdgeInsets.all(UkuranStudio.j4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: w.gagal),
          const SizedBox(width: UkuranStudio.j2),
          Expanded(
            child: Text(pesan, style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(onPressed: onCobaLagi, child: Text(l10n.cobaLagi)),
        ],
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.judul, this.keterangan});

  final String judul;
  final String? keterangan;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(UkuranStudio.j4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: teks.bodyMedium),
          if (keterangan != null) ...[
            const SizedBox(height: UkuranStudio.j1),
            Text(keterangan!, style: teks.bodySmall?.copyWith(color: w.teks2)),
          ],
        ],
      ),
    );
  }
}
