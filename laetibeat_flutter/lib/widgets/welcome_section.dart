import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../animations.dart';

//首页欢迎
class WelcomeSection extends StatefulWidget {
  const WelcomeSection({super.key});

  @override
  State<WelcomeSection> createState() => _WelcomeSectionState();
}

//播放的阶段
enum _PlaybackPhase { greeting, playing, ending }

//假数据，之后填充
class _MockPlayback {
  static const String userName = 'OtoyaAAAAAAAA';
  static const String currentTitle = '宇宙超威力加强合金版之超长标题';
  static const String currentArtist = '歌手名最长应该也就这么长';
  static const String nextTitle = '宇宙超威力加强合金版之超长标题';
  static const String nextArtist = '歌手名最长应该也就这么长';

  static String greetingFor(DateTime now) {
    final int hour = now.hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _WelcomeSectionState extends State<WelcomeSection> {
  //无限循环：page = index % [_pageCount]。
  static const int _pageCount = 3;
  static const int _itemCount = 900000;

  //自动轮播间隔。
  static const Duration _autoAdvanceInterval = Duration(seconds: 5);

  final PageController _controller = PageController();
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_controller.page?.round() ?? 0) + 1;
      _controller.animateToPage(
        next,
        duration: kSectionAnimDuration,
        curve: kSectionAnimCurve,
      );
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return AnimatedContainer(
      height: 140,
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _itemCount,
        itemBuilder: (context, index) {
          final phase = _PlaybackPhase.values[index % _pageCount];
          return _buildPage(theme, phase);
        },
      ),
    );
  }

  Widget _buildPage(M3EThemeData theme, _PlaybackPhase phase) {
    final scheme = theme.colorScheme;
    final type = theme.typeScale;
    final emphasized = theme.typography.emphasized;

    final Widget content;
    switch (phase) {
      case _PlaybackPhase.greeting:
        content = Text(
          '${_MockPlayback.greetingFor(DateTime.now())}，${_MockPlayback.userName}',
          style: type.headlineSmall,
        );
      case _PlaybackPhase.playing:
        content = _buildThreeLines(
          type: type,
          overline: '正在播放',
          headline: _MockPlayback.currentTitle,
          supporting: _MockPlayback.currentArtist,
          overlineStyle: type.labelMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          headlineStyle: emphasized.headlineMedium,
          supportingStyle: type.bodyLarge.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );
      case _PlaybackPhase.ending:
        content = _buildThreeLines(
          type: type,
          overline: '下一首即将播放',
          headline: _MockPlayback.nextTitle,
          supporting: _MockPlayback.nextArtist,
          overlineStyle: type.labelMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          headlineStyle: type.headlineMedium,
          supportingStyle: type.bodyLarge.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xl,
          vertical: theme.spacing.lg,
        ),
        child: content,
      ),
    );
  }

  //左对齐文本
  Widget _buildThreeLines({
    required M3ETypeScale type,
    required String overline,
    required String headline,
    required String supporting,
    required TextStyle? overlineStyle,
    required TextStyle headlineStyle,
    required TextStyle? supportingStyle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline,
          style: overlineStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: type.labelMedium.fontSize ?? 0),
        Text(
          headline,
          style: headlineStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: type.labelMedium.fontSize ?? 0),
        Text(
          supporting,
          style: supportingStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
