part of 'elys_native_tab_bar.dart';

enum _ElysNativeSurfaceMode { tabBar, inputCollapsed, keyboard }

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

  bool _inputActive;
  double _keyboardInset = 0;
  Duration _animationDuration = const Duration(milliseconds: 250);

  _ElysNativeSurfaceMode get mode {
    if (_keyboardInset > 0) return _ElysNativeSurfaceMode.keyboard;
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
      _ElysNativeSurfaceMode.keyboard => _keyboardViewHeight(
        fullHeight: fullHeight,
      ),
      _ => barHeight,
    };
  }

  void setInputActive(bool active) {
    _inputActive = active;
  }

  void setKeyboard({
    required bool visible,
    required double inset,
    required Duration animationDuration,
  }) {
    _keyboardInset = visible ? inset : 0;
    _animationDuration = animationDuration;
  }

  double _keyboardViewHeight({required double fullHeight}) {
    return fullHeight;
  }
}
