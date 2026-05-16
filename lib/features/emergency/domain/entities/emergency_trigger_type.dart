enum EmergencyTriggerType {
  voiceTrigger('voice_trigger'),
  manualTrigger('manual_trigger'),
  emergencyButton('emergency_button');

  const EmergencyTriggerType(this.value);

  final String value;
}
