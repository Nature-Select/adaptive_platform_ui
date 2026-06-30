class ElysInputOption {
  const ElysInputOption({
    required this.id,
    required this.icon,
    required this.title,
    this.enabled = true,
    this.accessibilityLabel,
  });

  final String id;
  final String icon;
  final String title;
  final bool enabled;
  final String? accessibilityLabel;

  Map<String, Object?> toMap() => {
    'id': id,
    'icon': icon,
    'title': title,
    'enabled': enabled,
    if (accessibilityLabel != null) 'accessibilityLabel': accessibilityLabel,
  };
}

class ElysInputOptionEvent {
  const ElysInputOptionEvent({required this.id, this.text});

  final String id;
  final String? text;
}
