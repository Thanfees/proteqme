import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/emergency_contact.dart';
import 'contacts_controller.dart';
import 'widgets/contact_form_dialog.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);
    final controller = ref.read(contactsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onAddContact(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: contactsState.when(
            data: (contacts) {
              if (contacts.isEmpty) {
                return const Center(
                  child: Text(
                    'No contacts yet. Add at least one emergency contact.',
                  ),
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
                child: ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return Card(
                      child: ListTile(
                        title: Text(contact.name),
                        subtitle: Text(contact.phone),
                        leading: Radio<String>(value: contact.id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () =>
                                  _onEditContact(context, controller, contact),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () => _onDeleteContact(
                                context,
                                controller,
                                contact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            error: (error, _) =>
                Center(child: Text('Failed to load contacts: $error')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Remove ${contact.name} from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
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
}
