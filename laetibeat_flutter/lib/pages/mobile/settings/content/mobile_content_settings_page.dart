import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/settings/download_settings.dart';
import '../../../../widgets/settings/lyrics_settings.dart';
import '../../../../widgets/settings/music_library_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import '../sources/mobile_music_sources_page.dart';

/// 内容设置子页面。
class MobileContentSettingsPage extends ConsumerWidget {
  const MobileContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(musicLibraryProvider).value;
    final download = ref.watch(downloadLocationProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: l10n.settingsContent),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ContentGroupTitle(l10n.lyricsGroup),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              onTap: (int index) {
                switch (index) {
                  case 0:
                    _showLyricsSources(context, ref);
                  case 1:
                    _showLyricsPriority(context, ref);
                }
              },
              itemCount: 3,
              itemBuilder: (BuildContext context, int index) {
                return switch (index) {
                  0 => M3EListItem(
                    headline: l10n.lyricsSource,
                    supportingText: l10n.lyricsSourceSupporting,
                  ),
                  1 => M3EListItem(
                    headline: l10n.lyricsPriority,
                    supportingText: l10n.lyricsPrioritySupporting,
                  ),
                  _ => M3EListItem(
                    headline: l10n.lyricsReset,
                    supportingText: l10n.lyricsResetSupporting,
                  ),
                };
              },
            ),
            const SizedBox(height: 24),
            _ContentGroupTitle(l10n.syncScanGroup),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              onTap: (int index) {
                if (index == 0) _chooseLocalLibrary(ref);
              },
              itemCount: 1,
              itemBuilder: (BuildContext context, int index) {
                return M3EListItem(
                  headline: l10n.chooseLocalLibrary,
                  supportingText:
                      library?.directoryName ??
                      l10n.chooseLocalLibrarySupporting,
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                M3EButton(
                  label: Text(l10n.chooseLibrary),
                  onPressed: () => _chooseLocalLibrary(ref),
                ),
                M3EButton(
                  style: M3EButtonStyle.tonal,
                  enabled:
                      library?.directory != null && library?.isLoading != true,
                  label: Text(
                    library?.isLoading == true
                        ? l10n.scanningButton
                        : l10n.scanButton,
                  ),
                  onPressed: () =>
                      ref.read(musicLibraryProvider.notifier).rescan(),
                ),
              ],
            ),
            if (library?.isLoading == true) ...[
              const SizedBox(height: 12),
              _LibraryScanCard(
                state: library!,
                onCancel: () =>
                    ref.read(musicLibraryProvider.notifier).cancelScan(),
              ),
            ] else if (library?.error != null) ...[
              const SizedBox(height: 12),
              _LibraryStatusCard(
                icon: M3EIcons.error,
                text: l10n.syncFailed(library!.error!),
                isError: true,
              ),
            ] else if (library?.hasScanned == true) ...[
              const SizedBox(height: 12),
              _LibraryStatusCard(
                icon: M3EIcons.check_circle,
                text: l10n.syncComplete(library!.tracks.length),
              ),
            ],
            const SizedBox(height: 24),
            _ContentGroupTitle('媒体来源'),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              onTap: (int index) {
                if (index == 0) {
                  pushMobileRootPage(
                    context,
                    const MobileMusicSourcesPage(),
                    name: MobileRoutes.musicSources,
                  );
                }
              },
              itemCount: 1,
              itemBuilder: (BuildContext context, int index) {
                return const M3EListItem(
                  headline: '音源配置',
                  supportingText: '管理本地、Subsonic、LX 等音乐来源',
                );
              },
            ),
            const SizedBox(height: 24),
            _ContentGroupTitle(l10n.downloadDirectory),
            const SizedBox(height: 8),
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              onTap: (int index) {
                if (index == 0) {
                  ref.read(downloadLocationProvider.notifier).pickDirectory();
                }
              },
              itemCount: 1,
              itemBuilder: (BuildContext context, int index) {
                return M3EListItem(
                  headline: l10n.downloadDirectory,
                  supportingText:
                      download.displayName ?? l10n.downloadDirectorySupporting,
                );
              },
            ),
            if (download.isSet &&
                library?.directory != null &&
                !_isInsideLibrary(library!.directory!, download.locator!)) ...[
              const SizedBox(height: 12),
              _LibraryStatusCard(
                icon: M3EIcons.info,
                text: l10n.downloadDirectoryOutsideLibrary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chooseLocalLibrary(WidgetRef ref) async {
    // 只选择目录，不自动扫描；用户点击“扫描”后才开始。
    await ref.read(musicLibraryProvider.notifier).pickDirectory();
  }

  Future<void> _showLyricsSources(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(lyricsSettingsProvider);
    final optionSources = <String, LyricsSourceId>{
      _sourceLabel(l10n, LyricsSourceId.tags, includingServer: true):
          LyricsSourceId.tags,
      _sourceLabel(l10n, LyricsSourceId.lrclib): LyricsSourceId.lrclib,
      _sourceLabel(l10n, LyricsSourceId.liriqo): LyricsSourceId.liriqo,
    };
    final options = optionSources.keys.toList(growable: false);
    final initialSelection = <String>[
      for (final source in settings.order)
        if (settings.isEnabled(source))
          _sourceLabel(
            l10n,
            source,
            includingServer: source == LyricsSourceId.tags,
          ),
    ];

    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: l10n.lyricsSource,
      options: options,
      multiSelect: true,
      initialSelection: initialSelection,
      icon: const Icon(M3EIcons.lyrics),
    );
    if (picked == null) return;

    final enabled = <LyricsSourceId>{
      for (final value in picked)
        if (optionSources[value] != null) optionSources[value]!,
    };
    await ref.read(lyricsSettingsProvider.notifier).setEnabled(enabled);
  }

  Future<void> _showLyricsPriority(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _LyricsPrioritySheet(
          initialOrder: ref.read(lyricsSettingsProvider).order,
          onChanged: (order) =>
              ref.read(lyricsSettingsProvider.notifier).setOrder(order),
        );
      },
    );
  }
}

String _sourceLabel(
  AppLocalizations l10n,
  LyricsSourceId source, {
  bool includingServer = false,
}) {
  return switch (source) {
    LyricsSourceId.tags =>
      includingServer
          ? l10n.lyricsSourceTagsIncludingServer
          : l10n.lyricsSourceTags,
    LyricsSourceId.lrclib => l10n.lyricsSourceLrclib,
    LyricsSourceId.liriqo => l10n.lyricsSourceLiriqo,
  };
}

class _LyricsPrioritySheet extends StatefulWidget {
  const _LyricsPrioritySheet({
    required this.initialOrder,
    required this.onChanged,
  });

  final List<LyricsSourceId> initialOrder;
  final ValueChanged<List<LyricsSourceId>> onChanged;

  @override
  State<_LyricsPrioritySheet> createState() => _LyricsPrioritySheetState();
}

class _LyricsPrioritySheetState extends State<_LyricsPrioritySheet> {
  late final List<LyricsSourceId> _order = List<LyricsSourceId>.of(
    widget.initialOrder,
  );

  void _handleReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    setState(() {
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    widget.onChanged(List<LyricsSourceId>.unmodifiable(_order));
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(theme.spacing.lg),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.lg,
            theme.spacing.md,
            theme.spacing.md,
            theme.spacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.lyricsPriority,
                      style: theme.typeScale.titleLarge,
                    ),
                  ),
                  M3EIconButton(
                    size: M3EIconButtonSize.xs,
                    icon: const Icon(M3EIcons.close),
                    tooltip: l10n.closeLyricsPriority,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                l10n.lyricsPriorityHint,
                style: theme.typeScale.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              M3EList.scrollable(
                shrinkWrap: true,
                reorder: true,
                onReorder: _handleReorder,
                itemCount: _order.length,
                itemBuilder: (BuildContext context, int index) {
                  final source = _order[index];
                  return M3EListItem(
                    headline: _sourceLabel(
                      l10n,
                      source,
                      includingServer: source == LyricsSourceId.tags,
                    ),
                    trailing: Icon(
                      M3EIcons.drag_handle,
                      color: scheme.onSurfaceVariant,
                      semanticLabel: l10n.lyricsReorderHandle,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isInsideLibrary(String library, String download) {
  if (library == download) return true;

  if (library.startsWith('content://') && download.startsWith('content://')) {
    final libraryTree = _safTreeId(library);
    final downloadTree = _safTreeId(download);
    if (libraryTree == null || downloadTree == null) return false;
    return downloadTree == libraryTree ||
        downloadTree.startsWith('$libraryTree/');
  }

  String normalize(String value) {
    var result = value.replaceAll('\\', '/');
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  final root = normalize(library);
  final target = normalize(download);
  return target == root || target.startsWith('$root/');
}

String? _safTreeId(String uri) {
  final parsed = Uri.tryParse(uri);
  if (parsed == null) return null;
  final segments = parsed.pathSegments;
  final index = segments.indexOf('tree');
  if (index < 0 || index + 1 >= segments.length) return null;
  return Uri.decodeComponent(segments[index + 1]);
}

class _LibraryScanCard extends StatelessWidget {
  const _LibraryScanCard({required this.state, required this.onCancel});

  final MusicLibraryState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final total = state.scanTotal;
    final progress = total != null && total > 0
        ? (state.scanProcessed / total).clamp(0.0, 1.0)
        : null;
    final countText = total == null
        ? '${state.scanProcessed} / ?'
        : '${state.scanProcessed} / $total';

    return M3ECard(
      variant: M3ECardVariant.filled,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      expanded: true,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(M3EIcons.sync, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.syncScanning,
                  style: theme.typeScale.titleSmall,
                ),
              ),
              M3EButton(
                style: M3EButtonStyle.text,
                size: M3EButtonSize.sm,
                label: Text(l10n.lyricsSearchCancel),
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          M3EProgressIndicator.linear(
            value: progress,
            linearSize: M3EProgressIndicatorSize.s,
            strokeWidth: 6,
            trackStrokeWidth: 6,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  state.scanCurrentName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.bodySmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                countText,
                style: theme.typeScale.labelSmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryStatusCard extends StatelessWidget {
  const _LibraryStatusCard({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return M3EList(
      color: scheme.surface,
      variant: M3ECardVariant.filled,
      itemCount: 1,
      itemBuilder: (BuildContext context, int index) {
        return M3EListItem(
          leading: Icon(icon, color: isError ? scheme.error : scheme.primary),
          headline: text,
        );
      },
    );
  }
}

class _ContentGroupTitle extends StatelessWidget {
  const _ContentGroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: Text(
        text,
        style: theme.typeScale.titleSmall.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
