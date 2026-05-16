import 'package:hive/hive.dart';

class EmergencyEventLog {
  EmergencyEventLog({
    required this.id,
    required this.type,
    required this.timestampMs,
    required this.callAttempted,
    required this.smsAttempted,
    required this.locationIncluded,
  });

  final String id;
  final String type;
  final int timestampMs;
  final bool callAttempted;
  final bool smsAttempted;
  final bool locationIncluded;
}

class EmergencyEventLogAdapter extends TypeAdapter<EmergencyEventLog> {
  static const int typeIdConst = 2;

  @override
  int get typeId => typeIdConst;

  @override
  EmergencyEventLog read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final fieldCount = reader.readByte();
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return EmergencyEventLog(
      id: fields[0] as String,
      type: fields[1] as String,
      timestampMs: fields[2] as int,
      callAttempted: fields[3] as bool,
      smsAttempted: fields[4] as bool,
      locationIncluded: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, EmergencyEventLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.timestampMs)
      ..writeByte(3)
      ..write(obj.callAttempted)
      ..writeByte(4)
      ..write(obj.smsAttempted)
      ..writeByte(5)
      ..write(obj.locationIncluded);
  }
}
