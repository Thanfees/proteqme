import 'package:flutter/material.dart';

import '../../domain/entities/emergency_contact.dart';

class ContactFormValue {
  const ContactFormValue({
    required this.name,
    required this.phone,
    required this.setAsPrimary,
  });

  final String name;
  final String phone;
  final bool setAsPrimary;
}

class ContactFormDialog extends StatefulWidget {
  const ContactFormDialog({super.key, this.initial});

  final EmergencyContact? initial;

  static Future<ContactFormValue?> show(
    BuildContext context, {
    EmergencyContact? initial,
  }) {
    return showDialog<ContactFormValue>(
      context: context,
      builder: (_) => ContactFormDialog(initial: initial),
    );
  }

  @override
  State<ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<ContactFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late bool _setAsPrimary;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _setAsPrimary = initial?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Contact' : 'Add Contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set as primary contact'),
              value: _setAsPrimary,
              onChanged: (value) => setState(() => _setAsPrimary = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              ContactFormValue(
                name: _nameController.text,
                phone: _phoneController.text,
                setAsPrimary: _setAsPrimary,
              ),
            );
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
