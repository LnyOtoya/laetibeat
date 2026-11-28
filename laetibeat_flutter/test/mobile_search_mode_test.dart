import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_mode.dart';
import 'package:laetibeat/pages/mobile/search/search_models.dart';

void main() {
  group('search source follows app mode', () {
    test('maps each mode to its own search source', () {
      expect(
        searchSourceForMode(AppMode.local),
        MobileSearchSourceFilter.local,
      );
      expect(
        searchSourceForMode(AppMode.subsonic),
        MobileSearchSourceFilter.subsonic,
      );
      expect(searchSourceForMode(AppMode.qq), MobileSearchSourceFilter.qq);
      expect(
        searchSourceForMode(AppMode.netease),
        MobileSearchSourceFilter.netease,
      );
    });

    test('online modes only expose supported result categories', () {
      const onlineCategories = <MobileSearchCategory>[
        MobileSearchCategory.songs,
        MobileSearchCategory.playlists,
        MobileSearchCategory.albums,
      ];

      expect(searchCategoriesForMode(AppMode.netease), onlineCategories);
      expect(searchCategoriesForMode(AppMode.qq), onlineCategories);
      expect(
        searchCategoriesForMode(AppMode.local),
        MobileSearchCategory.values,
      );
      expect(
        searchCategoriesForMode(AppMode.subsonic),
        MobileSearchCategory.values,
      );
    });

    test('search history is partitioned by mode', () {
      expect(
        searchHistoryKeyForMode(AppMode.netease),
        'search.recent_queries.netease',
      );
      expect(
        searchHistoryKeyForMode(AppMode.local),
        'search.recent_queries.local',
      );
    });
  });
}
