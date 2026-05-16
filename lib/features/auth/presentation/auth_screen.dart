import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/secrets.dart';
import '../../../data/local/app_database.dart';
import '../../../services/convex_service.dart';
import '../../contacts/data/hive_contact_repository.dart';
import '../../contacts/domain/entities/emergency_contact.dart';

/// OTP login to restore contacts from Convex vault on a new device.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _otpSent = false;

  Future<void> _requestOtp() async {
    final convex = ConvexService.tryCreate();
    if (convex == null) {
      setState(() => _error = 'Configure CONVEX_URL and CONVEX_DEPLOY_KEY');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await convex.requestOtp(_phoneController.text.trim());
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = 'OTP request failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final convex = ConvexService.tryCreate();
    if (convex == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await convex.verifyOtp(
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
      );
      final userId = result?['userId'] as String?;
      if (userId == null) {
        setState(() => _error = 'Invalid OTP');
        return;
      }

      final db = await AppDatabase.instance();
      await db.db.update(
        'auth_session',
        {
          'user_id': userId,
          'phone': _phoneController.text.trim(),
          'display_name': result?['displayName'] ?? 'ProteqMe User',
        },
        where: 'id = ?',
        whereArgs: [1],
      );

      final remote = await convex.fetchContacts(userId);
      final repo = ref.read(hiveContactRepositoryProvider);
      for (final row in remote) {
        await repo.upsertContact(
          EmergencyContact(
            id: row['_id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
            name: row['name'] as String? ?? 'Contact',
            phone: row['phone'] as String? ?? '',
            isPrimary: row['priority'] == 1,
            language: row['language'] as String? ?? 'en',
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Verify failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Secrets.hasConvex) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cloud vault')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Convex is not configured. Build with:\n'
            '--dart-define=CONVEX_URL=...\n'
            '--dart-define=CONVEX_DEPLOY_KEY=...',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in — ProteqMe vault')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone number'),
              keyboardType: TextInputType.phone,
            ),
            if (_otpSent)
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'OTP code'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading
                  ? null
                  : (_otpSent ? _verify : _requestOtp),
              child: Text(_otpSent ? 'Verify & sync contacts' : 'Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
