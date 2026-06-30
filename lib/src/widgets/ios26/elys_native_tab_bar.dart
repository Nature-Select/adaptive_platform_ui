import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'elys_native_tab_bar_models.dart';
import 'elys_option_popover_models.dart';

export 'elys_native_tab_bar_models.dart';
export 'elys_option_popover_models.dart';

part 'elys_native_tab_bar_controller.dart';
part 'elys_native_tab_bar_surface.dart';

class ElysNativeTabBar extends StatefulWidget {
  const ElysNativeTabBar({
    super.key,
    this.controller,
    required this.leadingAction,
    required this.tabs,
    required this.selectedTabId,
    required this.inputActive,
    required this.inputConfig,
    required this.onTabSelected,
    this.onLeadingAction,
    this.onInputModeChanged,
    this.onInputTextChanged,
    this.onInputSubmitted,
    this.onInputSideAction,
    this.onInputAccessoryAction,
    this.onInputOptionTapped,
    this.onInputOptionsPresentationChanged,
    this.onKeyboardFrameChanged,
    this.onLayoutChanged,
    this.height,
  });

  final ElysNativeTabBarController? controller;
  final ElysBarAction leadingAction;
  final List<ElysBarTab> tabs;
  final String selectedTabId;
  final bool inputActive;
  final ElysInputConfig inputConfig;
  final ValueChanged<String> onTabSelected;
  final ValueChanged<ElysBarActionEvent>? onLeadingAction;
  final ValueChanged<bool>? onInputModeChanged;
  final ValueChanged<String>? onInputTextChanged;
  final ValueChanged<String>? onInputSubmitted;
  final ValueChanged<ElysBarActionEvent>? onInputSideAction;
  final ValueChanged<ElysBarActionEvent>? onInputAccessoryAction;
  final ValueChanged<ElysInputOptionEvent>? onInputOptionTapped;
  final ValueChanged<bool>? onInputOptionsPresentationChanged;
  final ValueChanged<ElysKeyboardFrameEvent>? onKeyboardFrameChanged;
  final ValueChanged<ElysBarLayoutEvent>? onLayoutChanged;
  final double? height;

  @override
  State<ElysNativeTabBar> createState() => _ElysNativeTabBarState();
}

class _ElysNativeTabBarState extends State<ElysNativeTabBar> {
  MethodChannel? _channel;
  String? _lastSignature;
  double? _intrinsicHeight;
  ElysBarLayoutEvent? _lastLayout;
  late final _ElysNativeSurfaceCoordinator _surface;

  bool get _isDark =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _surface = _ElysNativeSurfaceCoordinator(inputActive: widget.inputActive);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant ElysNativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.inputActive != widget.inputActive) {
      _updateSurface(() => _surface.setInputActive(widget.inputActive));
    }
    _syncConfigIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncConfigIfNeeded();
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      final barHeight = widget.height ?? _intrinsicHeight ?? 83;
      final mediaHeight = MediaQuery.sizeOf(context).height;
      final viewHeight = _surface.viewHeight(
        fullHeight: mediaHeight,
        barHeight: barHeight,
        layout: _lastLayout,
      );
      return AnimatedContainer(
        duration: _surface.animationDuration,
        curve: Curves.easeOutCubic,
        height: viewHeight,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: viewHeight,
          child: UiKitView(
            viewType: 'elys_platform_ui/tab_bar',
            creationParams: _config(),
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            },
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Map<String, Object?> _config() => {
    'leadingAction': widget.leadingAction.toMap(),
    'tabs': widget.tabs.map((tab) => tab.toMap()).toList(),
    'selectedTabId': widget.selectedTabId,
    'inputActive': widget.inputActive,
    'input': widget.inputConfig.toMap(),
    'isDark': _isDark,
  };

  String _signature() => _config().toString();

  void _onCreated(int id) {
    final channel = MethodChannel('elys_platform_ui/tab_bar_$id');
    _channel = channel;
    _lastSignature = _signature();
    channel.setMethodCallHandler(_onMethodCall);
    _requestIntrinsicSize();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    final args = call.arguments as Map?;
    switch (call.method) {
      case 'tabSelected':
        final id = args?['id'] as String?;
        if (id != null) widget.onTabSelected(id);
        break;
      case 'leadingActionTapped':
        widget.onLeadingAction?.call(ElysBarActionEvent(id: '${args?['id']}'));
        break;
      case 'inputModeChanged':
        final active = args?['active'] == true;
        _updateSurface(() => _surface.setInputActive(active));
        widget.onInputModeChanged?.call(active);
        break;
      case 'inputTextChanged':
        widget.onInputTextChanged?.call((args?['text'] as String?) ?? '');
        break;
      case 'inputSubmitted':
        widget.onInputSubmitted?.call((args?['text'] as String?) ?? '');
        break;
      case 'inputSideActionTapped':
        widget.onInputSideAction?.call(
          ElysBarActionEvent(
            id: '${args?['id']}',
            text: args?['text'] as String?,
          ),
        );
        break;
      case 'inputAccessoryTapped':
        widget.onInputAccessoryAction?.call(
          ElysBarActionEvent(
            id: '${args?['id']}',
            text: args?['text'] as String?,
          ),
        );
        break;
      case 'inputOptionTapped':
        widget.onInputOptionTapped?.call(
          ElysInputOptionEvent(
            id: '${args?['id']}',
            text: args?['text'] as String?,
          ),
        );
        break;
      case 'optionPresentationChanged':
        final active = args?['active'] == true;
        _updateSurface(() => _surface.setOptionPopoverActive(active));
        widget.onInputOptionsPresentationChanged?.call(active);
        break;
      case 'keyboardFrameChanged':
        _handleKeyboardFrameChanged(args);
        break;
      case 'layoutChanged':
        final event = ElysBarLayoutEvent.fromMap(args);
        if (mounted) {
          setState(() => _lastLayout = event);
        } else {
          _lastLayout = event;
        }
        widget.onLayoutChanged?.call(event);
        break;
    }
    return null;
  }

  void _handleKeyboardFrameChanged(Map? args) {
    final event = ElysKeyboardFrameEvent(
      height: (args?['height'] as num?)?.toDouble() ?? 0,
      visible: args?['visible'] == true,
      duration: (args?['duration'] as num?)?.toDouble() ?? 0,
    );
    final nextInset = event.visible ? event.height : 0.0;
    final nextDuration = event.duration > 0
        ? Duration(milliseconds: (event.duration * 1000).round())
        : const Duration(milliseconds: 250);
    if (mounted &&
        _updateSurface(
          () => _surface.setKeyboard(
            visible: event.visible,
            inset: nextInset,
            animationDuration: nextDuration,
          ),
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncConfigIfNeeded();
      });
    }
    widget.onKeyboardFrameChanged?.call(event);
  }

  Future<void> _syncConfigIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    final signature = _signature();
    if (_lastSignature == signature) return;
    _lastSignature = signature;
    await channel.invokeMethod('setConfig', _config());
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod(method, arguments);
  }

  Future<void> _requestIntrinsicSize() async {
    if (widget.height != null) return;
    final channel = _channel;
    if (channel == null) return;
    try {
      final size = await channel.invokeMethod<Map>('getIntrinsicSize');
      final height = (size?['height'] as num?)?.toDouble();
      if (!mounted || height == null || height <= 0) return;
      setState(() => _intrinsicHeight = height);
    } catch (_) {}
  }

  bool _updateSurface(VoidCallback update) {
    final before = _surface.snapshot;
    update();
    final after = _surface.snapshot;
    if (before == after) return false;
    if (mounted) setState(() {});
    return true;
  }
}
