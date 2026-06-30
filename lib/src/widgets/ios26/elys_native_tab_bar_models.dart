import 'elys_option_popover_models.dart';

class ElysBarAction {
  const ElysBarAction({
    required this.id,
    required this.icon,
    this.label,
    this.badgeCount,
  });

  final String id;
  final String icon;
  final String? label;
  final int? badgeCount;

  Map<String, Object?> toMap() => {
    'id': id,
    'icon': icon,
    if (label != null) 'accessibilityLabel': label,
    if (badgeCount != null) 'badgeCount': badgeCount,
  };
}

class ElysBarTab {
  const ElysBarTab({
    required this.id,
    required this.icon,
    this.selectedIcon,
    this.badgeCount,
    this.label,
  });

  final String id;
  final String icon;
  final String? selectedIcon;
  final int? badgeCount;
  final String? label;

  Map<String, Object?> toMap() => {
    'id': id,
    'icon': icon,
    if (selectedIcon != null) 'selectedIcon': selectedIcon,
    if (badgeCount != null) 'badgeCount': badgeCount,
    if (label != null) 'accessibilityLabel': label,
  };
}

class ElysInputConfig {
  const ElysInputConfig({
    this.text = '',
    this.placeholder = '',
    this.sideAction,
    this.leadingAction,
    this.collapsedTrailingAction,
    this.expandedTrailingAction,
    this.optionItems = const <ElysInputOption>[],
  });

  final String text;
  final String placeholder;
  final ElysBarAction? sideAction;
  final ElysBarAction? leadingAction;
  final ElysBarAction? collapsedTrailingAction;
  final ElysBarAction? expandedTrailingAction;
  final List<ElysInputOption> optionItems;

  Map<String, Object?> toMap() => {
    'text': text,
    'placeholder': placeholder,
    if (sideAction != null) 'sideAction': sideAction!.toMap(),
    if (leadingAction != null) 'leadingAction': leadingAction!.toMap(),
    if (collapsedTrailingAction != null)
      'collapsedTrailingAction': collapsedTrailingAction!.toMap(),
    if (expandedTrailingAction != null)
      'expandedTrailingAction': expandedTrailingAction!.toMap(),
    if (optionItems.isNotEmpty)
      'optionItems': optionItems.map((item) => item.toMap()).toList(),
  };
}

class ElysBarActionEvent {
  const ElysBarActionEvent({required this.id, this.text});

  final String id;
  final String? text;
}

class ElysKeyboardFrameEvent {
  const ElysKeyboardFrameEvent({
    required this.height,
    required this.visible,
    required this.duration,
  });

  final double height;
  final bool visible;
  final double duration;
}

class ElysBarRect {
  const ElysBarRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory ElysBarRect.fromMap(Map? map) {
    return ElysBarRect(
      x: (map?['x'] as num?)?.toDouble() ?? 0,
      y: (map?['y'] as num?)?.toDouble() ?? 0,
      width: (map?['width'] as num?)?.toDouble() ?? 0,
      height: (map?['height'] as num?)?.toDouble() ?? 0,
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;
}

class ElysBarLayoutEvent {
  const ElysBarLayoutEvent({
    required this.mode,
    required this.platformWidth,
    required this.platformHeight,
    required this.inputFrame,
    required this.keyboardHeight,
    required this.keyboardVisible,
    required this.animationDuration,
  });

  factory ElysBarLayoutEvent.fromMap(Map? map) {
    return ElysBarLayoutEvent(
      mode: (map?['mode'] as String?) ?? 'tabBar',
      platformWidth: (map?['platformWidth'] as num?)?.toDouble() ?? 0,
      platformHeight: (map?['platformHeight'] as num?)?.toDouble() ?? 0,
      inputFrame: ElysBarRect.fromMap(map?['inputFrame'] as Map?),
      keyboardHeight: (map?['keyboardHeight'] as num?)?.toDouble() ?? 0,
      keyboardVisible: map?['keyboardVisible'] == true,
      animationDuration: (map?['animationDuration'] as num?)?.toDouble() ?? 0,
    );
  }

  final String mode;
  final double platformWidth;
  final double platformHeight;
  final ElysBarRect inputFrame;
  final double keyboardHeight;
  final bool keyboardVisible;
  final double animationDuration;

  bool get inputActive => mode != 'tabBar';
}
