import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import 'elys_flutter_interaction_dock.dart';
import 'elys_tab_bar_demo_content.dart';

class ElysTabBarPlatformViewDemoPage extends StatefulWidget {
  const ElysTabBarPlatformViewDemoPage({super.key});

  @override
  State<ElysTabBarPlatformViewDemoPage> createState() =>
      _ElysTabBarPlatformViewDemoPageState();
}

class _ElysTabBarPlatformViewDemoPageState
    extends State<ElysTabBarPlatformViewDemoPage> {
  static const _home = 'assets/elys_tab_bar/home.png';
  static const _homeSelected = 'assets/elys_tab_bar/home_selected.png';
  static const _chat = 'assets/elys_tab_bar/chat.png';
  static const _chatSelected = 'assets/elys_tab_bar/chat_selected.png';
  static const _map = 'assets/elys_tab_bar/map.png';
  static const _mapSelected = 'assets/elys_tab_bar/map_selected.png';
  static const _profile = 'assets/elys_tab_bar/profile.png';
  static const _profileSelected = 'assets/elys_tab_bar/profile_selected.png';
  static const _inputMore = 'assets/elys_tab_bar/input_more.png';
  static const _inputVoice = 'assets/elys_tab_bar/input_voice.png';
  static const _inputSend = 'assets/elys_tab_bar/input_send.png';
  static const _startInput = bool.fromEnvironment(
    'ELYS_START_INPUT',
    defaultValue: false,
  );
  static const _autoFocusInput = bool.fromEnvironment(
    'ELYS_AUTO_FOCUS',
    defaultValue: false,
  );
  static const _initialInputText = String.fromEnvironment(
    'ELYS_INITIAL_INPUT_TEXT',
  );

  String _selectedTabId = 'library';
  String _inputText = '';
  bool _inputActive = false;
  String _lastEvent = 'Ready';
  int _chatBadge = 3;
  int _flutterTestTapCount = 0;
  bool _photoOptionEnabled = false;
  ElysBarLayoutEvent? _barLayout;
  final _barController = ElysNativeTabBarController();

  @override
  void initState() {
    super.initState();
    _inputActive = _startInput;
    _inputText = _initialInputText.replaceAll(r'\n', '\n');
    if (_startInput && _autoFocusInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInputForTest());
    }
  }

  Future<void> _focusInputForTest() async {
    for (final delay in const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 700),
      Duration(milliseconds: 1200),
      Duration(milliseconds: 1800),
      Duration(milliseconds: 2600),
    ]) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      await _barController.focusInput();
    }
  }

  List<ElysBarTab> get _tabs => [
    const ElysBarTab(id: 'library', icon: _home, selectedIcon: _homeSelected),
    ElysBarTab(
      id: 'messages',
      icon: _chat,
      selectedIcon: _chatSelected,
      badgeCount: _chatBadge,
    ),
    const ElysBarTab(id: 'map', icon: _map, selectedIcon: _mapSelected),
    const ElysBarTab(
      id: 'profile',
      icon: _profile,
      selectedIcon: _profileSelected,
    ),
  ];

  ElysBarTab get _selectedTab {
    return _tabs.firstWhere(
      (tab) => tab.id == _selectedTabId,
      orElse: () => _tabs.first,
    );
  }

  ElysBarAction get _inputSideAction {
    final tab = _selectedTab;
    return ElysBarAction(
      id: tab.id,
      icon: tab.selectedIcon ?? tab.icon,
      badgeCount: tab.badgeCount,
    );
  }

  List<ElysInputOption> get _inputOptions => [
    const ElysInputOption(id: 'camera', icon: _map, title: '相机'),
    ElysInputOption(
      id: 'photo',
      icon: _homeSelected,
      title: '照片',
      enabled: _photoOptionEnabled,
    ),
    const ElysInputOption(
      id: 'sticker',
      icon: _profileSelected,
      title: '贴纸',
      showsSeparatorAfter: true,
    ),
    const ElysInputOption(id: 'audio', icon: _inputVoice, title: '音频'),
    const ElysInputOption(id: 'store', icon: _chatSelected, title: '商店'),
    const ElysInputOption(id: 'travel', icon: _mapSelected, title: '携程旅行'),
  ];

  Future<void> _togglePhotoOption() async {
    final enabled = !_photoOptionEnabled;
    setState(() {
      _photoOptionEnabled = enabled;
      _lastEvent = enabled ? 'photo option enabled' : 'photo option disabled';
    });
    await _barController.updateInputOption(
      ElysInputOption(
        id: 'photo',
        icon: _homeSelected,
        title: '照片',
        enabled: enabled,
      ),
    );
  }

  void _recordFlutterTestTap(String source) {
    setState(() {
      _flutterTestTapCount++;
      _lastEvent = 'flutter $source: $_flutterTestTapCount';
    });
  }

  void _dismissKeyboardFromFlutterSurface([Offset? globalPosition]) {
    final layout = _barLayout;
    if (!_inputActive || layout?.keyboardVisible != true) return;
    if (globalPosition != null &&
        _isInsideNativeInput(layout!, globalPosition)) {
      return;
    }
    unawaited(_barController.blurInput());
  }

  bool _isInsideNativeInput(ElysBarLayoutEvent layout, Offset globalPosition) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = layout.keyboardVisible ? layout.keyboardHeight : 0.0;
    final possiblePlatformTops = <double>{
      screenHeight - layout.platformHeight,
      screenHeight - keyboardHeight - layout.platformHeight,
      screenHeight + keyboardHeight - layout.platformHeight,
    };
    final input = layout.inputFrame;
    return possiblePlatformTops.any((platformTop) {
      final inputRect = Rect.fromLTWH(
        input.x,
        platformTop + input.y,
        input.width,
        input.height,
      ).inflate(32);
      return inputRect.contains(globalPosition);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isIOS26OrHigher()) {
      return AdaptiveScaffold(
        body: Center(
          child: Text('Requires iOS 26+. ${PlatformInfo.platformDescription}'),
        ),
      );
    }

    return CupertinoPageScaffold(
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (event) =>
            _dismissKeyboardFromFlutterSurface(event.position),
        child: NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            _dismissKeyboardFromFlutterSurface();
            return false;
          },
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 260,
                child: ElysDemoBackdrop(),
              ),
              SafeArea(
                bottom: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _inputActive
                      ? ElysDemoInputPage(
                          text: _inputText,
                          testTapCount: _flutterTestTapCount,
                          onPrimaryTestPressed: () =>
                              _recordFlutterTestTap('primary'),
                          onSecondaryTestPressed: () =>
                              _recordFlutterTestTap('secondary'),
                        )
                      : ElysDemoTabPage(
                          selectedTabId: _selectedTabId,
                          inputActive: _inputActive,
                          inputText: _inputText,
                          lastEvent: _lastEvent,
                          onBadgePressed: () => setState(() => _chatBadge++),
                          onOptionTogglePressed: _togglePhotoOption,
                          optionEnabled: _photoOptionEnabled,
                        ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ElysNativeTabBar(
                  controller: _barController,
                  leadingAction: const ElysBarAction(id: 'input', icon: _map),
                  tabs: _tabs,
                  selectedTabId: _selectedTabId,
                  inputActive: _inputActive,
                  inputConfig: ElysInputConfig(
                    text: _inputText,
                    placeholder: '输入任何内容...',
                    sideAction: _inputSideAction,
                    leadingAction: const ElysBarAction(
                      id: 'more',
                      icon: _inputMore,
                    ),
                    collapsedTrailingAction: const ElysBarAction(
                      id: 'voice',
                      icon: _inputVoice,
                    ),
                    expandedTrailingAction: const ElysBarAction(
                      id: 'send',
                      icon: _inputSend,
                    ),
                    optionItems: _inputOptions,
                  ),
                  onLeadingAction: (event) {
                    setState(() {
                      _inputActive = true;
                      _lastEvent = 'leading: ${event.id}';
                    });
                  },
                  onTabSelected: (id) {
                    setState(() {
                      _selectedTabId = id;
                      _inputActive = false;
                      _lastEvent = 'tab: $id';
                    });
                  },
                  onInputModeChanged: (active) {
                    setState(() {
                      _inputActive = active;
                      _lastEvent = active ? 'input opened' : 'input closed';
                    });
                  },
                  onInputTextChanged: (text) {
                    setState(() {
                      _inputText = text;
                      _lastEvent = 'typing: $text';
                    });
                  },
                  onInputSubmitted: (text) {
                    setState(() => _lastEvent = 'submit: $text');
                  },
                  onInputSideAction: (event) {
                    setState(() {
                      _inputActive = false;
                      _lastEvent = 'side: ${event.id} (${event.text ?? ''})';
                    });
                  },
                  onInputAccessoryAction: (event) {
                    setState(() {
                      _lastEvent =
                          'accessory: ${event.id} (${event.text ?? ''})';
                    });
                  },
                  onInputOptionTapped: (event) {
                    setState(() {
                      _lastEvent = 'option: ${event.id} (${event.text ?? ''})';
                    });
                  },
                  onLayoutChanged: (event) =>
                      setState(() => _barLayout = event),
                ),
              ),
              _AttachmentPreview(layout: _barLayout, visible: _inputActive),
              ElysFlutterInteractionDock(
                visible: _inputActive && (_barLayout?.keyboardVisible != true),
                tapCount: _flutterTestTapCount,
                onPrimaryPressed: () => _recordFlutterTestTap('dock A'),
                onSecondaryPressed: () => _recordFlutterTestTap('dock B'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.layout, required this.visible});

  final ElysBarLayoutEvent? layout;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final event = layout;
    final show = visible && event != null && event.inputActive;
    final input = event?.inputFrame;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final platformTop = event == null
        ? 0.0
        : screenHeight - event.platformHeight;
    final inputTop = input == null ? 0.0 : platformTop + input.y;
    final milliseconds = ((event?.animationDuration ?? 0.28) * 1000)
        .round()
        .clamp(160, 420);
    final duration = Duration(milliseconds: milliseconds);
    final top = input == null
        ? 0.0
        : (inputTop - 62).clamp(90.0, screenHeight - 170).toDouble();
    final left = input == null ? 24.0 : input.x + 12;
    final width = input == null
        ? 240.0
        : (input.width - 24).clamp(180.0, 360.0).toDouble();

    return AnimatedPositioned(
      duration: duration,
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: width,
      child: IgnorePointer(
        ignoring: !show,
        child: AnimatedOpacity(
          duration: duration,
          opacity: show ? 1 : 0,
          child: const _AttachmentChip(),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.link, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Flutter 附件预览跟随 native 输入框',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
