import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/domain/entities/emergency_contact.dart';
import '../domain/entities/emergency_event_log.dart';
import '../domain/entities/emergency_execution_result.dart';
import '../domain/entities/emergency_trigger_type.dart';
import '../domain/usecases/execute_emergency_workflow_usecase.dart';
import '../domain/usecases/watch_emergency_logs_usecase.dart';

class EmergencyControllerState {
  const EmergencyControllerState({
    required this.loading,
    this.lastResult,
    this.error,
  });

  const EmergencyControllerState.initial()
    : loading = false,
      lastResult = null,
      error = null;

  final bool loading;
  final EmergencyExecutionResult? lastResult;
  final String? error;

  EmergencyControllerState copyWith({
    bool? loading,
    EmergencyExecutionResult? lastResult,
    String? error,
    bool clearError = false,
  }) {
    return EmergencyControllerState(
      loading: loading ?? this.loading,
      lastResult: lastResult ?? this.lastResult,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class EmergencyController extends Notifier<EmergencyControllerState> {
  late final ExecuteEmergencyWorkflowUseCase _execute;

  @override
  EmergencyControllerState build() {
    _execute = ref.read(executeEmergencyWorkflowUseCaseProvider);
    return const EmergencyControllerState.initial();
  }

  Future<EmergencyExecutionResult?> trigger({
    required EmergencyTriggerType triggerType,
    required EmergencyContact? primaryContact,
    required List<EmergencyContact> contacts,
    required bool callPermissionGranted,
    required bool smsPermissionGranted,
    required bool locationPermissionGranted,
  }) async {
    if (contacts.isEmpty) {
      state = state.copyWith(error: 'Add at least one emergency contact.');
      return null;
    }

    if (primaryContact == null) {
      state = state.copyWith(
        error: 'Select a primary emergency contact first.',
      );
      return null;
    }

    state = state.copyWith(loading: true, clearError: true);

    try {
      final allNumbers = contacts
          .map((contact) => contact.phone.trim())
          .where((number) => number.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final result = await _execute(
        triggerType: triggerType,
        primaryNumber: primaryContact.phone,
        allNumbers: allNumbers,
        contacts: contacts,
        callPermissionGranted: callPermissionGranted,
        smsPermissionGranted: smsPermissionGranted,
        locationPermissionGranted: locationPermissionGranted,
      );

      state = state.copyWith(loading: false, lastResult: result);
      return result;
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: 'Emergency trigger failed: $error',
      );
      return null;
    }
  }
}

final emergencyControllerProvider =
    NotifierProvider<EmergencyController, EmergencyControllerState>(
      EmergencyController.new,
    );

final emergencyLogsProvider = StreamProvider<List<EmergencyEventLog>>(
  (ref) => ref.watch(watchEmergencyLogsUseCaseProvider).call(),
);
