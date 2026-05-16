class Contact {
  const Contact({
    this.id,
    required this.name,
    required this.phone,
    required this.priority,
    this.language = 'en',
    this.convexId,
  });

  final int? id;
  final String name;
  final String phone;
  final int priority;
  final String language;
  final String? convexId;

  factory Contact.fromMap(Map<String, Object?> map) {
    return Contact(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      priority: map['priority'] as int,
      language: map['language'] as String? ?? 'en',
      convexId: map['convex_id'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'priority': priority,
        'language': language,
        'convex_id': convexId,
      };

  Contact copyWith({
    int? id,
    String? name,
    String? phone,
    int? priority,
    String? language,
    String? convexId,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      priority: priority ?? this.priority,
      language: language ?? this.language,
      convexId: convexId ?? this.convexId,
    );
  }
}
