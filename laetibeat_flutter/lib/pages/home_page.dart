import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final M3ESearchController searchController = M3ESearchController();
  static const List<String> _filterLabels = [
    'ALL',
    'Happy Mix',
    'Chill Mix',
    'Energetic Mix',
    'Melancholy Mix',
    'Party Mix',
    'Aggressive Mix',
    'Study Mix',
    'Workout Mix',
    'Sleep Mix',
    'Road Trip Mix',
    'Cooking Mix',
    'Dining Mix',
    'Background Mix',

  ];
   int _selectedFilter = 0; 

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 16.0),
          _buildFilterButtonGroup(),
        ],
      ),
    );
  }

  // 搜索栏
  Widget _buildSearchBar() {
    return M3ESearchAnchor.bar(
      searchController: searchController,
      barHintText: 'Search',
      shrinkWrap: true,
      suggestionsBuilder: (context, controller) => const <Widget>[],
    );
  }


  // 过滤按钮组
  Widget _buildFilterButtonGroup() {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent &&
            event.kind == PointerDeviceKind.mouse &&
            event.scrollDelta.dy != 0 &&
            event.scrollDelta.dx == 0) {
          WidgetsBinding.instance.handlePointerEvent(PointerScrollEvent(
            viewId: event.viewId,
            timeStamp: event.timeStamp,
            kind: event.kind,
            device: event.device,
            position: event.position,
            scrollDelta: Offset(event.scrollDelta.dy, 0),
          ));
        }
      },
      child: M3EButtonGroup(
        type: M3EButtonGroupType.standard,
        shape: M3EButtonShape.round,
        size: M3EButtonSize.sm,
        style: M3EButtonStyle.filled,
        neighborSquish: true,
        selectedIndex: _selectedFilter,
        onSelectedIndexChanged: (int? index) {
          if (index != null) {
            setState(() => _selectedFilter = index);
          }
        },
        overflow: M3EButtonGroupOverflow.scroll,
        actions: List.generate(
          _filterLabels.length,
          (index) => M3EButtonGroupAction(
            label: Text(_filterLabels[index]),
          ),
        ),
      ),
    );
  }
}