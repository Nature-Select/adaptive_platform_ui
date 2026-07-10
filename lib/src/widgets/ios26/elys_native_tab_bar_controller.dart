part of 'elys_native_tab_bar.dart';

class ElysNativeTabBarController {
  _ElysNativeTabBarState? _state;

  Future<void> setInputActive(bool active) {
    return _state?._invoke('setInputActive', {'active': active}) ??
        Future.value();
  }

  /// 以原生 UIView 动画将整条 bar 平移出/回屏幕底部。
  ///
  /// 动画完全在原生侧执行，不经过 Flutter 帧循环，平台视图的尺寸与
  /// Flutter 布局保持不变，因此不会触发 Scaffold/MediaQuery 的布局连锁，
  /// 也没有平台视图逐帧 resize 的开销。隐藏期间 bar 区域的点击会穿透给
  /// Flutter 内容。
  ///
  /// 业务侧做显隐请优先用本方法，不要用 SizeTransition/AnimatedContainer
  /// 之类改变尺寸的动画包裹本组件；若确需在 Flutter 侧自行过渡，用
  /// Transform.translate 平移出屏，避免任何尺寸变化。
  Future<void> setBarHidden(bool hidden, {bool animated = true}) {
    return _state?._invoke('setBarHidden', {
          'hidden': hidden,
          'animated': animated,
        }) ??
        Future.value();
  }

  Future<void> setInputText(String text) {
    return _state?._invoke('setInputText', {'text': text}) ?? Future.value();
  }

  Future<void> focusInput() {
    return _state?._invoke('focusInput') ?? Future.value();
  }

  Future<void> blurInput() {
    return _state?._invoke('blurInput') ?? Future.value();
  }

  Future<void> updateInputOption(ElysInputOption item) {
    return _state?._invoke('updateInputOption', item.toMap()) ?? Future.value();
  }

  Future<void> updateInputPrefix(ElysInputPrefix? prefix) {
    return _state?._invoke(
          'updateInputPrefix',
          {'prefix': prefix?.toMap()},
        ) ??
        Future.value();
  }

  void _attach(_ElysNativeTabBarState state) => _state = state;

  void _detach(_ElysNativeTabBarState state) {
    if (_state == state) _state = null;
  }
}
