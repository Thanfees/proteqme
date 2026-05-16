import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/contact.dart';
import '../../data/repositories/contact_repository.dart';
import '../../data/repositories/sos_repository.dart';
import '../../services/convex_service.dart';
import '../home/home_screen.dart';

class ContactsSetupScreen extends StatefulWidget {
  const ContactsSetupScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  State<ContactsSetupScreen> createState() => _ContactsSetupScreenState();
}

class _ContactsSetupScreenState extends State<ContactsSetupScreen> {
  final _repo = ContactRepository();
  final _sosRepo = SosRepository();
  List<Contact> _contacts = [];
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _language = 'en';
  int _nextPriority = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _contacts = await _repo.getAll();
    _nextPriority = _contacts.isEmpty
        ? 1
        : _contacts.map((c) => c.priority).reduce((a, b) => a > b ? a : b) + 1;
    setState(() {});
  }

  Future<void> _addContact() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;
    await _repo.insert(
      Contact(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        priority: _nextPriority,
        language: _language,
      ),
    );
    _nameCtrl.clear();
    _phoneCtrl.clear();
    await _load();
  }

  Future<void> _syncFromConvex() async {
    if (!ConvexService.instance.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convex not configured')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('convex_user_id') ?? 'local_user';
    final remote = await ConvexService.instance.fetchContacts(userId);
    if (remote.isNotEmpty) {
      await _repo.replaceAll(remote);
      await _load();
    }
  }

  Future<void> _saveAndContinue() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one contact')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('contacts_setup_complete', true);
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _setUserName() async {
    final ctrl = TextEditingController(
      text: (await _sosRepo.getState()).userName,
    );
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your display name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Name in SMS alerts'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _sosRepo.updateUserName(name);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency contacts'),
        actions: [
          if (ConvexService.instance.isConfigured)
            IconButton(
              onPressed: _syncFromConvex,
              icon: const Icon(Icons.cloud_download),
              tooltip: 'Sync from Convex',
            ),
          IconButton(
            onPressed: _setUserName,
            icon: const Icon(Icons.person),
            tooltip: 'Your name',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._contacts.map(
            (c) => ListTile(
              leading: CircleAvatar(child: Text('${c.priority}')),
              title: Text(c.name),
              subtitle: Text('${c.phone} · ${c.language}'),
            ),
          ),
          const Divider(),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone'),
            keyboardType: TextInputType.phone,
          ),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'SMS language'),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'si', child: Text('Sinhala')),
              DropdownMenuItem(value: 'ta', child: Text('Tamil')),
            ],
            onChanged: (v) => setState(() => _language = v ?? 'en'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _addContact, child: const Text('Add contact')),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saveAndContinue,
            child: Text(widget.fromSettings ? 'Done' : 'Start monitoring'),
          ),
        ],
      ),
    );
  }
}
