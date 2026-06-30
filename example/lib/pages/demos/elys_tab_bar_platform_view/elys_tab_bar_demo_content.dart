import 'package:flutter/cupertino.dart';

class ElysDemoBackdrop extends StatelessWidget {
  const ElysDemoBackdrop({super.key});

  static const _colors = [
    Color(0xFFFF5A5F),
    Color(0xFFFFC400),
    Color(0xFF19C37D),
    Color(0xFF00A3FF),
    Color(0xFF7C3AED),
    Color(0xFFFF7A00),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final color in _colors)
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final color in _colors.reversed)
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.58),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ElysDemoTabPage extends StatelessWidget {
  const ElysDemoTabPage({
    super.key,
    required this.selectedTabId,
    required this.inputActive,
    required this.inputText,
    required this.lastEvent,
    required this.onBadgePressed,
    required this.onOptionTogglePressed,
    required this.optionEnabled,
  });

  final String selectedTabId;
  final bool inputActive;
  final String inputText;
  final String lastEvent;
  final VoidCallback onBadgePressed;
  final VoidCallback onOptionTogglePressed;
  final bool optionEnabled;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('tabs'),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 160),
      children: [
        const Text(
          'Elys Liquid Bar',
          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 32),
        _StatusCard(
          selectedTabId: selectedTabId,
          inputActive: inputActive,
          inputText: inputText,
          lastEvent: lastEvent,
        ),
        const SizedBox(height: 16),
        CupertinoButton.filled(
          onPressed: onBadgePressed,
          child: const Text('Increment chat badge from Flutter'),
        ),
        const SizedBox(height: 12),
        CupertinoButton.filled(
          onPressed: onOptionTogglePressed,
          child: Text(
            optionEnabled ? 'Disable photo option' : 'Enable photo option',
          ),
        ),
      ],
    );
  }
}

class ElysDemoInputPage extends StatelessWidget {
  const ElysDemoInputPage({
    super.key,
    required this.text,
    required this.testTapCount,
    required this.onPrimaryTestPressed,
    required this.onSecondaryTestPressed,
  });

  final String text;
  final int testTapCount;
  final VoidCallback onPrimaryTestPressed;
  final VoidCallback onSecondaryTestPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('input'),
      padding: const EdgeInsets.fromLTRB(24, 54, 24, 220),
      children: [
        const Text(
          '输入',
          style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 26),
        Text(
          text.isEmpty ? '输入框内容会实时显示在这里' : text,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: text.isEmpty
                ? CupertinoColors.secondaryLabel.resolveFrom(context)
                : CupertinoColors.label.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 280),
        Text(
          'Flutter bottom test: $testTapCount',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        CupertinoButton.filled(
          onPressed: onPrimaryTestPressed,
          child: const Text('Flutter button under input'),
        ),
        const SizedBox(height: 10),
        CupertinoButton(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          onPressed: onSecondaryTestPressed,
          child: const Text('Second Flutter button'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(child: Text('chip ${index + 1}')),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < 6; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(
                  context,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Scrollable Flutter row ${index + 1}'),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.selectedTabId,
    required this.inputActive,
    required this.inputText,
    required this.lastEvent,
  });

  final String selectedTabId;
  final bool inputActive;
  final String inputText;
  final String lastEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _row('Selected tab', selectedTabId),
          _row('Input active', '$inputActive'),
          _row('Input text', inputText.isEmpty ? '-' : inputText),
          _row('Last event', lastEvent),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
