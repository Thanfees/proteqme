class EmergencyExecutionResult {
  const EmergencyExecutionResult({
    required this.callAttempted,
    required this.smsAttempted,
    required this.locationIncluded,
    required this.message,
  });

  final bool callAttempted;
  final bool smsAttempted;
  final bool locationIncluded;
  final String message;
}
