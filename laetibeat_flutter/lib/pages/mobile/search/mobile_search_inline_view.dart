import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_mode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../widgets/settings/persistence.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import 'mobile_search_page.dart';
import 'search_models.dart';

/// Inline search surface shown behind [AppMorphingTabBar]'s expanded search
/// field.
///
/// The controller and focus node are owned by the shell so the bottom search
/// field and this body stay in sync. Submitting or selecting a suggestion
/// persists history, closes the inline mode, and pushes the existing results
/// page.
class MobileSearchInlineView extends ConsumerStatefulWidget {
  const MobileSearchInlineView({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onClose;

  @override
  ConsumerState<MobileSearchInlineView> createState() =>
      MobileSearchInlineViewState();
}

class MobileSearchInlineViewState
    extends ConsumerState<MobileSearchInlineView> {
  static const int _recentSearchLimit = 30;

  late final String _recentSearchKey;
  List<String> _recentSearches = const <String>[];

  @override
  void initState() {
    super.initState();
    _recentSearchKey = searchHistoryKeyForMode(ref.read(appModeProvider));
    final preferences = ref.read(sharedPreferencesProvider);
    _recentSearches =
        preferences.getStringList(_recentSearchKey) ??
        preferences.getStringList(legacySearchHistoryKey) ??
        const <String>[];
    widget.controller.addListener(_onQueryChanged);
  }

  @override
  void didUpdateWidget(covariant MobileSearchInlineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onQueryChanged);
      widget.controller.addListener(_onQueryChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onQueryChanged);
    super.dispose();
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _rememberSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final next = <String>[
      query,
      ..._recentSearches.where((item) => item != query),
    ];
    if (next.length > _recentSearchLimit) {
      next.removeRange(_recentSearchLimit, next.length);
    }
    if (mounted) setState(() => _recentSearches = next);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_recentSearchKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const <String>[]);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_recentSearchKey, const <String>[]);
  }

  /// Persists [value], closes inline search, and opens results.
  ///
  /// Called by the bottom bar's `onSubmitted` through a [GlobalKey].
  Future<void> submit(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    await _rememberSearch(query);
    if (!mounted) return;
    widget.controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    widget.focusNode.unfocus();
    pushMobileRootPage(
      context,
      MobileSearchResultsPage(initialQuery: query),
      name: MobileRoutes.searchResults,
    );
    widget.onClose?.call();
  }

  Widget _buildHistory(M3EThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.searchRecentTitle,
                style: theme.typeScale.titleMedium,
              ),
            ),
            if (_recentSearches.isNotEmpty)
              M3EButton(
                style: M3EButtonStyle.text,
                size: M3EButtonSize.sm,
                label: Text(l10n.searchRecentClear),
                onPressed: _clearRecentSearches,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentSearches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.searchRecentEmpty,
              style: theme.typeScale.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          M3EList(
            color: theme.colorScheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: _recentSearches.length,
            onTap: (index) => unawaited(submit(_recentSearches[index])),
            itemBuilder: (BuildContext context, int index) {
              return M3EListItem(
                leading: const Icon(M3EIcons.history),
                headline: _recentSearches[index],
              );
            },
          ),
      ],
    );
  }

  Widget _buildQuerySuggestion(
    M3EThemeData theme,
    AppLocalizations l10n,
    String query,
  ) {
    return M3EList(
      color: theme.colorScheme.surfaceContainerLow,
      variant: M3ECardVariant.filled,
      itemCount: 1,
      onTap: (_) => unawaited(submit(query)),
      itemBuilder: (BuildContext context, int index) => M3EListItem(
        leading: const Icon(M3EIcons.search),
        headline: query,
        supportingText: l10n.searchHint,
        trailing: const Icon(M3EIcons.arrow_forward),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final query = widget.controller.text;
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
          child: query.trim().isEmpty
              ? _buildHistory(theme, l10n)
              : _buildQuerySuggestion(theme, l10n, query.trim()),
        ),
      ),
    );
  }
}
