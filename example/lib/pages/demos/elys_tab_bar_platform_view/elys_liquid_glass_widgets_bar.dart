import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ElysGlassWidgetsBar extends StatelessWidget {
  const ElysGlassWidgetsBar({
    super.key,
    required this.inputActive,
    required this.hasFocus,
    required this.lineCount,
    required this.tabs,
    required this.selectedIndex,
    required this.textController,
    required this.focusNode,
    required this.onLeadingTap,
    required this.onCloseInput,
    required this.onTabSelected,
    required this.onTextChanged,
    required this.onLineCountChanged,
  });

  static const leadingIcon = 'assets/elys_tab_bar/map.png';
  static const inputMoreIcon = 'assets/elys_tab_bar/input_more.png';
  static const inputSettings = LiquidGlassSettings(
    blur: 10,
    thickness: 28,
    refractiveIndex: 1.2,
    saturation: 1.25,
    glassColor: Color(0x2EFFFFFF),
    backerColor: Color(0x72FFFFFF),
    whitenStrength: 0.32,
    shadowElevation: 0.8,
  );

  final bool inputActive;
  final bool hasFocus;
  final int lineCount;
  final List<ElysGlassTabSpec> tabs;
  final int selectedIndex;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onLeadingTap;
  final VoidCallback onCloseInput;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<int> onLineCountChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: inputActive
              ? _ElysGlassInputRow(bar: this)
              : _ElysGlassTabRow(bar: this),
        ),
      ),
    );
  }

  List<GlassTab> glassTabs() {
    return [
      for (final tab in tabs)
        GlassTab(
          icon: ElysGlassAssetIcon(path: tab.icon),
          activeIcon: ElysGlassTabIcon(tab: tab, selected: true),
          semanticLabel: tab.id,
        ),
    ];
  }
}

class _ElysGlassTabRow extends StatelessWidget {
  const _ElysGlassTabRow({required this.bar});

  final ElysGlassWidgetsBar bar;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('tabs'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GlassButton.custom(
          width: 56,
          height: 56,
          label: 'Open input',
          quality: GlassQuality.premium,
          onTap: bar.onLeadingTap,
          child: const ElysGlassAssetIcon(
            path: ElysGlassWidgetsBar.leadingIcon,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 252,
          height: 64,
          child: GlassTabBar.bottom(
            tabs: bar.glassTabs(),
            selectedIndex: bar.selectedIndex,
            onTabSelected: bar.onTabSelected,
            horizontalPadding: 0,
            verticalPadding: 4,
            barHeight: 56,
            barBorderRadius: 32,
            tabWidth: 63,
            iconSize: 25,
            enableBlend: true,
            blendAmount: 12,
            quality: GlassQuality.premium,
            indicatorBorderRadius: 25,
            indicatorExpansion: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
          ),
        ),
      ],
    );
  }
}

class _ElysGlassInputRow extends StatelessWidget {
  const _ElysGlassInputRow({required this.bar});

  final ElysGlassWidgetsBar bar;

  @override
  Widget build(BuildContext context) {
    final selected = bar.tabs[bar.selectedIndex];
    final maxLines = bar.hasFocus ? 4 : 1;
    final minLines = bar.hasFocus ? 2 : 1;
    final visibleLines = bar.hasFocus ? bar.lineCount.clamp(2, 4) : 1;
    final inputHeight = 56.0 + (visibleLines - 1) * 24.0;

    return Row(
      key: const ValueKey('input'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            height: inputHeight,
            child: GlassTextField(
              controller: bar.textController,
              focusNode: bar.focusNode,
              placeholder: '输入任何内容...',
              minLines: minLines,
              maxLines: maxLines,
              height: inputHeight,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              prefixIcon: const ElysGlassAssetIcon(
                path: ElysGlassWidgetsBar.inputMoreIcon,
                size: 24,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              iconSpacing: 12,
              iconAlignment: CrossAxisAlignment.end,
              textStyle: const TextStyle(
                fontSize: 18,
                height: 1.28,
                color: Color(0xFF1F1F25),
              ),
              placeholderStyle: TextStyle(
                fontSize: 18,
                height: 1.28,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              shape: LiquidRoundedSuperellipse(
                borderRadius: bar.hasFocus ? 24 : 28,
              ),
              useOwnLayer: true,
              quality: GlassQuality.premium,
              settings: ElysGlassWidgetsBar.inputSettings,
              onChanged: bar.onTextChanged,
              onLineCountChanged: bar.onLineCountChanged,
              onTapOutside: (_) => bar.focusNode.unfocus(),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 330),
          curve: Curves.easeOutCubic,
          width: bar.hasFocus ? 0 : 64,
          margin: EdgeInsets.only(left: bar.hasFocus ? 0 : 8),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: bar.hasFocus ? 0 : 1,
            child: IgnorePointer(
              ignoring: bar.hasFocus,
              child: GlassButton.custom(
                width: 56,
                height: 56,
                label: 'Close input',
                settings: ElysGlassWidgetsBar.inputSettings,
                quality: GlassQuality.premium,
                onTap: bar.onCloseInput,
                child: ElysGlassTabIcon(tab: selected, selected: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ElysGlassTabIcon extends StatelessWidget {
  const ElysGlassTabIcon({
    super.key,
    required this.tab,
    required this.selected,
  });

  final ElysGlassTabSpec tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = ElysGlassAssetIcon(
      path: selected ? tab.selectedIcon : tab.icon,
      size: 25,
    );
    if (tab.badgeCount <= 0) return icon;
    return GlassBadge(
      count: tab.badgeCount,
      backgroundColor: CupertinoColors.systemRed,
      child: icon,
    );
  }
}

class ElysGlassAssetIcon extends StatelessWidget {
  const ElysGlassAssetIcon({super.key, required this.path, this.size = 26});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class ElysGlassTabSpec {
  const ElysGlassTabSpec({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });

  final String id;
  final String icon;
  final String selectedIcon;
  final int badgeCount;
}
