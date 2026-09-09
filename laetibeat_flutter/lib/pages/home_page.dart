import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final M3ESearchController searchController = M3ESearchController();
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
          _buildFilterChip()
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

  // chips
  Widget _buildChip(int index, String label) {
    return M3EChip(
      label: label,
      type: M3EChipType.filter,
      selected: _selectedFilter == index,
      onPressed: () => setState(() => _selectedFilter = index),
    );
  }

  // chips筛选
  Widget _buildFilterChip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(0, 'All'),
          const SizedBox(width: 8.0),
          _buildChip(1, 'Happy Mix'),
          const SizedBox(width: 8.0),
          _buildChip(2, 'Chill Mix'),
          const SizedBox(width: 8.0),
          _buildChip(3, 'Energetic Mix'),
          const SizedBox(width: 8.0),
          _buildChip(4, 'ALL'),
          const SizedBox(width: 8.0),
          _buildChip(5, 'Happy Mix'),
          const SizedBox(width: 8.0),
          _buildChip(6, 'Chill Mix'),
          const SizedBox(width: 8.0),
          _buildChip(7, 'Energetic Mix'),
          const SizedBox(width: 8.0),
          _buildChip(8, 'ALL'),
          const SizedBox(width: 8.0),
          _buildChip(9, 'Happy Mix'),
          const SizedBox(width: 8.0),
          _buildChip(10, 'Chill Mix'),
          const SizedBox(width: 8.0),
          _buildChip(11, 'Energetic Mix'),
          const SizedBox(width: 8.0),
          _buildChip(12, 'ALL'),
          const SizedBox(width: 8.0),
          _buildChip(13, 'Happy Mix'),
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }
}