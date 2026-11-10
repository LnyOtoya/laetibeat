import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pages/mobile/search/search_models.dart';
import 'persistence.dart';

const String kDefaultSearchSourceKey = 'search.default_source';

/// Default source filter for the independent search-results page.
class DefaultSearchSourceNotifier
    extends Notifier<MobileSearchSourceFilter> {
  @override
  MobileSearchSourceFilter build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(kDefaultSearchSourceKey);
    return MobileSearchSourceFilter.values.firstWhere(
      (filter) => filter.name == saved,
      orElse: () => MobileSearchSourceFilter.local,
    );
  }

  Future<void> setSource(MobileSearchSourceFilter filter) async {
    if (filter == state) return;
    state = filter;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kDefaultSearchSourceKey, filter.name);
  }
}

final defaultSearchSourceProvider =
    NotifierProvider<DefaultSearchSourceNotifier, MobileSearchSourceFilter>(
      DefaultSearchSourceNotifier.new,
    );
