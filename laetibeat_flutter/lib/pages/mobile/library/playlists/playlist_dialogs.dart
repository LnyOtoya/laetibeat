import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';

Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  String? initialName,
  String? title,
}) {
  return M3EDialog.show<String>(
    context,
    dialog: _PlaylistNameDialog(initialName: initialName, title: title),
  );
}

Future<bool> showDeletePlaylistConfirm(
  BuildContext context, {
  required String name,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await M3EDialog.show<bool>(
    context,
    dialog: M3EDialog(
      title: l10n.playlistDelete,
      icon: const Icon(M3EIcons.delete),
      content: Text(l10n.playlistDeleteConfirm(name)),
      actions: <Widget>[
        M3EButton(
          label: Text(l10n.actionCancel),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        M3EButton(
          label: Text(l10n.actionDelete),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({this.initialName, this.title});

  final String? initialName;
  final String? title;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return M3EDialog(
      title: widget.title ?? l10n.playlistNew,
      icon: const Icon(M3EIcons.queue_music),
      content: SizedBox(
        width: double.maxFinite,
        child: M3ETextField(
          controller: _controller,
          label: l10n.playlistName,
          placeholder: l10n.playlistName,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: <Widget>[
        M3EButton(
          label: Text(l10n.actionCancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        M3EButton(label: Text(l10n.actionSave), onPressed: _submit),
      ],
    );
  }
}
