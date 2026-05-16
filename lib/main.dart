import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'data/local/app_database.dart';
import 'features/contacts/domain/entities/emergency_contact.dart';
import 'features/emergency/domain/entities/emergency_event_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance();
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(EmergencyContactAdapter.typeIdConst)) {
    Hive.registerAdapter(EmergencyContactAdapter());
  }
  if (!Hive.isAdapterRegistered(EmergencyEventLogAdapter.typeIdConst)) {
    Hive.registerAdapter(EmergencyEventLogAdapter());
  }
  await Hive.openBox<EmergencyContact>(AppConstants.contactsBoxName);
  await Hive.openBox<EmergencyEventLog>(AppConstants.emergencyLogsBoxName);

  runApp(const ProviderScope(child: ProteqMeApp()));
}
