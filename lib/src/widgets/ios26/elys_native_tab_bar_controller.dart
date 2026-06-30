part of 'elys_native_tab_bar.dart';

class ElysNativeTabBarController {
  _ElysNativeTabBarState? _state;

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

  void _attach(_ElysNativeTabBarState state) => _state = state;

  void _detach(_ElysNativeTabBarState state) {
    if (_state == state) _state = null;
  }
}
