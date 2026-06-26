import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../adaptive_scaffold.dart';

/// Elys Native iOS tab bar with center floating action button
/// Uses native UITabBar platform view with a floating center button
class ElysNativeTabBar extends StatefulWidget {
  const ElysNativeTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    this.onCenterButtonPressed,
    this.centerButtonConfig,
    this.tint,
    this.unselectedItemTint,
    this.backgroundColor,
    this.height,
  });

  /// Navigation destinations for the tab bar
  final List<AdaptiveNavigationDestination> destinations;

  /// Currently selected tab index
  final int selectedIndex;

  /// Callback when a tab is tapped
  final ValueChanged<int> onTap;

  /// Callback when center button is pressed
  final VoidCallback? onCenterButtonPressed;

  /// Configuration for the center floating button
  final ElysCenterButtonConfig? centerButtonConfig;

  /// Tint color for selected items
  final Color? tint;

  /// Tint color for unselected items
  final Color? unselectedItemTint;

  /// Background color for the tab bar
  final Color? backgroundColor;

  /// Height for the tab bar (includes floating button)
  final double? height;

  @override
  State<ElysNativeTabBar> createState() => _ElysNativeTabBarState();
}

/// Configuration for the center floating action button
class ElysCenterButtonConfig {
  const ElysCenterButtonConfig({
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    this.accessibilityIdentifier,
  });

  /// Asset path for the button icon (e.g. "assets/icons/plus.png")
  final String icon;

  /// Background color of the button (defaults to system blue)
  final Color? backgroundColor;

  /// Icon/tint color of the button (defaults to white)
  final Color? iconColor;

  /// Native accessibility identifier for UI automation.
  final String? accessibilityIdentifier;
}

class _ElysNativeTabBarState extends State<ElysNativeTabBar> {
  MethodChannel? _channel;
  int? _lastIndex;
  int? _lastBg;
  bool? _lastIsDark;
  double? _intrinsicHeight;
  List<String>? _lastLabels;
  List<String>? _lastIcons;
  List<String>? _lastSelectedIcons;
  List<String?>? _lastAccessibilityIdentifiers;
  List<int?>? _lastBadgeCounts;
  ElysCenterButtonConfig? _lastCenterButtonConfig;

  bool get _isDark =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  @override
  void didUpdateWidget(covariant ElysNativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
    _syncPropsToNativeIfNeeded();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  int _colorToARGB(Color color) {
    // Resolve CupertinoDynamicColor if needed
    Color resolvedColor = color;
    if (color is CupertinoDynamicColor) {
      final brightness = MediaQuery.platformBrightnessOf(context);
      resolvedColor = brightness == Brightness.dark
          ? color.darkColor
          : color.color;
    }

    return ((resolvedColor.a * 255.0).round() & 0xff) << 24 |
        ((resolvedColor.r * 255.0).round() & 0xff) << 16 |
        ((resolvedColor.g * 255.0).round() & 0xff) << 8 |
        ((resolvedColor.b * 255.0).round() & 0xff);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      final labels = widget.destinations.map((e) => e.label).toList();
      final icons = widget.destinations.map((e) {
        final icon = e.icon;
        if (icon is String) return icon;
        return '';
      }).toList();
      final selectedIcons = widget.destinations.map((e) {
        final selectedIcon = e.selectedIcon ?? e.icon;
        if (selectedIcon is String) return selectedIcon;
        return '';
      }).toList();

      final badgeCounts = widget.destinations.map((e) => e.badgeCount).toList();
      final accessibilityIdentifiers = widget.destinations
          .map((e) => e.accessibilityIdentifier)
          .toList();

      final creationParams = <String, dynamic>{
        'labels': labels,
        'icons': icons,
        'selectedIcons': selectedIcons,
        'accessibilityIdentifiers': accessibilityIdentifiers,
        'badgeCounts': badgeCounts,
        'selectedIndex': widget.selectedIndex,
        'isDark': _isDark,
        if (widget.backgroundColor != null)
          'backgroundColor': _colorToARGB(widget.backgroundColor!),
        if (widget.centerButtonConfig != null)
          'centerButton': {
            'icon': widget.centerButtonConfig!.icon,
            'accessibilityIdentifier':
                widget.centerButtonConfig!.accessibilityIdentifier,
          },
      };

      final platformView = UiKitView(
        viewType: 'elys_platform_ui/tab_bar',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
        },
      );

      final h = widget.height ?? _intrinsicHeight ?? 78.0;
      return SizedBox(height: h, child: platformView);
    }

    // Fallback for non-iOS
    return SizedBox(
      height: widget.height ?? 50,
      child: Container(
        color:
            widget.backgroundColor ??
            CupertinoColors.systemBackground.resolveFrom(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            widget.destinations.length,
            (index) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => widget.onTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.circle,
                    color: index == widget.selectedIndex
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.systemGrey,
                  ),
                  Text(
                    widget.destinations[index].label,
                    style: TextStyle(
                      fontSize: 10,
                      color: index == widget.selectedIndex
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onCreated(int id) {
    final ch = MethodChannel('elys_platform_ui/tab_bar_$id');
    _channel = ch;
    ch.setMethodCallHandler(_onMethodCall);
    _lastIndex = widget.selectedIndex;
    _lastBg = widget.backgroundColor != null
        ? _colorToARGB(widget.backgroundColor!)
        : null;
    _lastIsDark = _isDark;
    _lastCenterButtonConfig = widget.centerButtonConfig;
    _requestIntrinsicSize();
    _cacheItems();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'valueChanged') {
      final args = call.arguments as Map?;
      final idx = (args?['index'] as num?)?.toInt();
      if (idx != null) {
        widget.onTap(idx);
        _lastIndex = idx;
      }
    } else if (call.method == 'onCenterButtonPressed') {
      widget.onCenterButtonPressed?.call();
    }
    return null;
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;

    final idx = widget.selectedIndex;
    final bg = widget.backgroundColor != null
        ? _colorToARGB(widget.backgroundColor!)
        : null;

    if (_lastIndex != idx) {
      await ch.invokeMethod('setSelectedIndex', {'index': idx});
      _lastIndex = idx;
    }

    if (_lastBg != bg && bg != null) {
      await ch.invokeMethod('setStyle', {'backgroundColor': bg});
      _lastBg = bg;
    }

    // Items update
    final labels = widget.destinations.map((e) => e.label).toList();
    final icons = widget.destinations.map((e) {
      final icon = e.icon;
      if (icon is String) return icon;
      return '';
    }).toList();
    final selectedIcons = widget.destinations.map((e) {
      final selectedIcon = e.selectedIcon ?? e.icon;
      if (selectedIcon is String) return selectedIcon;
      return '';
    }).toList();
    final accessibilityIdentifiers = widget.destinations
        .map((e) => e.accessibilityIdentifier)
        .toList();
    final badgeCounts = widget.destinations.map((e) => e.badgeCount).toList();

    // Check if labels changed (requires full rebuild) or item count changed
    final labelsChanged = _lastLabels?.join('|') != labels.join('|');
    final itemCountChanged = _lastIcons?.length != icons.length;
    final identifiersChanged =
        _lastAccessibilityIdentifiers?.join('|') !=
        accessibilityIdentifiers.join('|');

    if (labelsChanged || itemCountChanged || identifiersChanged) {
      // Full rebuild needed
      await ch.invokeMethod('setItems', {
        'labels': labels,
        'icons': icons,
        'selectedIcons': selectedIcons,
        'accessibilityIdentifiers': accessibilityIdentifiers,
        'badgeCounts': badgeCounts,
        'selectedIndex': widget.selectedIndex,
      });
      _lastLabels = List.from(labels);
      _lastIcons = List.from(icons);
      _lastSelectedIcons = List.from(selectedIcons);
      _lastAccessibilityIdentifiers = List.from(accessibilityIdentifiers);
      _lastBadgeCounts = List.from(badgeCounts);
      _requestIntrinsicSize();
    } else {
      // Check for individual icon changes - update only changed icons
      for (int i = 0; i < icons.length; i++) {
        final iconChanged =
            _lastIcons != null &&
            i < _lastIcons!.length &&
            _lastIcons![i] != icons[i];
        final selectedIconChanged =
            _lastSelectedIcons != null &&
            i < _lastSelectedIcons!.length &&
            _lastSelectedIcons![i] != selectedIcons[i];

        if (iconChanged || selectedIconChanged) {
          await ch.invokeMethod('updateItemIcon', {
            'index': i,
            if (iconChanged) 'icon': icons[i],
            if (selectedIconChanged) 'selectedIcon': selectedIcons[i],
          });
        }
      }
      _lastIcons = List.from(icons);
      _lastSelectedIcons = List.from(selectedIcons);
    }

    // Center button update
    if (_lastCenterButtonConfig?.icon != widget.centerButtonConfig?.icon ||
        _lastCenterButtonConfig?.accessibilityIdentifier !=
            widget.centerButtonConfig?.accessibilityIdentifier) {
      if (widget.centerButtonConfig != null) {
        await ch.invokeMethod('updateCenterButton', {
          'icon': widget.centerButtonConfig!.icon,
          'accessibilityIdentifier':
              widget.centerButtonConfig!.accessibilityIdentifier,
        });
      }
      _lastCenterButtonConfig = widget.centerButtonConfig;
    }

    // Badge counts update
    final currentBadgeCounts = widget.destinations
        .map((e) => e.badgeCount)
        .toList();
    if (_lastBadgeCounts?.join('|') != currentBadgeCounts.join('|')) {
      await ch.invokeMethod('setBadgeCounts', {
        'badgeCounts': currentBadgeCounts,
      });
      _lastBadgeCounts = List.from(currentBadgeCounts);
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      await ch.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }
  }

  void _cacheItems() {
    _lastLabels = widget.destinations.map((e) => e.label).toList();
    _lastIcons = widget.destinations.map((e) {
      final icon = e.icon;
      if (icon is String) return icon;
      return '';
    }).toList();
    _lastSelectedIcons = widget.destinations.map((e) {
      final selectedIcon = e.selectedIcon ?? e.icon;
      if (selectedIcon is String) return selectedIcon;
      return '';
    }).toList();
    _lastAccessibilityIdentifiers = widget.destinations
        .map((e) => e.accessibilityIdentifier)
        .toList();
    _lastBadgeCounts = widget.destinations.map((e) => e.badgeCount).toList();
  }

  Future<void> _requestIntrinsicSize() async {
    if (widget.height != null) return;
    final ch = _channel;
    if (ch == null) return;
    try {
      final size = await ch.invokeMethod<Map>('getIntrinsicSize');
      final h = (size?['height'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        if (h != null && h > 0) _intrinsicHeight = h;
      });
    } catch (_) {}
  }
}
