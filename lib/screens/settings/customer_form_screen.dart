import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../providers/master_data_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Form tambah/edit pelanggan. `existing == null` → mode tambah.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.existing});

  final Customer? existing;

  @override
  ConsumerState<CustomerFormScreen> createState() =>
      _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  late final _nama = TextEditingController(text: widget.existing?.nama);
  late final _alamat = TextEditingController(text: widget.existing?.alamat);
  late final _contactPerson = TextEditingController(
    text: widget.existing?.contactPerson,
  );
  late final _telepon = TextEditingController(text: widget.existing?.telepon);
  late final _email = TextEditingController(text: widget.existing?.email);

  bool _menyimpan = false;
  String? _errorNama;

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _contactPerson.dispose();
    _telepon.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);

    if (_nama.text.trim().isEmpty) {
      setState(() => _errorNama = l10n.custFieldRequired);
      return;
    }
    setState(() {
      _errorNama = null;
      _menyimpan = true;
    });

    final data = Customer(
      id: widget.existing?.id ?? 0,
      nama: _nama.text.trim(),
      alamat: _alamat.text.trim(),
      contactPerson: _contactPerson.text.trim(),
      telepon: _telepon.text.trim(),
      email: _email.text.trim(),
      jumlahAlat: widget.existing?.jumlahAlat ?? 0,
    );

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.existing == null) {
        await ref.read(customerProvider.notifier).tambah(data);
      } else {
        await ref.read(customerProvider.notifier).ubah(data);
      }
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.custSaveFailed(e.toString()))),
      );
      setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mengedit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(mengedit ? l10n.custEdit : l10n.custAdd),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppTextField(
            label: l10n.custNama,
            controller: _nama,
            errorText: _errorNama,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: l10n.custAlamat, controller: _alamat),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.custContactPerson,
            controller: _contactPerson,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.custTelepon,
            controller: _telepon,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.custEmail,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.custSave,
            isLoading: _menyimpan,
            onPressed: _menyimpan ? null : _simpan,
          ),
        ],
      ),
    );
  }
}
