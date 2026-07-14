import 'package:flutter/material.dart';

import '../../widgets/empty_placeholder.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: const EmptyPlaceholder(
        icon: Icons.history_outlined,
        title: 'Riwayat Kalibrasi',
        message:
            'Riwayat sesi kalibrasi & sertifikat yang udah terbit. '
            'Digarap minggu 9.',
      ),
    );
  }
}
