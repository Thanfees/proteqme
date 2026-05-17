import 'dart:async';

import 'package:flutter/material.dart';

import '../features/emergency/data/sos_loop_datasource.dart';
import '../features/emergency/presentation/emergency_overlay_screen.dart';
import 'router.dart';
import 'theme.dart';

class ProteqMeApp extends StatelessWidget {
  const ProteqMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProteqMe',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _ProteqMeRoot(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

class _ProteqMeRoot extends StatefulWidget {
  const _ProteqMeRoot();

  @override
  State<_ProteqMeRoot> createState() => _ProteqMeRootState();
}

class _ProteqMeRootState extends State<_ProteqMeRoot>
    with WidgetsBindingObserver {
  bool _checkedSos = false;
  bool _sosActive = false;
  Timer? _pollTimer;
  final _innerNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSosState();

    // Watch every 2s so when native voice detection triggers SOS the overlay
    // appears immediately — even if the user wasn't on a specific screen.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshSosState(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSosState();
    }
  }

  Future<void> _refreshSosState() async {
    try {
      final active = await SosLoopDatasource().isActive();
      if (!mounted) return;
      if (active != _sosActive || !_checkedSos) {
        setState(() {
          _sosActive = active;
          _checkedSos = true;
        });
      }
    } catch (_) {
      if (!_checkedSos && mounted) {
        setState(() => _checkedSos = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedSos) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_sosActive) {
      return EmergencyOverlayScreen(
        key: const ValueKey('proteqme-sos-overlay'),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Forward the back press to the nested navigator.
        final popped = await _innerNavKey.currentState?.maybePop() ?? false;
        if (!popped && context.mounted) {
          // At root — let the system handle it (exit app).
          Navigator.of(context).pop();
        }
      },
      child: Navigator(
        key: _innerNavKey,
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.launch || settings.name == null) {
            return AppRouter.onGenerateRoute(
              const RouteSettings(name: AppRouter.launch),
            );
          }
          return AppRouter.onGenerateRoute(settings);
        },
        initialRoute: AppRouter.launch,
      ),
    );
  }
}
