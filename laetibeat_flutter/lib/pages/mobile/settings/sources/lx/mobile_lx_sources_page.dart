import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../l10n/generated/app_localizations.dart';
import '../../../widgets/mobile_large_subpage_app_bar.dart';

/// Mobile UI for importing and managing user-provided LX source scripts.
class MobileLxSourcesPage extends StatefulWidget {
  const MobileLxSourcesPage({super.key});

  @override
  State<MobileLxSourcesPage> createState() => _MobileLxSourcesPageState();
}

class _MobileLxSourcesPageState extends State<MobileLxSourcesPage> {
  List<rust_lx.UiLxSourceEntry> _sources = const [];
  final Set<String> _busy = <String>{};
  bool _loading = true;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final sources = await rust_lx.listLxSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _importSource() async {
    final l10n = AppLocalizations.of(context);
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: l10n.lxImportSource,
      options: <String>[l10n.lxImportLocalFile, l10n.lxImportFromUrl],
      icon: const Icon(M3EIcons.file_upload),
    );
    if (!mounted || picked == null || picked.isEmpty) return;

    if (picked.first == l10n.lxImportLocalFile) {
      await _importLocalFile();
    } else {
      await _importFromUrl();
    }
  }

  Future<void> _importLocalFile() async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const <String>['js'],
      );
      if (file == null) return;

      final script = utf8.decode(await file.readAsBytes());
      await _importScript(script, l10n.lxSourceImportSuccess);
    } catch (error) {
      if (!mounted) return;
      _showMessage('${l10n.lxSourceImportFailed}: $error');
    }
  }

  Future<void> _importFromUrl() async {
    final l10n = AppLocalizations.of(context);
    final url = await M3EDialog.show<String>(
      context,
      dialog: const _UrlImportDialog(),
    );
    if (!mounted || url == null || url.trim().isEmpty) return;

    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      _showMessage(l10n.lxSourceImportFailed);
      return;
    }

    final client = HttpClient();
    try {
      setState(() => _importing = true);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, chunk) => previous..addAll(chunk),
      );
      await _importScript(
        utf8.decode(bytes),
        l10n.lxSourceImportSuccess,
        showLoading: false,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('${l10n.lxSourceImportFailed}: $error');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importScript(
    String script,
    String successMessage, {
    bool showLoading = true,
  }) async {
    if (showLoading) setState(() => _importing = true);
    try {
      await rust_lx.importLxSource(script: script);
      await _reload();
      if (mounted) _showMessage(successMessage);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _setEnabled(rust_lx.UiLxSourceEntry source, bool enabled) async {
    if (_busy.contains(source.id)) return;
    setState(() => _busy.add(source.id));
    try {
      await rust_lx.setLxSourceEnabled(id: source.id, enabled: enabled);
      await _reload();
    } catch (error) {
      await _reload();
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(source.id));
    }
  }

  Future<void> _showActions(rust_lx.UiLxSourceEntry source) async {
    final l10n = AppLocalizations.of(context);
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: source.name,
      options: <String>[
        l10n.lxSourceRaisePriority,
        l10n.lxSourceLowerPriority,
        l10n.lxSourceDelete,
      ],
      icon: const Icon(M3EIcons.tune),
    );
    if (!mounted || picked == null || picked.isEmpty) return;

    switch (picked.first) {
      case final option when option == l10n.lxSourceRaisePriority:
        await _changePriority(source, 1);
      case final option when option == l10n.lxSourceLowerPriority:
        await _changePriority(source, -1);
      case final option when option == l10n.lxSourceDelete:
        await _confirmDelete(source);
    }
  }

  Future<void> _changePriority(
    rust_lx.UiLxSourceEntry source,
    int delta,
  ) async {
    setState(() => _busy.add(source.id));
    try {
      await rust_lx.setLxSourcePriority(
        id: source.id,
        priority: source.priority + delta,
      );
      await _reload();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(source.id));
    }
  }

  Future<void> _confirmDelete(rust_lx.UiLxSourceEntry source) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await M3EDialog.show<bool>(
      context,
      dialog: M3EDialog(
        title: l10n.lxSourceDeleteTitle,
        icon: const Icon(M3EIcons.delete),
        content: Text(l10n.lxSourceDeleteBody),
        actions: <Widget>[
          M3EButton(
            label: Text(l10n.lxSourceCancel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          M3EButton(
            label: Text(l10n.lxSourceDeleteConfirm),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _busy.add(source.id));
    try {
      await rust_lx.removeLxSource(id: source.id);
      await _reload();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(source.id));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(AppLocalizations l10n, rust_lx.UiLxSourceEntry source) {
    return switch (source.status) {
      'ready' => l10n.lxSourceReady,
      'initializing' => l10n.lxSourceInitializing,
      'failed' => l10n.lxSourceFailed,
      _ => l10n.lxSourceUninitialized,
    };
  }

  String _supportingText(
    AppLocalizations l10n,
    rust_lx.UiLxSourceEntry source,
  ) {
    final parts = <String>[
      if (source.version.isNotEmpty) 'v${source.version}',
      if (source.author.isNotEmpty) source.author,
      _statusLabel(l10n, source),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: l10n.lxSourcesTitle,
        centerTitle: false,
        actions: <Widget>[
          M3EIconButton(
            icon: const Icon(M3EIcons.add),
            tooltip: l10n.lxImportSource,
            semanticLabel: l10n.lxImportSource,
            onPressed: _importing ? null : _importSource,
          ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody(context, theme, l10n)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    M3EThemeData theme,
    AppLocalizations l10n,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l10n.lxSourceLoadFailed, style: theme.typeScale.titleMedium),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              M3EButton(label: Text(l10n.lxSourceRetry), onPressed: _reload),
            ],
          ),
        ),
      );
    }

    if (_sources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                M3EIcons.extension,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(l10n.lxSourceEmpty, style: theme.typeScale.titleMedium),
              const SizedBox(height: 6),
              Text(
                l10n.lxSourceEmptyHint,
                textAlign: TextAlign.center,
                style: theme.typeScale.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              M3EButton(
                label: Text(l10n.lxImportSource),
                onPressed: _importing ? null : _importSource,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Text(
          l10n.lxSourcesWarning,
          style: theme.typeScale.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        M3EList(
          color: theme.colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: _sources.length,
          itemBuilder: (BuildContext context, int index) {
            final source = _sources[index];
            final busy = _busy.contains(source.id);
            return M3EListItem(
              headline: source.name,
              supportingText: _supportingText(l10n, source),
              trailingText: 'P${source.priority}',
              onTap: busy ? null : () => _showActions(source),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  M3ESwitch(
                    value: source.enabled,
                    onChanged: busy
                        ? null
                        : (value) => _setEnabled(source, value),
                  ),
                  const SizedBox(width: 4),
                  M3EIconButton(
                    icon: const Icon(M3EIcons.delete_outline),
                    tooltip: l10n.lxSourceDelete,
                    semanticLabel: l10n.lxSourceDelete,
                    variant: M3EIconButtonVariant.tonal,
                    size: M3EIconButtonSize.xs,
                    onPressed: busy ? null : () => _confirmDelete(source),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _UrlImportDialog extends StatefulWidget {
  const _UrlImportDialog();

  @override
  State<_UrlImportDialog> createState() => _UrlImportDialogState();
}

class _UrlImportDialogState extends State<_UrlImportDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return M3EDialog(
      title: l10n.lxImportUrlTitle,
      icon: const Icon(M3EIcons.link),
      content: SizedBox(
        width: double.maxFinite,
        child: M3ETextField(
          controller: _controller,
          label: l10n.lxImportUrlLabel,
          placeholder: l10n.lxImportUrlHint,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: <Widget>[
        M3EButton(
          label: Text(l10n.lxSourceCancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        M3EButton(
          label: Text(l10n.lxImportSource),
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
