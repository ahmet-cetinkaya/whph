import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/controllers/mcp_settings_controller.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/mcp_runtime_service.dart';

typedef McpDirectoryPicker = Future<String?> Function();

class McpSettings extends StatefulWidget {
  final IMcpAccessService accessService;
  final McpRuntimeService runtimeService;
  final ITranslationService translationService;
  final IMcpOperationService? operationService;
  final McpDirectoryPicker? pickDirectory;

  const McpSettings({
    super.key,
    required this.accessService,
    required this.runtimeService,
    required this.translationService,
    this.operationService,
    this.pickDirectory,
  });

  @override
  State<McpSettings> createState() => _McpSettingsState();
}

class _McpSettingsState extends State<McpSettings> {
  late final McpSettingsController _controller;
  final TextEditingController _portController = TextEditingController();

  String _translate(String key) => widget.translationService.translate(key);

  @override
  void initState() {
    super.initState();
    _controller = McpSettingsController(
      accessService: widget.accessService,
      runtimeService: widget.runtimeService,
    )..addListener(_handleControllerChange);
    _controller.load();
  }

  void _handleControllerChange() {
    if (!mounted) return;
    final port = _controller.accessState?.preferences.port;
    if (port != null && _portController.text != '$port') {
      _portController.text = '$port';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChange)
      ..dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(AppTheme.sizeLarge),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final accessState = _controller.accessState;
    if (accessState == null) return _buildUnavailableCard();
    final preferences = accessState.preferences;
    final activeGrants = accessState.grants.where((grant) => !grant.isRevoked).toList(growable: false);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEnableRow(preferences),
            const Divider(height: AppTheme.sizeXLarge),
            _buildEndpoint(),
            const SizedBox(height: AppTheme.sizeMedium),
            _buildPort(preferences),
            const SizedBox(height: AppTheme.sizeMedium),
            _buildTransferDirectory(preferences),
            if (_controller.lastError != null) ...[
              const SizedBox(height: AppTheme.sizeMedium),
              _buildError(_controller.lastError!),
            ],
            const Divider(height: AppTheme.sizeXLarge),
            _buildConnectionsHeader(),
            const SizedBox(height: AppTheme.sizeSmall),
            if (activeGrants.isEmpty)
              Text(
                _translate(SettingsTranslationKeys.mcpNoConnections),
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...activeGrants.map(_buildConnection),
            if (widget.operationService != null) ...[
              const Divider(height: AppTheme.sizeXLarge),
              _McpApprovalRequests(
                operationService: widget.operationService!,
                translationService: widget.translationService,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableCard() => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: _buildError(
            _controller.lastError ?? _translate(SettingsTranslationKeys.mcpStorageUnavailable),
          ),
        ),
      );

  Widget _buildEnableRow(McpServerPreferences preferences) => Row(
        children: [
          Icon(
            Icons.smart_toy_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.sizeMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_translate(SettingsTranslationKeys.mcpTitle)),
                Text(
                  _translate(SettingsTranslationKeys.mcpDescription),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('mcp-enable-switch'),
            value: preferences.isEnabled,
            onChanged: _controller.isUpdating ? null : _controller.setEnabled,
          ),
        ],
      );

  Widget _buildEndpoint() {
    final endpoint = _controller.runtimeState.endpoint;
    final isRunning = _controller.runtimeState.isRunning;
    return Semantics(
      label: _translate(SettingsTranslationKeys.mcpStatus),
      value:
          isRunning ? _translate(SettingsTranslationKeys.mcpRunning) : _translate(SettingsTranslationKeys.mcpStopped),
      child: Row(
        children: [
          Icon(
            isRunning ? Icons.check_circle : Icons.pause_circle_outline,
            size: AppTheme.iconSizeMedium,
            color: isRunning ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.sizeSmall),
          Expanded(
            child: Text(
              endpoint?.toString() ?? _translate(SettingsTranslationKeys.mcpStopped),
              key: const Key('mcp-endpoint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPort(McpServerPreferences preferences) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('mcp-port-field'),
              controller: _portController,
              enabled: !_controller.isUpdating,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _translate(SettingsTranslationKeys.mcpPort),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
          IconButton.filledTonal(
            key: const Key('mcp-save-port'),
            tooltip: _translate(SettingsTranslationKeys.mcpSavePort),
            onPressed: _controller.isUpdating
                ? null
                : () => _controller.setPort(
                      int.tryParse(_portController.text) ?? 0,
                    ),
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      );

  Widget _buildTransferDirectory(McpServerPreferences preferences) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.folder_outlined),
        title: Text(_translate(SettingsTranslationKeys.mcpTransferDirectory)),
        subtitle: Text(
          preferences.transferDirectory,
          key: const Key('mcp-transfer-directory'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: _translate(SettingsTranslationKeys.mcpChooseDirectory),
          onPressed: _controller.isUpdating ? null : _chooseDirectory,
          icon: const Icon(Icons.folder_open_outlined),
        ),
      );

  Widget _buildError(String message) => Semantics(
        liveRegion: true,
        child: Row(
          key: const Key('mcp-error'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: AppTheme.sizeSmall),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          ],
        ),
      );

  Widget _buildConnectionsHeader() => Row(
        children: [
          Expanded(
            child: Text(
              _translate(SettingsTranslationKeys.mcpConnections),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          FilledButton.tonalIcon(
            key: const Key('mcp-create-connection'),
            onPressed: _controller.isUpdating ? null : _showCreateDialog,
            icon: const Icon(Icons.add),
            label: Text(_translate(SettingsTranslationKeys.mcpCreateConnection)),
          ),
        ],
      );

  Widget _buildConnection(McpAccessGrant grant) => ListTile(
        key: Key('mcp-grant-${grant.id}'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.link),
        title: Text(grant.clientName),
        subtitle: Text(_sortedScopes(grant.scopes)),
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: _translate(SettingsTranslationKeys.mcpRotate),
              onPressed: () => _rotateGrant(grant),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: _translate(SettingsTranslationKeys.mcpRevoke),
              onPressed: () => _revokeGrant(grant),
              icon: const Icon(Icons.link_off),
            ),
          ],
        ),
      );

  Future<void> _chooseDirectory() async {
    final directory = await (widget.pickDirectory ?? () => FilePicker.platform.getDirectoryPath())();
    if (directory != null) await _controller.setTransferDirectory(directory);
  }

  String _sortedScopes(Set<String> scopes) {
    final values = scopes.toList()..sort();
    return values.join(', ');
  }

  Future<void> _showCreateDialog() async {
    final request = await showDialog<_GrantRequest>(
      context: context,
      builder: (_) => _CreateMcpConnectionDialog(
        translationService: widget.translationService,
      ),
    );
    if (request == null) return;
    final token = await _controller.createGrant(request.name, request.scopes);
    if (token != null) await _copyToken(token);
  }

  Future<void> _rotateGrant(McpAccessGrant grant) async {
    final shouldRotate = await _confirm(
      _translate(SettingsTranslationKeys.mcpRotateConfirm),
    );
    if (!shouldRotate) return;
    final token = await _controller.rotateGrant(grant.id);
    if (token != null) await _copyToken(token);
  }

  Future<void> _revokeGrant(McpAccessGrant grant) async {
    final shouldRevoke = await _confirm(
      _translate(SettingsTranslationKeys.mcpRevokeConfirm),
    );
    if (shouldRevoke) await _controller.revokeGrant(grant.id);
  }

  Future<bool> _confirm(String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_translate(SettingsTranslationKeys.mcpCancel)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_translate(SettingsTranslationKeys.mcpConfirm)),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _copyToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_translate(SettingsTranslationKeys.mcpTokenCopied))),
    );
  }
}

class _CreateMcpConnectionDialog extends StatefulWidget {
  final ITranslationService translationService;

  const _CreateMcpConnectionDialog({required this.translationService});

  @override
  State<_CreateMcpConnectionDialog> createState() => _CreateMcpConnectionDialogState();
}

class _CreateMcpConnectionDialogState extends State<_CreateMcpConnectionDialog> {
  static const _defaultScopes = {
    McpScopes.tasksRead,
    McpScopes.habitsRead,
    McpScopes.notesRead,
    McpScopes.tagsRead,
    McpScopes.timersRead,
    McpScopes.usageRead,
    McpScopes.settingsRead,
    McpScopes.syncRead,
    McpScopes.overviewRead,
    McpScopes.appRead,
  };

  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Set<String> _selectedScopes = Set.unmodifiable(_defaultScopes);

  String _translate(String key) => widget.translationService.translate(key);

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_translate(SettingsTranslationKeys.mcpCreateConnection)),
        content: SizedBox(
          width: AppTheme.screenSmall,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(right: AppTheme.sizeSmall),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('mcp-client-name'),
                    controller: _nameController,
                    maxLength: 100,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _translate(SettingsTranslationKeys.mcpConnectionName),
                    ),
                  ),
                  const SizedBox(height: AppTheme.sizeSmall),
                  Text(_translate(SettingsTranslationKeys.mcpPermissions)),
                  const SizedBox(height: AppTheme.sizeSmall),
                  Wrap(
                    spacing: AppTheme.size2XSmall,
                    runSpacing: AppTheme.size2XSmall,
                    children: McpScopes.all.map(_buildScopeChip).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_translate(SettingsTranslationKeys.mcpCancel)),
          ),
          FilledButton(
            key: const Key('mcp-create-confirm'),
            onPressed: _canCreate ? _create : null,
            child: Text(_translate(SettingsTranslationKeys.mcpCreate)),
          ),
        ],
      );

  Widget _buildScopeChip(String scope) => FilterChip(
        key: Key('mcp-scope-$scope'),
        label: Text(scope),
        selected: _selectedScopes.contains(scope),
        onSelected: (isSelected) {
          setState(() {
            _selectedScopes = Set.unmodifiable(
                isSelected ? {..._selectedScopes, scope} : _selectedScopes.where((value) => value != scope));
          });
        },
      );

  bool get _canCreate => _nameController.text.trim().isNotEmpty && _selectedScopes.isNotEmpty;

  void _create() => Navigator.pop(
        context,
        _GrantRequest(_nameController.text.trim(), _selectedScopes),
      );
}

class _GrantRequest {
  final String name;
  final Set<String> scopes;

  _GrantRequest(this.name, Set<String> scopes) : scopes = Set.unmodifiable(scopes);
}

class _McpApprovalRequests extends StatefulWidget {
  final IMcpOperationService operationService;
  final ITranslationService translationService;

  const _McpApprovalRequests({required this.operationService, required this.translationService});

  @override
  State<_McpApprovalRequests> createState() => _McpApprovalRequestsState();
}

class _McpApprovalRequestsState extends State<_McpApprovalRequests> {
  List<McpOperation> _operations = const [];
  bool _isLoading = true;
  String? _error;

  String _translate(String key) => widget.translationService.translate(key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final operations = await widget.operationService.listPending();
      if (!mounted) return;
      setState(() {
        _operations = operations;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _translate(SettingsTranslationKeys.mcpApprovalsLoadError);
      });
    }
  }

  Future<void> _resolve(Future<McpOperation> Function() operation) async {
    setState(() => _isLoading = true);
    try {
      await operation();
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _translate(SettingsTranslationKeys.mcpApprovalUpdateError);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _translate(SettingsTranslationKeys.mcpApprovals),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                key: const Key('mcp-approvals-refresh'),
                tooltip: _translate(SettingsTranslationKeys.mcpRefresh),
                onPressed: _isLoading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (_operations.isEmpty)
            Text(
              _translate(SettingsTranslationKeys.mcpNoApprovals),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ..._operations.map(_buildOperation),
        ],
      );

  Widget _buildOperation(McpOperation operation) => ListTile(
        key: Key('mcp-approval-${operation.id}'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.verified_user_outlined),
        title: Text(operation.summary),
        subtitle: Text('${_operationLabel(operation.type)} · ${_formatApprovalDeadline(operation.approvalExpiresAt)}'),
        trailing: Wrap(
          children: [
            IconButton(
              key: Key('mcp-reject-${operation.id}'),
              tooltip: _translate(SettingsTranslationKeys.mcpReject),
              onPressed: () => _resolve(() => widget.operationService.reject(operation.id)),
              icon: const Icon(Icons.close),
            ),
            IconButton.filled(
              key: Key('mcp-approve-${operation.id}'),
              tooltip: _translate(SettingsTranslationKeys.mcpApprove),
              onPressed: () => _resolve(() => widget.operationService.approve(operation.id)),
              icon: const Icon(Icons.check),
            ),
          ],
        ),
      );

  String _operationLabel(McpOperationType type) => switch (type) {
        McpOperationType.dataImport => _translate(SettingsTranslationKeys.importTitle),
        McpOperationType.syncPair => _translate(SyncTranslationKeys.addSyncDevice),
      };

  String _formatApprovalDeadline(DateTime deadline) => DateFormat.yMd().add_Hm().format(deadline.toLocal());
}
