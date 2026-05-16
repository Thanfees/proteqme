import '../../../contacts/domain/entities/emergency_contact.dart';
import '../entities/emergency_event_log.dart';
import '../entities/emergency_execution_result.dart';
import '../entities/emergency_trigger_type.dart';

abstract class EmergencyRepository {
  Future<EmergencyExecutionResult> executeWorkflow({
    required EmergencyTriggerType triggerType,
    required String primaryNumber,
    required List<String> allNumbers,
    required List<EmergencyContact> contacts,
    required bool callPermissionGranted,
    required bool smsPermissionGranted,
    required bool locationPermissionGranted,
  });

  Stream<List<EmergencyEventLog>> watchLogs();
}
