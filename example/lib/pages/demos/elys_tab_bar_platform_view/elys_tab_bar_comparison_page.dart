import 'package:adaptive_platform_ui_example/pages/demos/elys_tab_bar_platform_view/elys_liquid_glass_widgets_demo_page.dart';
import 'package:adaptive_platform_ui_example/pages/demos/elys_tab_bar_platform_view/elys_tab_bar_platform_view_demo_page.dart';
import 'package:flutter/cupertino.dart';

enum ElysBarDemoKind { native, liquidGlassWidgets }

class ElysTabBarComparisonPage extends StatefulWidget {
  const ElysTabBarComparisonPage({super.key});

  @override
  State<ElysTabBarComparisonPage> createState() =>
      _ElysTabBarComparisonPageState();
}

class _ElysTabBarComparisonPageState extends State<ElysTabBarComparisonPage> {
  ElysBarDemoKind _kind = ElysBarDemoKind.native;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: switch (_kind) {
              ElysBarDemoKind.native => const ElysTabBarPlatformViewDemoPage(
                key: ValueKey('native'),
              ),
              ElysBarDemoKind.liquidGlassWidgets =>
                const ElysLiquidGlassWidgetsDemoPage(
                  key: ValueKey('liquid_glass_widgets'),
                ),
            },
          ),
        ),
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: CupertinoSlidingSegmentedControl<ElysBarDemoKind>(
                groupValue: _kind,
                children: const {
                  ElysBarDemoKind.liquidGlassWidgets: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('demo2'),
                  ),
                  ElysBarDemoKind.native: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('native'),
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) return;
                  setState(() => _kind = value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
