import 'package:adaptive_platform_ui_example/pages/demos/elys_tab_bar_platform_view/elys_tab_bar_demo_content.dart';
import 'package:adaptive_platform_ui_example/pages/demos/elys_tab_bar_platform_view/elys_liquid_glass_widgets_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ElysLiquidGlassWidgetsDemoPage extends StatefulWidget {
  const ElysLiquidGlassWidgetsDemoPage({super.key});

  @override
  State<ElysLiquidGlassWidgetsDemoPage> createState() =>
      _ElysLiquidGlassWidgetsDemoPageState();
}

class _ElysLiquidGlassWidgetsDemoPageState
    extends State<ElysLiquidGlassWidgetsDemoPage> {
  static const _tabs = [
    ElysGlassTabSpec(
      id: 'library',
      icon: 'assets/elys_tab_bar/home.png',
      selectedIcon: 'assets/elys_tab_bar/home_selected.png',
    ),
    ElysGlassTabSpec(
      id: 'messages',
      icon: 'assets/elys_tab_bar/chat.png',
      selectedIcon: 'assets/elys_tab_bar/chat_selected.png',
      badgeCount: 3,
    ),
    ElysGlassTabSpec(
      id: 'map',
      icon: 'assets/elys_tab_bar/map.png',
      selectedIcon: 'assets/elys_tab_bar/map_selected.png',
    ),
    ElysGlassTabSpec(
      id: 'profile',
      icon: 'assets/elys_tab_bar/profile.png',
      selectedIcon: 'assets/elys_tab_bar/profile_selected.png',
    ),
  ];

  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;
  bool _inputActive = false;
  bool _hasFocus = false;
  int _lineCount = 1;
  String _lastEvent = 'demo2 ready';

  ElysGlassTabSpec get _selectedTab => _tabs[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openInput() {
    setState(() {
      _inputActive = true;
      _lastEvent = 'left icon -> input';
    });
  }

  void _closeInput() {
    _focusNode.unfocus();
    setState(() {
      _inputActive = false;
      _lineCount = 1;
      _lastEvent = 'side icon -> tabs';
    });
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _inputActive = false;
      _lineCount = 1;
      _lastEvent = 'tab: ${_tabs[index].id}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final barBottom = bottomInset > 0 ? bottomInset + 8.0 : safeBottom + 8.0;

    return GlassPage(
      background: const ElysGlassDemoBackground(),
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.transparent,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _focusNode.unfocus(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _inputActive
                      ? ElysDemoInputPage(
                          text: _textController.text,
                          testTapCount: 0,
                          onPrimaryTestPressed: () {},
                          onSecondaryTestPressed: () {},
                        )
                      : ElysDemoTabPage(
                          selectedTabId: _selectedTab.id,
                          inputActive: _inputActive,
                          inputText: _textController.text,
                          lastEvent: _lastEvent,
                          onBadgePressed: () {},
                          onOptionTogglePressed: () {},
                          optionEnabled: true,
                        ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: barBottom,
              child: ElysGlassWidgetsBar(
                inputActive: _inputActive,
                hasFocus: _hasFocus,
                lineCount: _lineCount,
                tabs: _tabs,
                selectedIndex: _selectedIndex,
                textController: _textController,
                focusNode: _focusNode,
                onLeadingTap: _openInput,
                onCloseInput: _closeInput,
                onTabSelected: _selectTab,
                onTextChanged: (text) {
                  setState(() => _lastEvent = 'typing: $text');
                },
                onLineCountChanged: (count) {
                  setState(() => _lineCount = count);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ElysGlassDemoBackground extends StatelessWidget {
  const ElysGlassDemoBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: const Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 260,
            child: ElysDemoBackdrop(),
          ),
        ],
      ),
    );
  }
}
