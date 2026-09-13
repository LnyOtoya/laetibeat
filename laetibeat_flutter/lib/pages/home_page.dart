import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final M3ESearchController searchController = M3ESearchController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
        ],
      ),
    );
  }

  // 搜索栏(先不放了不合适感觉)
  Widget _buildSearchBar() {
    return M3ESearchAnchor.bar(
      searchController: searchController,
      barHintText: 'Search',
      shrinkWrap: true,
      suggestionsBuilder: (context, controller) => const <Widget>[],
    );
  }
}