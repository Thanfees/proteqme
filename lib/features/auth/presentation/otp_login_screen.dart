import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/secrets.dart';
import '../../../core/widgets/brand_scaffold.dart';
import '../../../data/local/app_database.dart';
import '../../../services/convex_service.dart';
import '../../../services/live_location_service.dart';
import '../../contacts/data/hive_contact_repository.dart';
import '../../contacts/domain/entities/emergency_contact.dart';

/// Legacy OTP login retained for back-compat with phone-only accounts.
///
/// The primary auth surface is now [AuthScreen] (username/password); this
/// screen is reachable via the small "Use OTP login (legacy)" link.
class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

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

      final remote = await convex.fetchContacts(userId: userId);
      final repo = ref.read(hiveContactRepositoryProvider);
      for (final row in remote) {
        await repo.upsertContact(
          EmergencyContact(
            id: row['_id']?.toString() ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            name: row['name'] as String? ?? 'Contact',
            phone: row['phone'] as String? ?? '',
            isPrimary: row['priority'] == 1,
            language: row['language'] as String? ?? 'en',
          ),
        );
      }
      
      ref.read(liveLocationServiceFutureProvider.future).then((service) {
        service.start(userId);
      });

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
      return BrandScaffold(
        title: 'OTP login',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            BrandSectionHeader(
              label: 'NOT CONFIGURED',
              icon: Icons.warning_amber_rounded,
            ),
            BrandCard(
              borderColor: Color(0x66FFB347),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        color: Color(0xFFFFB347),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Convex is not configured',
                        style: TextStyle(
                          color: Color(0xFFFFE7F2),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Build with:\n'
                    '--dart-define=CONVEX_URL=...\n'
                    '--dart-define=CONVEX_DEPLOY_KEY=...',
                    style: TextStyle(
                      color: Color(0xFFD9C5E9),
                      fontSize: 13,
                      height: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return BrandScaffold(
      title: 'OTP login (legacy)',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFFFF6AA7), Color(0xFFD71962)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66FF3E8D),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.sms_outlined,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sign in with phone OTP',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFE7F2),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Legacy phone-OTP flow. New accounts should prefer username/password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB59BC9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const BrandSectionHeader(
            label: 'PHONE NUMBER',
            icon: Icons.phone_outlined,
          ),
          BrandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _phoneController,
                  enabled: !_otpSent,
                  style: const TextStyle(color: Color(0xFFFFE7F2)),
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+94 70 123 4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    style: const TextStyle(color: Color(0xFFFFE7F2)),
                    decoration: const InputDecoration(
                      labelText: 'OTP code',
                      hintText: '6-digit code',
                      prefixIcon: Icon(Icons.password_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFFF3B5C),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFF3B5C),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _loading
                      ? null
                      : (_otpSent ? _verify : _requestOtp),
                  icon: Icon(
                    _otpSent
                        ? Icons.verified_user_outlined
                        : Icons.send_outlined,
                  ),
                  label: Text(
                    _otpSent ? 'Verify & sync contacts' : 'Send OTP',
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _otpSent = false;
                              _codeController.clear();
                              _error = null;
                            }),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit phone number'),
                  ),
                ],
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
