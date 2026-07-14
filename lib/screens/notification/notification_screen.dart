import 'package:flutter/material.dart';

import '../../widgets/empty_placeholder.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: const EmptyPlaceholder(
        icon: Icons.notifications_none,
        title: 'Notifikasi',
        message:
            'Pengingat alat yang mau jatuh tempo kalibrasi. Digarap minggu 9.',
      ),
    );
  }
}
