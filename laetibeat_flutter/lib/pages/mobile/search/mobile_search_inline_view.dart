import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../widgets/settings/persistence.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import 'library_search_suggestions.dart';
import 'mobile_search_page.dart';

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
  static const String _recentSearchKey = 'search.recent_queries';
  static const int _recentSearchLimit = 30;

  List<String> _recentSearches = const <String>[];

  @override
  void initState() {
    super.initState();
    _recentSearches =
        ref.read(sharedPreferencesProvider).getStringList(_recentSearchKey) ??
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
    await ref.read(sharedPreferencesProvider).remove(_recentSearchKey);
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
              : LibrarySearchSuggestions(
                  query: query,
                  onSelected: (selection) => unawaited(submit(selection.query)),
                ),
        ),
      ),
    );
  }
}
