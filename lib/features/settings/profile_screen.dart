import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/brand_scaffold.dart';
import '../../data/local/app_database.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance();
    final name = await db.getUserDisplayName();
    if (!mounted) return;
    _controller.text = name == 'ProteqMe User' ? '' : name;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _status = 'Please enter your name.');
      return;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    final db = await AppDatabase.instance();
    await db.setUserDisplayName(name);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = 'Saved — used in every SOS SMS.';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandScaffold(
      title: 'Your profile',
      body: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandSectionHeader(
                  label: 'IDENTITY',
                  icon: Icons.person_outline,
                ),
                BrandCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Your name',
                        style: TextStyle(
                          color: Color(0xFFFFE7F2),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'This name appears in every SOS SMS so your '
                        'contacts know who is in danger.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB59BC9),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Color(0xFFFFE7F2)),
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          hintText: 'e.g. Nimal Perera',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_status != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              _status!.startsWith('Saved')
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              size: 16,
                              color: _status!.startsWith('Saved')
                                  ? const Color(0xFF3BE77A)
                                  : const Color(0xFFFFB347),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _status!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _status!.startsWith('Saved')
                                      ? const Color(0xFF3BE77A)
                                      : const Color(0xFFFFB347),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving…' : 'Save name'),
                      ),
                    ],
                  ),
                ),
                const BrandSectionHeader(
                  label: 'PREVIEW',
                  icon: Icons.sms_outlined,
                ),
                BrandCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sample SOS message',
                        style: TextStyle(
                          color: Color(0xFFFFE7F2),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0x33221232),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0x44FF63A4)),
                        ),
                        child: Text(
                          'URGENT SOS (now): '
                          '${_controller.text.trim().isEmpty ? "Your name" : _controller.text.trim()} '
                          'is in danger! Location: https://maps.google.com/?q=…',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFD9C5E9),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
