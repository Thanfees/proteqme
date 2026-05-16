import '../entities/detection_event.dart';
import '../entities/listener_service_status.dart';

abstract class ListenerServiceRepository {
  Future<void> startService({
    required String primaryNumber,
    required List<String> allNumbers,
  });

  Future<void> stopService();

  Future<void> updatePrimaryNumber({
    required String primaryNumber,
    required List<String> allNumbers,
  });

  Future<ListenerServiceStatus> getServiceStatus();

  Stream<DetectionEvent> get events;
}
