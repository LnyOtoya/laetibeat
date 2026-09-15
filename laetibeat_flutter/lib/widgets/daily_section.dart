import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../animations.dart';
import 'album_card.dart';

//每日推荐区块
class DailySection extends StatefulWidget {
  const DailySection({super.key});

  @override
  State<DailySection> createState() => _DailySectionState();
}

class _DailySectionState extends State<DailySection> {
  //当前选中的筛选标签
  int _selectedIndex = 0;

  //筛选选项
  static const List<String> _filters = <String>['未曾听过', '很久没听', '常听歌曲'];

  //假数据,之后填充
  static const List<_MockAlbum> _albums = <_MockAlbum>[
    _MockAlbum('Paradise Found', 'The Starlings'),
    _MockAlbum('City Lights', 'Neon Reverie'),
    _MockAlbum('Wandering', 'Paper Cranes'),
    _MockAlbum('Sunbeam', 'Mellow Fields'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      padding: EdgeInsets.all(theme.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //上部分:标题 + 筛选按钮组
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '为你推荐',
                style: theme.typeScale.titleLarge,
              ),
              M3EButtonGroup(
                type: M3EButtonGroupType.connected,
                actions: _filters
                    .map(
                      (filter) => M3EButtonGroupAction(label: Text(filter)),
                    )
                    .toList(),
                selectedIndex: _selectedIndex,
                onSelectedIndexChanged: (index) {
                  setState(() => _selectedIndex = index ?? 0);
                },
              ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),
          //下部分:横向四个卡片
          Row(
            children: [
              //四个等宽专辑卡片,间距用spacing.md分隔
              for (int i = 0; i < _albums.length; i++) ...[
                if (i > 0) SizedBox(width: theme.spacing.md),
                Expanded(
                  flex: 1,
                  child: AlbumCard(
                    title: _albums[i].name,
                    subtitle: _albums[i].artist,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

//专辑假数据
class _MockAlbum {
  final String name;
  final String artist;

  const _MockAlbum(this.name, this.artist);
}