import '../../../app/app_mode.dart';

/// Search result categories available for each app mode.
enum MobileSearchCategory { songs, playlists, albums, artists }

/// Search source selected from the active app mode.
enum MobileSearchSourceFilter { all, local, subsonic, lx, netease, qq }

const String legacySearchHistoryKey = 'search.recent_queries';

MobileSearchSourceFilter searchSourceForMode(AppMode mode) => switch (mode) {
  AppMode.local => MobileSearchSourceFilter.local,
  AppMode.subsonic => MobileSearchSourceFilter.subsonic,
  AppMode.qq => MobileSearchSourceFilter.qq,
  AppMode.netease => MobileSearchSourceFilter.netease,
};

List<MobileSearchCategory> searchCategoriesForMode(AppMode mode) =>
    switch (mode) {
      AppMode.local || AppMode.subsonic => MobileSearchCategory.values,
      AppMode.qq || AppMode.netease => const <MobileSearchCategory>[
        MobileSearchCategory.songs,
        MobileSearchCategory.playlists,
        MobileSearchCategory.albums,
      ],
    };

String searchHistoryKeyForMode(AppMode mode) =>
    'search.recent_queries.${mode.id}';
