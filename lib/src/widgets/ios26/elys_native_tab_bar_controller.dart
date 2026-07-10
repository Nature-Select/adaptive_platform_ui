part of 'elys_native_tab_bar.dart';

class ElysNativeTabBarController {
  _ElysNativeTabBarState? _state;

  /// Updates the selected tab with a lightweight channel call instead of a
  /// full `setConfig` push.
  ///
  /// No-ops when [id] already matches the selection native currently shows,
  /// so callers may forward every Dart-side selection change unconditionally:
  /// echoes of native-initiated taps are dropped here.
  Future<void> setSelectedTab(String id) {
    return _state?._setSelectedTab(id) ?? Future.value();
  }

  Future<void> setInputActive(bool active) {
    return _state?._invoke('setInputActive', {'active': active}) ??
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
