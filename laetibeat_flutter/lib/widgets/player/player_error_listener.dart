import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'player_provider.dart';

/// Shows playback failures as a SnackBar and offers a one-shot retry.
/// It lives above the mobile/desktop shell so errors from background
/// resolution are visible even when the playback page is not open.
class PlayerErrorListener extends ConsumerWidget {
  const PlayerErrorListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(playerProvider.select((state) => state.errorMessage), (
      String? previous,
      String? next,
    ) {
      if (next == null || next == previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context);
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next),
              action: SnackBarAction(
                label: l10n.playbackRetry,
                onPressed: () {
                  ref.read(playerProvider.notifier).retryCurrent();
                },
              ),
            ),
          );
        ref.read(playerProvider.notifier).clearError();
      });
    });
    return child;
  }
}
