import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';

/// Apple Music-style search landing view.
///
/// Shown when search mode is active but the field has not been focused yet.
/// Two rows of genre cards keep the screen useful before the keyboard opens.
class MobileSearchBrowseView extends StatelessWidget {
  const MobileSearchBrowseView({super.key, this.onGenreSelected});

  final ValueChanged<String>? onGenreSelected;

  static const List<_BrowseGenre> _genres = <_BrowseGenre>[
    _BrowseGenre(
      name: '流行',
      icon: M3EIcons.star,
      surface: AppColorRole.primary,
      content: AppColorRole.onPrimary,
    ),
    _BrowseGenre(
      name: '嘻哈',
      icon: M3EIcons.mic,
      surface: AppColorRole.secondary,
      content: AppColorRole.onSecondary,
    ),
    _BrowseGenre(
      name: '摇滚',
      icon: M3EIcons.graphic_eq,
      surface: AppColorRole.tertiary,
      content: AppColorRole.onTertiary,
    ),
    _BrowseGenre(
      name: '电子',
      icon: M3EIcons.headphones,
      surface: AppColorRole.primaryContainer,
      content: AppColorRole.onPrimaryContainer,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl + bottomInset,
          ),
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppText(
              l10n.navSearch,
              role: AppTextRole.displaySmall,
              colorRole: AppColorRole.onSurface,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppText(
              l10n.libraryBrowse,
              role: AppTextRole.titleMedium,
              colorRole: AppColorRole.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _genres.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.65,
              ),
              itemBuilder: (BuildContext context, int index) {
                final genre = _genres[index];
                return _GenreCard(
                  genre: genre,
                  onTap: onGenreSelected == null
                      ? null
                      : () => onGenreSelected!(genre.name),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  const _GenreCard({required this.genre, this.onTap});

  final _BrowseGenre genre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final background = genre.surface.resolve(scheme);
    final foreground = genre.content.resolve(scheme);

    return Semantics(
      button: true,
      label: '浏览${genre.name}',
      child: Material(
        color: background,
        borderRadius: AppRadii.xlAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: Stack(
            children: <Widget>[
              Positioned(
                right: -AppSpacing.sm,
                bottom: -AppSpacing.sm,
                child: Icon(
                  genre.icon,
                  size: 72,
                  color: foreground.withValues(alpha: 0.12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: AppText(
                    genre.name,
                    role: AppTextRole.titleLarge,
                    colorRole: genre.content,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseGenre {
  const _BrowseGenre({
    required this.name,
    required this.icon,
    required this.surface,
    required this.content,
  });

  final String name;
  final IconData icon;
  final AppColorRole surface;
  final AppColorRole content;
}
