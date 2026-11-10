import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/layout/detektor_layout.dart';
import '../../services/pesan_galat_pindai.dart' show catatGalatPindai;

/// Kemajuan yang ditampilkan dialog "Mendeteksi Tabel & Membaca Formulir…".
class KemajuanProses {
  const KemajuanProses({this.tahap, this.bagian});

  /// `null` = membaca formulir (setelah/tanpa layout).
  final TahapLayout? tahap;

  /// 0..1 untuk unduhan model; selain itu `null` (tak tentu).
  final double? bagian;
}

/// Isi dialog progres pindai. Tanpa layout ([denganLayout] false) teksnya
/// tetap kalimat lama ("Membaca foto di HP…") — jalur Windows/iOS/test tidak
/// berubah satu huruf pun.
class IsiDialogProses extends StatelessWidget {
  const IsiDialogProses({
    super.key,
    required this.kemajuan,
    required this.denganLayout,
  });

  final ValueListenable<KemajuanProses> kemajuan;
  final bool denganLayout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<KemajuanProses>(
      valueListenable: kemajuan,
      builder: (_, k, _) {
        if (!denganLayout) {
          return Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(l10n.lkAsliMemproses)),
            ],
          );
        }

        final sub = switch (k.tahap) {
          TahapLayout.menyiapkanModel => l10n.lkLayoutMenyiapkanModel,
          TahapLayout.mengunduhModel => l10n.lkLayoutMengunduhModel(
            ((k.bagian ?? 0) * 100).floor(),
          ),
          TahapLayout.memeriksaModel => l10n.lkLayoutMemeriksaModel,
          TahapLayout.mendeteksi => l10n.lkLayoutDeteksiJalan,
          null => l10n.lkAsliMemproses,
        };

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.lkLayoutMendeteksi,
                    key: const ValueKey('judul-proses-layout'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (k.tahap == TahapLayout.mengunduhModel)
              LinearProgressIndicator(
                key: const ValueKey('progres-unduh-model'),
                value: k.bagian,
              ),
            const SizedBox(height: 8),
            Text(
              sub,
              key: const ValueKey('sub-proses-layout'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

/// Menjalankan deteksi layout dengan jalan keluar yang jelas:
///  - platform tak didukung / unduhan ditolak -> `null` tanpa suara;
///  - gagal -> dialog "Muat ulang" / "Lanjut tanpa deteksi tabel". Memilih
///    lanjut mengembalikan `null`: pembacaan sel TIDAK bergantung pada layout.
Future<HasilLayout?> jalankanLayoutDenganPilihan({
  required BuildContext Function() konteks,
  required DetektorLayout detektor,
  required Uint8List jpeg,
  required ValueNotifier<KemajuanProses> proses,
  required Future<bool> Function() jaringanTakBerbayar,
}) async {
  if (!detektor.tersedia) return null;

  while (true) {
    SebabLayoutGagal sebab;

    try {
      return await detektor.deteksi(
        jpeg,
        kemajuan: (tahap, bagian) =>
            proses.value = KemajuanProses(tahap: tahap, bagian: bagian),
        izinUnduh: () => _izinUnduh(konteks(), jaringanTakBerbayar),
      );
    } on LayoutGagal catch (e, st) {
      if (e.sebab == SebabLayoutGagal.platformTakDidukung ||
          e.sebab == SebabLayoutGagal.unduhDitolak) {
        return null;
      }
      catatGalatPindai('layout', e, st);
      sebab = e.sebab;
    } catch (e, st) {
      catatGalatPindai('layout', e, st);
      sebab = SebabLayoutGagal.deteksiGagal;
    }

    final context = konteks();
    if (!context.mounted) return null;

    final ulang = await _tanyaUlang(context, sebab);
    if (ulang != true) return null;

    proses.value = const KemajuanProses(tahap: TahapLayout.menyiapkanModel);
  }
}

Future<bool> _izinUnduh(
  BuildContext context,
  Future<bool> Function() jaringanTakBerbayar,
) async {
  if (await jaringanTakBerbayar()) return true;
  if (!context.mounted) return false;

  final l10n = AppLocalizations.of(context);
  final ya = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.lkLayoutUnduhSelulerJudul),
      content: Text(l10n.lkLayoutUnduhSelulerIsi),
      actions: [
        TextButton(
          key: const ValueKey('layout-lewati'),
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.lkLayoutLanjutTanpa),
        ),
        FilledButton(
          key: const ValueKey('layout-unduh'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.lkLayoutUnduh),
        ),
      ],
    ),
  );

  return ya == true;
}

Future<bool?> _tanyaUlang(BuildContext context, SebabLayoutGagal sebab) {
  final l10n = AppLocalizations.of(context);
  final teksSebab = switch (sebab) {
    SebabLayoutGagal.modelRusak => l10n.lkLayoutSebabRusak,
    SebabLayoutGagal.deteksiGagal => l10n.lkLayoutSebabDeteksi,
    _ => l10n.lkLayoutSebabUnduh,
  };

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.lkLayoutGagalJudul),
      content: Text(l10n.lkLayoutGagalIsi(teksSebab)),
      actions: [
        TextButton(
          key: const ValueKey('layout-lanjut-tanpa'),
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.lkLayoutLanjutTanpa),
        ),
        FilledButton(
          key: const ValueKey('layout-muat-ulang'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.lkLayoutMuatUlang),
        ),
      ],
    ),
  );
}

/// Petunjuk deteksi -> kalimat untuk layar review.
List<String> teksPeringatanLayout(
  AppLocalizations l10n,
  List<PeringatanLayout> p,
) => [
  for (final x in p)
    switch (x) {
      PeringatanLayout.tabelTakTerdeteksi => l10n.lkLayoutTabelTakTerdeteksi,
      PeringatanLayout.tabelTerpotong => l10n.lkLayoutTabelTerpotong,
    },
];
