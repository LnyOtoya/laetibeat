import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/library.dart' as rust_library;
import 'package:laetibeat/widgets/cache/cover_cache.dart';
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import 'package:laetibeat/widgets/settings/cache_usage_service.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

class MobileStorageSettingsPage extends ConsumerWidget {
  const MobileStorageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final usageAsync = ref.watch(cacheUsageProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: l10n.cacheManagement,
        titleStartPadding: 32,
      ),
      body: SafeArea(
        top: false,
        child: usageAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${l10n.cacheScanFailed}\n$error',
                textAlign: TextAlign.center,
                style: theme.typeScale.bodyMedium.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
          data: (usage) => _CacheBody(usage: usage),
        ),
      ),
    );
  }
}

class _CacheBody extends ConsumerWidget {
  const _CacheBody({required this.usage});

  final CacheUsageSnapshot usage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final limits = ref.watch(cacheLimitsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Column(
          children: <Widget>[
            Text(l10n.cacheOverview, style: theme.typeScale.titleMedium),
            const SizedBox(height: 4),
            Text(
              formatCacheBytes(usage.totalBytes),
              style: theme.typeScale.headlineSmall.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _CacheBreakdown(usage: usage),
        const SizedBox(height: 12),
        M3EButton(
          label: Text(l10n.clearAllCaches),
          style: M3EButtonStyle.tonal,
          onPressed: () => _clearAll(context, ref),
        ),
        const SizedBox(height: 24),
        _GroupSection(
          title: l10n.cacheLocal,
          group: CacheGroup.local,
          usage: usage.local,
          limitMb: limits.localMb,
        ),
        const SizedBox(height: 16),
        _GroupSection(
          title: l10n.cacheSubsonic,
          group: CacheGroup.subsonic,
          usage: usage.subsonic,
          limitMb: limits.subsonicMb,
        ),
        const SizedBox(height: 16),
        _GroupSection(
          title: l10n.cacheLx,
          group: CacheGroup.lx,
          usage: usage.lx,
          limitMb: limits.lxMb,
        ),
      ],
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final servers =
        ref.read(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    try {
      await rust_library.clearLyricsCache();
      await remoteCoverDiskCache.clearAll();
      await ref.read(librarySnapshotStoreProvider).clear();
      for (final server in servers) {
        await rust_library.clearRemoteLibrary(sourceId: server.id);
      }
      ref.invalidate(coverProvider);
      ref.invalidate(lxCoverSourceProvider);
      ref.invalidate(lxSearchProvider);
      ref.invalidate(musicLibraryProvider);
      ref.invalidate(cacheUsageProvider);
      if (context.mounted) _showMessage(context, l10n.cacheCleared);
    } catch (error) {
      if (context.mounted) _showMessage(context, error.toString());
    }
  }
}

class _CacheBreakdown extends StatelessWidget {
  const _CacheBreakdown({required this.usage});

  final CacheUsageSnapshot usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return M3EList(
      color: M3ETheme.of(context).colorScheme.surface,
      variant: M3ECardVariant.filled,
      itemCount: 3,
      itemBuilder: (BuildContext context, int index) {
        final (label, bytes) = switch (index) {
          0 => (l10n.cacheLyrics, usage.lyricsBytes),
          1 => (l10n.cacheCovers, usage.coversBytes),
          _ => (l10n.cacheOther, usage.otherBytes),
        };
        final icon = switch (index) {
          0 => M3EIcons.lyrics,
          1 => M3EIcons.image,
          _ => M3EIcons.storage,
        };
        return _CacheBreakdownRow(
          icon: icon,
          label: label,
          value: usage.totalBytes == 0 ? 0 : bytes / usage.totalBytes,
          detail: formatCacheBytes(bytes),
        );
      },
    );
  }
}

class _GroupSection extends ConsumerWidget {
  const _GroupSection({
    required this.title,
    required this.group,
    required this.usage,
    required this.limitMb,
  });

  final String title;
  final CacheGroup group;
  final CacheGroupUsage usage;
  final int limitMb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final limitBytes = limitMb == 0 ? 0 : limitMb * 1024 * 1024;
    final progress = limitBytes == 0
        ? 0.0
        : (usage.totalBytes / limitBytes).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(title, style: theme.typeScale.titleMedium)),
              Text(
                formatCacheBytes(usage.totalBytes),
                style: theme.typeScale.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          M3EProgressIndicator.linearWavy(
            value: progress,
            strokeWidth: 24,
            trackStrokeWidth: 24,
            gapSize: 0,
            color: theme.colorScheme.primary,
            trackColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${l10n.cacheLyrics} ${formatCacheBytes(usage.lyricsBytes)}',
                  style: theme.typeScale.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${l10n.cacheCovers} ${formatCacheBytes(usage.coversBytes)}',
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${l10n.cacheOther} ${formatCacheBytes(usage.otherBytes)}',
              style: theme.typeScale.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.cacheLimit, style: theme.typeScale.labelLarge),
          const SizedBox(height: 6),
          _LimitSlider(
            selectedMb: limitMb,
            onSelected: (mb) => _applyLimit(ref, mb),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: M3EButton(
              label: Text(l10n.clearGroupCache),
              style: M3EButtonStyle.text,
              size: M3EButtonSize.sm,
              onPressed: () => _clearGroup(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyLimit(WidgetRef ref, int mb) async {
    await ref.read(cacheLimitsProvider.notifier).setLimit(group, mb);
    final bytes = mb == 0 ? (1 << 60) : mb * 1024 * 1024;
    switch (group) {
      case CacheGroup.local:
        final provider = ref.read(coverProvider);
        if (provider is FileCoverProvider) provider.setMaxBytes(bytes);
      case CacheGroup.subsonic:
        ref.read(remoteCoverSourceProvider).setMaxBytes(bytes);
        await remoteCoverDiskCache.setMaxBytes(bytes);
      case CacheGroup.lx:
        ref.read(lxCoverSourceProvider).setMaxBytes(bytes);
    }
  }

  Future<void> _clearGroup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      switch (group) {
        case CacheGroup.local:
          await ref.read(librarySnapshotStoreProvider).clear();
          await rust_library.clearLyricsCache(prefix: 'local:');
          ref.invalidate(coverProvider);
          ref.invalidate(musicLibraryProvider);
        case CacheGroup.subsonic:
          final servers =
              ref.read(subsonicServersProvider).value ??
              const <SubsonicServerConfig>[];
          for (final server in servers) {
            await rust_library.clearRemoteLibrary(sourceId: server.id);
            await rust_library.clearRemoteLyricsCache(sourceId: server.id);
          }
          await rust_library.clearLyricsCache(prefix: 'opensubsonic:');
          await remoteCoverDiskCache.clearAll();
        case CacheGroup.lx:
          await rust_library.clearLyricsCache(prefix: 'lx:');
          ref.invalidate(lxCoverSourceProvider);
          ref.invalidate(lxSearchProvider);
      }
      ref.invalidate(cacheUsageProvider);
      if (context.mounted) _showMessage(context, l10n.cacheCleared);
    } catch (error) {
      if (context.mounted) _showMessage(context, error.toString());
    }
  }
}

class _LimitSlider extends StatefulWidget {
  const _LimitSlider({required this.selectedMb, required this.onSelected});

  final int selectedMb;
  final ValueChanged<int> onSelected;

  @override
  State<_LimitSlider> createState() => _LimitSliderState();
}

class _LimitSliderState extends State<_LimitSlider> {
  late int _index = _indexOf(widget.selectedMb);

  static int _indexOf(int mb) {
    final index = kCacheLimitMbLevels.indexOf(mb);
    return index < 0 ? kCacheLimitMbLevels.length - 1 : index;
  }

  @override
  void didUpdateWidget(_LimitSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMb != widget.selectedMb) {
      _index = _indexOf(widget.selectedMb);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final maxIndex = kCacheLimitMbLevels.length - 1;
    final mb = kCacheLimitMbLevels[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        M3ESlider(
          value: _index.toDouble(),
          min: 0,
          max: maxIndex.toDouble(),
          divisions: maxIndex,
          label: mb == 0 ? '∞' : '${mb}MB',
          size: M3ESliderSize.s,
          onChanged: (value) => setState(() => _index = value.round()),
          onChangeEnd: (value) =>
              widget.onSelected(kCacheLimitMbLevels[value.round()]),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            mb == 0 ? '∞' : '${mb}MB',
            style: theme.typeScale.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _CacheBreakdownRow extends StatelessWidget {
  const _CacheBreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final double value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(label, style: theme.typeScale.bodyMedium),
                    ),
                    Text(
                      detail,
                      style: theme.typeScale.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 150,
                  child: M3EProgressIndicator.linear(
                    value: value.clamp(0, 1),
                    strokeWidth: 24,
                    trackStrokeWidth: 24,
                    color: theme.colorScheme.primary,
                    trackColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
