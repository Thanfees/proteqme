class ListenerServiceStatus {
  const ListenerServiceStatus({
    required this.running,
    required this.cooldownRemaining,
  });

  final bool running;
  final int cooldownRemaining;
}
