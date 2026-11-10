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
    final l10n = AppLocalizations.of(context);
    final limits = ref.watch(cacheLimitsProvider);
    final totalLimitBytes = limits.isUnlimited ? null : limits.totalBytes;
    final progress = totalLimitBytes == null || totalLimitBytes <= 0
        ? 0.0
        : (usage.totalBytes / totalLimitBytes).clamp(0.0, 1.0).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _StorageSummary(
          usedBytes: usage.totalBytes,
          totalLimitBytes: totalLimitBytes,
          progress: progress,
        ),
        const SizedBox(height: 18),
        _FreeSpaceCard(onTap: () => _clearAll(context, ref)),
        const SizedBox(height: 28),
        _CacheGroupSection(
          title: l10n.cacheLocal,
          usage: usage.local,
        ),
        const SizedBox(height: 20),
        _CacheGroupSection(
          title: l10n.cacheSubsonic,
          usage: usage.subsonic,
        ),
        const SizedBox(height: 20),
        _CacheGroupSection(
          title: l10n.cacheLx,
          usage: usage.lx,
        ),
        const SizedBox(height: 28),
        _TotalCacheLimitCard(
          selectedMb: limits.totalMb,
          onSelected: (mb) => _applyTotalLimit(ref, mb),
        ),
      ],
    );
  }

  Future<void> _applyTotalLimit(WidgetRef ref, int mb) async {
    await ref.read(cacheLimitsProvider.notifier).setTotalMb(mb);
    await _applyCurrentLimits(ref);
  }

  Future<void> _applyCurrentLimits(WidgetRef ref) async {
    try {
      await applyCacheLimitsToCovers(
        limits: ref.read(cacheLimitsProvider),
        localCovers: ref.read(coverProvider),
        remoteCovers: ref.read(remoteCoverSourceProvider),
        lxCovers: ref.read(lxCoverSourceProvider),
      );
    } catch (error) {
      debugPrint('应用缓存上限失败: $error');
    }
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
      ref.invalidate(remoteCoverSourceProvider);
      ref.invalidate(lxCoverSourceProvider);
      ref.invalidate(lxSearchProvider);
      ref.invalidate(musicLibraryProvider);
      ref.invalidate(cacheUsageProvider);
      // Invalidate 会创建新的缓存实例；重新套用用户配置的总上限。
      await _applyCurrentLimits(ref);
      if (context.mounted) _showMessage(context, l10n.cacheCleared);
    } catch (error) {
      if (context.mounted) _showMessage(context, error.toString());
    }
  }
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({
    required this.usedBytes,
    required this.totalLimitBytes,
    required this.progress,
  });

  final int usedBytes;
  final int? totalLimitBytes;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final used = formatCacheSizeParts(usedBytes);
    final total = totalLimitBytes == null
        ? null
        : formatCacheSizeParts(totalLimitBytes!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${l10n.cacheUsed} ',
                        style: theme.typeScale.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: used.value,
                        style: theme.typeScale.displaySmall.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      TextSpan(
                        text: ' ${used.unit}',
                        style: theme.typeScale.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              total == null
                  ? '${l10n.cacheTotal} ∞'
                  : '${l10n.cacheTotal} ${total.value} ${total.unit}',
              style: theme.typeScale.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        M3EProgressIndicator.linearWavy(
          value: progress,
          strokeWidth: 16,
          trackStrokeWidth: 16,
          gapSize: 0,
          color: theme.colorScheme.primary,
          trackColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _FreeSpaceCard extends StatelessWidget {
  const _FreeSpaceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: <Widget>[
              Icon(
                M3EIcons.delete_outline,
                size: 24,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.cacheFreeSpace,
                      style: theme.typeScale.titleMedium.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.clearAllCaches,
                      style: theme.typeScale.bodySmall.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CacheGroupSection extends StatelessWidget {
  const _CacheGroupSection({required this.title, required this.usage});

  final String title;
  final CacheGroupUsage usage;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final total = usage.totalBytes;

    final metrics = <_CacheMetric>[
      _CacheMetric(
        icon: M3EIcons.lyrics,
        label: l10n.cacheLyrics,
        bytes: usage.lyricsBytes,
        color: scheme.primary,
      ),
      _CacheMetric(
        icon: M3EIcons.image,
        label: l10n.cacheCovers,
        bytes: usage.coversBytes,
        color: scheme.tertiary,
      ),
      _CacheMetric(
        icon: M3EIcons.storage,
        label: l10n.cacheOther,
        bytes: usage.otherBytes,
        color: scheme.secondary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, bottom: 8),
          child: Text(
            title,
            style: theme.typeScale.titleSmall.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: <Widget>[
              for (var index = 0; index < metrics.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 56,
                    endIndent: 16,
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                _CacheMetricRow(
                  metric: metrics[index],
                  fraction: total == 0 ? 0 : metrics[index].bytes / total,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CacheMetric {
  const _CacheMetric({
    required this.icon,
    required this.label,
    required this.bytes,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int bytes;
  final Color color;
}

class _CacheMetricRow extends StatelessWidget {
  const _CacheMetricRow({required this.metric, required this.fraction});

  final _CacheMetric metric;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    // Match the two-line M3EListItem height used by the appearance settings
    // page (72dp). The list card otherwise collapses to its content height,
    // which makes these rows look noticeably smaller than the other settings.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(metric.icon, size: 24, color: metric.color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          metric.label,
                          style: theme.typeScale.bodyMedium,
                        ),
                      ),
                      Text(
                        formatCacheBytes(metric.bytes),
                        style: theme.typeScale.labelMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Flutter's LinearProgressIndicator draws from x=0. The M3E
                  // variant paints with a 4dp inset and a round cap, so its
                  // visible left edge sits 1dp inside the text edge; using the
                  // standard bar keeps both edges pixel-aligned.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(metric.color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCacheLimitCard extends StatelessWidget {
  const _TotalCacheLimitCard({
    required this.selectedMb,
    required this.onSelected,
  });

  final int selectedMb;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.cacheTotalSize,
                  style: theme.typeScale.titleMedium,
                ),
              ),
              Text(
                formatCacheLimitLabel(selectedMb),
                style: theme.typeScale.titleMedium.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _CacheLimitSlider(
            selectedMb: selectedMb,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _CacheLimitSlider extends StatefulWidget {
  const _CacheLimitSlider({
    required this.selectedMb,
    required this.onSelected,
  });

  final int selectedMb;
  final ValueChanged<int> onSelected;

  @override
  State<_CacheLimitSlider> createState() => _CacheLimitSliderState();
}

class _CacheLimitSliderState extends State<_CacheLimitSlider> {
  late int _index = _nearestIndex(widget.selectedMb);

  static int _nearestIndex(int mb) {
    var bestIndex = 0;
    var bestDistance = (kCacheLimitMbLevels.first - mb).abs();
    for (var index = 1; index < kCacheLimitMbLevels.length; index++) {
      final distance = (kCacheLimitMbLevels[index] - mb).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  @override
  void didUpdateWidget(_CacheLimitSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMb != widget.selectedMb) {
      _index = _nearestIndex(widget.selectedMb);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final maxIndex = kCacheLimitMbLevels.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        M3ESlider(
          value: _index.toDouble(),
          min: 0,
          max: maxIndex.toDouble(),
          divisions: maxIndex,
          label: formatCacheLimitLabel(kCacheLimitMbLevels[_index]),
          size: M3ESliderSize.s,
          onChanged: (value) => setState(() => _index = value.round()),
          onChangeEnd: (value) =>
              widget.onSelected(kCacheLimitMbLevels[value.round()]),
        ),
        Row(
          children: <Widget>[
            for (final mb in kCacheLimitMbLevels)
              Expanded(
                child: Text(
                  formatCacheLimitLabel(mb),
                  textAlign: TextAlign.center,
                  style: theme.typeScale.labelSmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
