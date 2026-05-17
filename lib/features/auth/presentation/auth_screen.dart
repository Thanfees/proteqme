import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/config/secrets.dart';
import '../../../core/widgets/brand_scaffold.dart';
import 'auth_session_provider.dart';

/// Tabbed sign-in / create-account screen.  The legacy OTP flow lives at
/// [AppRouter.otpLogin] behind a small link at the bottom.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  // Sign-in
  final _signinUserCtrl = TextEditingController();
  final _signinPwCtrl = TextEditingController();

  // Signup
  final _signupUserCtrl = TextEditingController();
  final _signupNameCtrl = TextEditingController();
  final _signupPwCtrl = TextEditingController();
  final _signupConfirmCtrl = TextEditingController();

  final _signinFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  bool _busy = false;

  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  @override
  void dispose() {
    _tabController.dispose();
    _signinUserCtrl.dispose();
    _signinPwCtrl.dispose();
    _signupUserCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupPwCtrl.dispose();
    _signupConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitSignin() async {
    if (_busy) return;
    if (!(_signinFormKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authSessionProvider.notifier).signin(
            username: _signinUserCtrl.text.trim().toLowerCase(),
            password: _signinPwCtrl.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.home,
        (_) => false,
      );
    } catch (e) {
      _showSnack(_extractMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitSignup() async {
    if (_busy) return;
    if (!(_signupFormKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authSessionProvider.notifier).signup(
            username: _signupUserCtrl.text.trim().toLowerCase(),
            password: _signupPwCtrl.text,
            displayName: _signupNameCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.home,
        (_) => false,
      );
    } catch (e) {
      _showSnack(_extractMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _extractMessage(Object error) {
    final raw = error.toString();
    // Convex errors come back as JSON wrapped in Exception("Convex HTTP 400: {...}").
    final marker = 'Server Error: ';
    final i = raw.indexOf(marker);
    if (i >= 0) return raw.substring(i + marker.length);
    // Strip any leading "Exception: " for tidier snackbars.
    final ex = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    return ex.length > 240 ? '${ex.substring(0, 240)}…' : ex;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (!Secrets.hasConvex) {
      return _notConfigured();
    }

    return BrandScaffold(
      title: 'ProteqMe account',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 88,
              height: 88,
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
                Icons.shield_moon_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sign in to ProteqMe',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFE7F2),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your account keeps your emergency contacts safe across devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB59BC9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          BrandCard(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFFF6AA7),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFFFFE7F2),
                  unselectedLabelColor: const Color(0xFFB59BC9),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  tabs: const [
                    Tab(text: 'Sign in'),
                    Tab(text: 'Create account'),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (_, _) {
                    return IndexedStack(
                      index: _tabController.index,
                      children: [
                        _buildSigninTab(),
                        _buildSignupTab(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pushNamed(AppRouter.otpLogin),
            icon: const Icon(Icons.sms_outlined, size: 16),
            label: const Text(
              'Use OTP login (legacy)',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSigninTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Form(
        key: _signinFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _signinUserCtrl,
              enabled: !_busy,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Color(0xFFFFE7F2)),
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signinPwCtrl,
              enabled: !_busy,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitSignin(),
              style: const TextStyle(color: Color(0xFFFFE7F2)),
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _submitSignin,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_outlined),
              label: Text(_busy ? 'Signing in…' : 'Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Form(
        key: _signupFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _signupUserCtrl,
              enabled: !_busy,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Color(0xFFFFE7F2)),
              decoration: const InputDecoration(
                labelText: 'Username',
                helperText: '3–20 chars · letters, digits, underscore',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Choose a username';
                if (!_usernameRegex.hasMatch(t)) {
                  return '3–20 chars, only letters/digits/_';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupNameCtrl,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Color(0xFFFFE7F2)),
              decoration: const InputDecoration(
                labelText: 'Display name',
                helperText: 'Used in every SOS SMS so contacts know it’s you',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupPwCtrl,
              enabled: !_busy,
              obscureText: true,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Color(0xFFFFE7F2)),
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least 6 characters',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a password';
                if (v.length < 6) return 'Password must be at least 6 chars';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupConfirmCtrl,
              enabled: !_busy,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitSignup(),
              style: const TextStyle(color: Color(0xFFFFE7F2)),
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirm your password';
                if (v != _signupPwCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _submitSignup,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_outlined),
              label: Text(_busy ? 'Creating…' : 'Create account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notConfigured() {
    return BrandScaffold(
      title: 'ProteqMe account',
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
                    Icon(Icons.cloud_off_outlined, color: Color(0xFFFFB347)),
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
}
