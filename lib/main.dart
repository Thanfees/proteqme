import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'background/emergency_service.dart';
import 'data/local/app_database.dart';
import 'data/repositories/sos_repository.dart';
import 'sync/convex_sync_worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;

  final sosRepo = SosRepository();
  final sosActive = await sosRepo.isActive();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('sos_active_cache', sosActive);

  await EmergencyService.instance.initialize();

  if (sosActive) {
    await EmergencyService.instance.resumeIfActive();
  }

  final bootstrap = await resolveBootstrap();
  final effectiveBootstrap = AppBootstrap(
    sosActive: sosActive,
    initialRoute: bootstrap.initialRoute,
  );

  final syncWorker = ConvexSyncWorker();
  await syncWorker.start();

  runApp(ProteqMeApp(
    sosActive: effectiveBootstrap.sosActive,
    initialRoute: effectiveBootstrap.initialRoute,
  ));
}
