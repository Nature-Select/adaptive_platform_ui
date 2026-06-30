part of 'elys_native_tab_bar.dart';

enum _ElysNativeSurfaceMode { tabBar, inputCollapsed, keyboard, optionPopover }

class _ElysNativeSurfaceSnapshot {
  const _ElysNativeSurfaceSnapshot({
    required this.mode,
    required this.keyboardInset,
    required this.animationDuration,
  });

  final _ElysNativeSurfaceMode mode;
  final double keyboardInset;
  final Duration animationDuration;

  @override
  bool operator ==(Object other) {
    return other is _ElysNativeSurfaceSnapshot &&
        other.mode == mode &&
        other.keyboardInset == keyboardInset &&
        other.animationDuration == animationDuration;
  }

  @override
  int get hashCode => Object.hash(mode, keyboardInset, animationDuration);
}

class _ElysNativeSurfaceCoordinator {
  _ElysNativeSurfaceCoordinator({required bool inputActive})
    : _inputActive = inputActive;

  static const _fallbackKeyboardInputHeight = 120.0;
  static const _inputKeyboardGap = 2.0;

  bool _inputActive;
  bool _optionPopoverActive = false;
  double _keyboardInset = 0;
  Duration _animationDuration = const Duration(milliseconds: 250);

  _ElysNativeSurfaceMode get mode {
    if (_keyboardInset > 0) return _ElysNativeSurfaceMode.keyboard;
    if (_optionPopoverActive) return _ElysNativeSurfaceMode.optionPopover;
    if (_inputActive) return _ElysNativeSurfaceMode.inputCollapsed;
    return _ElysNativeSurfaceMode.tabBar;
  }

  Duration get animationDuration => _animationDuration;

  _ElysNativeSurfaceSnapshot get snapshot => _ElysNativeSurfaceSnapshot(
    mode: mode,
    keyboardInset: _keyboardInset,
    animationDuration: _animationDuration,
  );

  double viewHeight({
    required double fullHeight,
    required double barHeight,
    required ElysBarLayoutEvent? layout,
  }) {
    return switch (mode) {
      _ElysNativeSurfaceMode.optionPopover => fullHeight,
      _ElysNativeSurfaceMode.keyboard => _keyboardViewHeight(
        fullHeight: fullHeight,
        layout: layout,
      ),
      _ => barHeight,
    };
  }

  void setInputActive(bool active) {
    _inputActive = active;
    if (!active) _optionPopoverActive = false;
  }

  void setOptionPopoverActive(bool active) {
    _optionPopoverActive = active;
    _animationDuration = const Duration(milliseconds: 220);
  }

  void setKeyboard({
    required bool visible,
    required double inset,
    required Duration animationDuration,
  }) {
    _keyboardInset = visible ? inset : 0;
    _animationDuration = animationDuration;
  }

  double _keyboardViewHeight({
    required double fullHeight,
    required ElysBarLayoutEvent? layout,
  }) {
    final nextHeight = _inputHeight(layout) + _inputKeyboardGap;
    return nextHeight.clamp(0, fullHeight).toDouble();
  }

  double _inputHeight(ElysBarLayoutEvent? layout) {
    final height = layout?.inputFrame.height ?? 0;
    return height > 0 ? height : _fallbackKeyboardInputHeight;
  }
}
