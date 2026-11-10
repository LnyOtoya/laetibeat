/// Search UI categories shared by the library suggestions and the full search
/// page.
enum MobileSearchCategory { songs, playlists, albums, artists }

/// Source filter used by the search page's split filter button.
enum MobileSearchSourceFilter { all, local, subsonic, lx }

/// One clickable suggestion shown below the library search bar.
class MobileSearchSuggestion {
  const MobileSearchSuggestion({
    required this.text,
    required this.query,
    required this.sourceLabel,
    required this.kindLabel,
  });

  final String text;
  final String query;
  final String sourceLabel;
  final String kindLabel;
}
