import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/widgets/brand_scaffold.dart';
import '../domain/entities/emergency_contact.dart';
import 'contacts_controller.dart';
import 'widgets/contact_form_dialog.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);
    final controller = ref.read(contactsControllerProvider);

    return BrandScaffold(
      title: 'Emergency Contacts',
      scroll: false,
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF3B7C),
        foregroundColor: Colors.white,
        onPressed: () => _onAddContactPicker(context, controller),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text(
          'Add Contact',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: contactsState.when(
        data: (contacts) {
          if (contacts.isEmpty) {
            return _EmptyContacts(
              onAdd: () => _onAddContactPicker(context, controller),
            );
          }

          String? primaryId;
          for (final contact in contacts) {
            if (contact.isPrimary) {
              primaryId = contact.id;
              break;
            }
          }

          return RadioGroup<String>(
            groupValue: primaryId,
            onChanged: (value) {
              if (value != null) {
                controller.setPrimary(value);
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandSectionHeader(
                    label: 'PRIMARY CONTACT',
                    icon: Icons.star_rounded,
                  ),
                  const _PrimaryHint(),
                  const BrandSectionHeader(
                    label: 'YOUR EMERGENCY CONTACTS',
                    icon: Icons.groups_2_outlined,
                  ),
                  for (int i = 0; i < contacts.length; i++) ...[
                    _ContactCard(
                      contact: contacts[i],
                      onEdit: () =>
                          _onEditContact(context, controller, contacts[i]),
                      onDelete: () =>
                          _onDeleteContact(context, controller, contacts[i]),
                    ),
                    if (i != contacts.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );
        },
        error: (error, _) => _ErrorState(message: 'Failed to load contacts: $error'),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _onPickFromPhone(
    BuildContext context,
    ContactsController controller,
  ) async {
    final result = await controller.pickFromPhone();
    if (!context.mounted) return;

    if (result.cancelled) return;

    if (result.error != null) {
      if (result.openSettings) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error!),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error!)),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${result.addedName} as emergency contact.')),
    );
  }

  /// Shows a bottom sheet asking how to add a contact.
  Future<void> _onAddContactPicker(
    BuildContext context,
    ContactsController controller,
  ) async {
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      backgroundColor: const Color(0xFF1B1126),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0x44FF63A4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Add Emergency Contact',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFFFFE7F2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: BrandTile(
                  icon: Icons.contact_phone_outlined,
                  title: 'Select from phone',
                  subtitle: 'Pick a contact from your phone book',
                  onTap: () =>
                      Navigator.of(context).pop(_AddChoice.fromPhone),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: BrandTile(
                  icon: Icons.edit_outlined,
                  title: 'Enter manually',
                  subtitle: 'Type a name and phone number',
                  onTap: () =>
                      Navigator.of(context).pop(_AddChoice.manually),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || choice == null) return;

    if (choice == _AddChoice.fromPhone) {
      await _onPickFromPhone(context, controller);
    } else {
      await _onAddContact(context, controller);
    }
  }

  Future<void> _onAddContact(
    BuildContext context,
    ContactsController controller,
  ) async {
    final result = await ContactFormDialog.show(context);
    if (result == null) {
      return;
    }

    final error = await controller.addContact(
      name: result.name,
      phone: result.phone,
      setAsPrimary: result.setAsPrimary,
    );

    if (context.mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _onEditContact(
    BuildContext context,
    ContactsController controller,
    EmergencyContact contact,
  ) async {
    final authorized = await _verifyIdentity(
      context,
      reason: 'Confirm identity to edit ${contact.name}',
    );
    if (!authorized || !context.mounted) return;

    final result = await ContactFormDialog.show(context, initial: contact);
    if (result == null) {
      return;
    }

    final error = await controller.updateContact(
      contact: contact,
      name: result.name,
      phone: result.phone,
      setAsPrimary: result.setAsPrimary,
    );

    if (context.mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _onDeleteContact(
    BuildContext context,
    ContactsController controller,
    EmergencyContact contact,
  ) async {
    final authorized = await _verifyIdentity(
      context,
      reason: 'Confirm identity to delete ${contact.name}',
    );
    if (!authorized || !context.mounted) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Remove ${contact.name} from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await controller.deleteContact(contact.id);
  }

  /// Requires fingerprint / device PIN before allowing edit or delete.
  /// Prevents an attacker from silently disabling SOS by removing your contacts.
  Future<bool> _verifyIdentity(
    BuildContext context, {
    required String reason,
  }) async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      if (!supported) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Set a screen lock (PIN, pattern, or fingerprint) to protect contacts.',
              ),
            ),
          );
        }
        return false;
      }

      final ok = await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Identity not confirmed.')),
        );
      }
      return ok;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auth error: $e')),
        );
      }
      return false;
    }
  }
}

enum _AddChoice { fromPhone, manually }

class _PrimaryHint extends StatelessWidget {
  const _PrimaryHint();

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: Color(0xFFFF6AA7), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap a contact below to mark them as your primary — they get '
              'called first during SOS.',
              style: TextStyle(
                color: Color(0xFFD9C5E9),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      borderColor: contact.isPrimary
          ? const Color(0xAAFF63A4)
          : const Color(0x44FF63A4),
      child: Row(
        children: [
          Radio<String>(value: contact.id),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact.name,
                        style: const TextStyle(
                          color: Color(0xFFFFE7F2),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (contact.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF6AA7),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: const Color(0xAAFF6AA7),
                          ),
                        ),
                        child: const Text(
                          'PRIMARY',
                          style: TextStyle(
                            color: Color(0xFFFFE7F2),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  style: const TextStyle(
                    color: Color(0xFFB59BC9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFFD9C5E9),
            ),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFFF3B5C),
            ),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contacts_outlined,
              size: 48,
              color: Color(0xFF8A7A9B),
            ),
            const SizedBox(height: 16),
            const Text(
              'No emergency contacts yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFE7F2),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Add at least one contact so ProteqMe knows who to call '
                'during an SOS.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFB59BC9),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add Contact'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BrandCard(
        borderColor: const Color(0x66FF3B5C),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF3B5C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFFFFE7F2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
