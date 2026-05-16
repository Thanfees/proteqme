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

class _ProteqMeRootState extends State<_ProteqMeRoot> {
  bool _checkedSos = false;
  bool _sosActive = false;

  @override
  void initState() {
    super.initState();
    _refreshSosState();
  }

  Future<void> _refreshSosState() async {
    final active = await SosLoopDatasource().isActive();
    if (!mounted) return;
    setState(() {
      _sosActive = active;
      _checkedSos = true;
    });
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
        key: ValueKey(DateTime.now().millisecondsSinceEpoch),
      );
    }

    return Navigator(
      onGenerateRoute: (settings) {
        if (settings.name == AppRouter.launch || settings.name == null) {
          return AppRouter.onGenerateRoute(
            const RouteSettings(name: AppRouter.launch),
          );
        }
        return AppRouter.onGenerateRoute(settings);
      },
      initialRoute: AppRouter.launch,
    );
  }
}
