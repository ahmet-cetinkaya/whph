import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/settings/models/public_setting.dart';
import 'package:whph/core/application/features/settings/services/settings_actions.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

part 'settings_tool_contract.dart';
part 'settings_tool_support.dart';

const settingsToolNames = <String>{
  'whph_settings_list',
  'whph_settings_read',
  'whph_settings_update',
};

List<McpToolDefinition> createSettingsTools({
  required SettingsActions actions,
  required IMcpRequestContext requestContext,
}) =>
    List.unmodifiable([
      McpToolDefinition(
        name: 'whph_settings_list',
        description:
            'Lists supported user-facing settings and their effective values.',
        inputSchema: JsonSchema.object(additionalProperties: false),
        outputSchema: _settingsListOutputSchema,
        annotations: _readAnnotations,
        requiredScopes: const {McpScopes.settingsRead},
        handler: (arguments, extra) async {
          final settings = await actions.list();
          return McpToolResult.success({
            'settings': settings.map(_settingJson).toList(growable: false),
          });
        },
      ),
      McpToolDefinition(
        name: 'whph_settings_read',
        description: 'Reads one supported user-facing setting.',
        inputSchema: JsonSchema.object(
          properties: {
            'key': JsonSchema.string(enumValues: _publicSettingNames)
          },
          required: const ['key'],
          additionalProperties: false,
        ),
        outputSchema: _settingOutputSchema,
        annotations: _readAnnotations,
        requiredScopes: const {McpScopes.settingsRead},
        handler: (arguments, extra) async {
          final key = _requirePublicKey(arguments.requireString('key'));
          return McpToolResult.success(_settingJson(await actions.read(key)));
        },
      ),
      McpToolDefinition(
        name: 'whph_settings_update',
        description:
            'Updates one allowlisted setting with optimistic concurrency and applies its user-visible effect.',
        inputSchema: _settingsUpdateInputSchema,
        outputSchema: _settingsUpdateOutputSchema,
        annotations: _mutationAnnotations,
        requiredScopes: const {McpScopes.settingsWrite},
        handler: (arguments, extra) async {
          final key = _requirePublicKey(arguments.requireString('key'));
          final expectedRevision = _optionalRevision(arguments);
          try {
            final update = await actions.update(
              key: key,
              value: arguments['value'],
              expectedRevision: expectedRevision,
              beforeCommit: () => _requireCurrentAuthorization(
                requestContext,
                extra,
                const {McpScopes.settingsWrite},
              ),
            );
            return McpToolResult.success({
              ..._settingJson(update.setting),
              'committed': true,
              'effectStatus': update.effectApplied ? 'applied' : 'failed',
              if (!update.effectApplied)
                'effectError':
                    'The setting was saved, but its user-visible effect failed.',
            });
          } on FormatException catch (error) {
            return _failure(McpToolErrorCode.validationError, error.message);
          } on SettingRevisionConflictException {
            return _failure(McpToolErrorCode.conflict,
                'The setting changed after it was read.');
          }
        },
      ),
    ]);
