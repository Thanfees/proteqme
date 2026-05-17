class ListenerServiceStatus {
  const ListenerServiceStatus({
    required this.running,
    required this.cooldownRemaining,
    this.userWantsListening = false,
    this.primaryNumber = '',
    this.allNumbers = const [],
  });

  final bool running;
  final int cooldownRemaining;
  final bool userWantsListening;
  final String primaryNumber;
  final List<String> allNumbers;
}
