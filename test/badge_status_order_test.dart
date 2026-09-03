import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/widgets/status_badge.dart';

/// Empat status Order punya warna & ikonnya sendiri (BUG-011).
///
/// `Order::STATUS_BARU|DIPROSES|SELESAI|DIBATALKAN` di backend tidak punya satu
/// pun `case` di `StatusBadge.fromApi`, jadi keempatnya jatuh ke cabang
/// default. Fallback-nya memang didesain aman — dia tidak bikin app crash, dan
/// justru itu sebabnya tidak ada yang menyadarinya: teknisi melihat teks mentah
/// `dibatalkan` dalam pil abu-abu, sama datarnya dengan `baru`, padahal status
/// alat dan status sesi kalibrasi semuanya sudah berwarna.
///
/// Yang diuji di sini nada warnanya (`BadgeTone`), bukan kode warnanya —
/// paletnya boleh diganti, artinya tidak boleh.
void main() {
  ({String label, BadgeTone tone, IconData? icon}) badge(String api) {
    final b = StatusBadge.fromApi(api);
    return (label: b.label, tone: b.tone, icon: b.icon);
  }

  group('status Order dikenali', () {
    test('baru', () {
      final b = badge('baru');
      expect(b.label, 'Baru');
      expect(b.tone, BadgeTone.info);
      expect(b.icon, isNotNull);
    });

    test('diproses', () {
      final b = badge('diproses');
      expect(b.label, 'Diproses');
      expect(b.tone, BadgeTone.warning);
      expect(b.icon, isNotNull);
    });

    test('selesai', () {
      final b = badge('selesai');
      expect(b.label, 'Selesai');
      expect(b.tone, BadgeTone.success);
      expect(b.icon, isNotNull);
    });

    test('dibatalkan', () {
      final b = badge('dibatalkan');
      expect(b.label, 'Dibatalkan');
      expect(b.tone, BadgeTone.danger);
      expect(b.icon, isNotNull);
    });

    /// Inti bug-nya, dan yang tidak bisa hijau karena kebetulan: keempatnya
    /// dulu punya nada yang SAMA (neutral) dan label mentah. Yang diadu di sini
    /// bukan tiap nilai satu per satu, tapi bahwa keempatnya bisa dibedakan.
    test('keempatnya nggak lagi datar sewarna', () {
      final nada = ['baru', 'diproses', 'selesai', 'dibatalkan']
          .map((s) => StatusBadge.fromApi(s).tone)
          .toSet();

      expect(
        nada,
        hasLength(4),
        reason: 'Masih ada status Order yang jatuh ke nada yang sama.',
      );
      expect(nada, isNot(contains(BadgeTone.neutral)));
    });

    /// Order yang dibatalkan itu pekerjaan yang tidak jadi; FAIL itu alat yang
    /// tidak lolos. Dua hal yang tidak boleh terbaca sama sekilas, walau
    /// nada warnanya sama-sama `danger`.
    test('ikon "dibatalkan" beda dari ikon FAIL', () {
      expect(
        StatusBadge.fromApi('dibatalkan').icon,
        isNot(StatusBadge.fromApi('FAIL').icon),
      );
    });
  });

  /// JANGAN kebablasan.
  group('yang sudah benar tetap seperti sebelumnya', () {
    test('status alat & sesi nggak ikut berubah', () {
      expect(StatusBadge.fromApi('PASS').tone, BadgeTone.success);
      expect(StatusBadge.fromApi('FAIL').tone, BadgeTone.danger);
      expect(StatusBadge.fromApi('aktif').tone, BadgeTone.success);
      expect(StatusBadge.fromApi('overdue').tone, BadgeTone.warning);
      expect(StatusBadge.fromApi('nonaktif').tone, BadgeTone.neutral);
      expect(StatusBadge.fromApi('draft').tone, BadgeTone.neutral);
      expect(StatusBadge.fromApi('menunggu_approval').tone, BadgeTone.info);
      expect(StatusBadge.fromApi('disetujui').tone, BadgeTone.success);
      expect(StatusBadge.fromApi('perlu_revisi').tone, BadgeTone.warning);
    });

    /// Fallback-nya tetap ada dan tetap aman: status baru dari backend
    /// ditampilkan apa adanya, bukan bikin app crash.
    test('status yang belum dikenal tetap tampil apa adanya', () {
      final b = StatusBadge.fromApi('status_yang_belum_ada');
      expect(b.label, 'status_yang_belum_ada');
      expect(b.tone, BadgeTone.neutral);
    });
  });
}
