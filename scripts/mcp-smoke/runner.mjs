import { writeFile } from 'node:fs/promises';

import {
  Client as ModernClient,
  StreamableHTTPClientTransport as ModernTransport,
} from '@modelcontextprotocol/client';
import { Client as LegacyClient } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport as LegacyTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { LATEST_PROTOCOL_VERSION as LEGACY_PROTOCOL_VERSION } from '@modelcontextprotocol/sdk/types.js';

const MODERN_PROTOCOL_VERSION = '2026-07-28';
const CONNECTION_TIMEOUT_MS = 10_000;
const EXPECTED_TOOLS = Object.freeze([
  'whph_app_context',
  'whph_data_export',
  'whph_data_import_prepare',
  'whph_habit_daily_results',
  'whph_habit_records_list',
  'whph_habit_records_set',
  'whph_habit_records_undo',
  'whph_habit_statistics',
  'whph_habit_time_records_add',
  'whph_habit_time_records_list',
  'whph_habit_time_records_update',
  'whph_habit_time_total',
  'whph_habits_archive',
  'whph_habits_create',
  'whph_habits_delete',
  'whph_habits_list',
  'whph_habits_read',
  'whph_habits_reorder',
  'whph_habits_update',
  'whph_marathon_advance',
  'whph_marathon_select_task',
  'whph_notes_create',
  'whph_notes_delete',
  'whph_notes_list',
  'whph_notes_read',
  'whph_notes_reorder',
  'whph_notes_update',
  'whph_operations_get',
  'whph_overview_calendar',
  'whph_overview_time_analysis',
  'whph_overview_today',
  'whph_settings_list',
  'whph_settings_read',
  'whph_settings_update',
  'whph_sync_devices_delete',
  'whph_sync_devices_list',
  'whph_sync_devices_read',
  'whph_sync_devices_update',
  'whph_sync_pair_prepare',
  'whph_sync_start',
  'whph_sync_stop',
  'whph_tag_elements_by_time',
  'whph_tag_relationships_set',
  'whph_tag_time_analysis',
  'whph_tags_create',
  'whph_tags_delete',
  'whph_tags_list',
  'whph_tags_read',
  'whph_tags_update',
  'whph_task_statuses_create',
  'whph_task_statuses_delete',
  'whph_task_statuses_list',
  'whph_task_statuses_read',
  'whph_task_statuses_reorder',
  'whph_task_statuses_update',
  'whph_task_time_records_add',
  'whph_task_time_records_list',
  'whph_task_time_records_update',
  'whph_task_time_total',
  'whph_tasks_create',
  'whph_tasks_delete',
  'whph_tasks_import',
  'whph_tasks_list',
  'whph_tasks_read',
  'whph_tasks_reorder',
  'whph_tasks_set_completion',
  'whph_tasks_update',
  'whph_timers_list',
  'whph_timers_pause',
  'whph_timers_read',
  'whph_timers_resume',
  'whph_timers_set_phase',
  'whph_timers_start',
  'whph_timers_stop',
  'whph_timers_update_settings',
  'whph_usage_delete',
  'whph_usage_devices_list',
  'whph_usage_ignore_rules_create',
  'whph_usage_ignore_rules_delete',
  'whph_usage_ignore_rules_list',
  'whph_usage_list',
  'whph_usage_read',
  'whph_usage_statistics',
  'whph_usage_tag_rules_create',
  'whph_usage_tag_rules_delete',
  'whph_usage_tag_rules_list',
  'whph_usage_tracking_start',
  'whph_usage_tracking_stop',
  'whph_usage_update',
]);

function requiredEnvironment(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function smokeEndpoint() {
  const rawUrl = requiredEnvironment('MCP_SMOKE_URL');
  const endpoint = new URL(rawUrl);
  const isLoopback = endpoint.hostname === '127.0.0.1' || endpoint.hostname === 'localhost';
  if (endpoint.protocol !== 'http:' || !isLoopback || endpoint.pathname !== '/mcp') {
    throw new Error('MCP_SMOKE_URL must be an http://127.0.0.1 or localhost /mcp endpoint');
  }
  if (endpoint.username || endpoint.password || endpoint.search || endpoint.hash) {
    throw new Error('MCP_SMOKE_URL must not contain credentials, query parameters, or a fragment');
  }
  return endpoint;
}

function smokeMode() {
  const mode = process.env.MCP_SMOKE_MODE?.trim() || 'catalog';
  if (!['catalog', 'happy', 'readonly', 'revoked', 'disconnect'].includes(mode)) {
    throw new Error(`Unsupported MCP_SMOKE_MODE: ${mode}`);
  }
  return mode;
}

async function connectModern({ endpoint, token, fetchImpl }) {
  const client = new ModernClient(
    { name: 'whph-task-14-modern-smoke', version: '1.0.0' },
    { versionNegotiation: { mode: { pin: MODERN_PROTOCOL_VERSION } } },
  );
  const transport = new ModernTransport(endpoint, {
    authProvider: { token: async () => token },
    fetch: fetchImpl,
  });
  await client.connect(transport, { timeout: CONNECTION_TIMEOUT_MS });
  if (client.getProtocolEra() !== 'modern') {
    await client.close();
    throw new Error('Modern client did not negotiate the modern protocol era');
  }
  if (client.getNegotiatedProtocolVersion() !== MODERN_PROTOCOL_VERSION) {
    await client.close();
    throw new Error('Modern client negotiated an unexpected protocol version');
  }
  return client;
}

async function connectLegacy(endpoint, token) {
  const client = new LegacyClient({ name: 'whph-task-14-legacy-smoke', version: '1.0.0' });
  const transport = new LegacyTransport(endpoint, {
    requestInit: { headers: { Authorization: `Bearer ${token}` } },
  });
  await client.connect(transport, { timeout: CONNECTION_TIMEOUT_MS });
  return client;
}

function validateSchema(tool, schemaName) {
  const schema = tool[schemaName];
  if (!schema || schema.type !== 'object' || schema.additionalProperties !== false) {
    throw new Error(`${tool.name} has a non-closed ${schemaName}`);
  }
}

function validateCatalog(tools) {
  const names = tools.map((tool) => tool.name).sort();
  const expected = [...EXPECTED_TOOLS].sort();
  if (new Set(names).size !== names.length) throw new Error('tools/list returned duplicate names');
  if (JSON.stringify(names) !== JSON.stringify(expected)) {
    const missing = expected.filter((name) => !names.includes(name));
    const extra = names.filter((name) => !expected.includes(name));
    throw new Error(`tools/list mismatch: missing=${missing.join(',')} extra=${extra.join(',')}`);
  }
  for (const tool of tools) {
    validateSchema(tool, 'inputSchema');
    validateSchema(tool, 'outputSchema');
    if (!tool.description?.trim()) throw new Error(`${tool.name} has no description`);
    if (!tool.annotations || tool.annotations.openWorldHint !== false) {
      throw new Error(`${tool.name} has invalid annotations`);
    }
  }
}

function structuredResult(name, result) {
  if (!result || result.isError === true) {
    const code = result?.structuredContent?.error?.code ?? 'unknown';
    throw new Error(`${name} failed with ${code}`);
  }
  const value = result.structuredContent;
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${name} returned malformed structuredContent`);
  }
  return value;
}

async function call(client, name, args = {}) {
  return structuredResult(name, await client.callTool({ name, arguments: args }));
}

async function callForApproval(client, name, args) {
  const result = await client.callTool({ name, arguments: args });
  const error = result?.structuredContent?.error;
  const details = error?.details;
  if (result?.isError !== true || error?.code !== 'approval_required') {
    throw new Error(`${name} did not require local approval`);
  }
  if (!details || typeof details !== 'object' || Array.isArray(details)) {
    throw new Error(`${name} returned malformed approval details`);
  }
  return details;
}

async function verifyModernCatalog(endpoint, token) {
  const client = await connectModern({ endpoint, token });
  try {
    const listed = await client.listTools(undefined, { cacheMode: 'refresh' });
    validateCatalog(listed.tools);
    await call(client, 'whph_app_context');
    return {
      era: client.getProtocolEra(),
      protocolVersion: client.getNegotiatedProtocolVersion(),
      toolCount: listed.tools.length,
    };
  } finally {
    await client.close();
  }
}

async function verifyLegacyCatalog(endpoint, token) {
  const client = await connectLegacy(endpoint, token);
  try {
    const listed = await client.listTools();
    validateCatalog(listed.tools);
    return {
      protocolVersion: LEGACY_PROTOCOL_VERSION,
      toolCount: listed.tools.length,
    };
  } finally {
    await client.close();
  }
}

async function createTaskFlow(client, suffix, tagId) {
  const task = await call(client, 'whph_tasks_create', {
    title: `MCP task ${suffix}`,
    description: 'Created by the isolated task-14 smoke test',
    plannedAt: '2026-09-09T09:00:00+03:00',
    tagIds: [tagId],
  });
  const child = await call(client, 'whph_tasks_create', {
    title: `MCP subtask ${suffix}`,
    parentId: task.id,
    tagIds: [tagId],
  });
  const planned = await call(client, 'whph_tasks_update', {
    id: task.id,
    expectedRevision: task.revision,
    deadlineAt: '2026-09-10T17:00:00+03:00',
  });
  const timer = await call(client, 'whph_timers_start', {
    ownerType: 'task',
    ownerId: task.id,
    mode: 'stopwatch',
  });
  await new Promise((resolve) => setTimeout(resolve, 1_100));
  await call(client, 'whph_timers_pause', { sessionId: timer.sessionId });
  await call(client, 'whph_timers_resume', { sessionId: timer.sessionId });
  await new Promise((resolve) => setTimeout(resolve, 1_100));
  await call(client, 'whph_timers_stop', { sessionId: timer.sessionId });
  const timeRecords = await call(client, 'whph_task_time_records_list', { taskId: task.id });
  if (!Array.isArray(timeRecords.items) || timeRecords.items.length !== 1) {
    throw new Error('Stopwatch flow did not persist exactly one task time record');
  }
  const completed = await call(client, 'whph_tasks_set_completion', {
    id: task.id,
    expectedRevision: planned.revision,
    isCompleted: true,
  });
  const reopened = await call(client, 'whph_tasks_set_completion', {
    id: task.id,
    expectedRevision: completed.revision,
    isCompleted: false,
  });
  return { task, child, reopened, timeRecordCount: timeRecords.items.length };
}

async function createHabitFlow(client, suffix) {
  const goodHabit = await call(client, 'whph_habits_create', {
      name: `MCP good habit ${suffix}`,
      type: 'good',
    });
  const badHabit = await call(client, 'whph_habits_create', {
      name: `MCP bad habit ${suffix}`,
      type: 'bad',
    });
  await call(client, 'whph_habit_records_set', {
      habitId: goodHabit.id,
      date: '2026-09-08',
      status: 'complete',
    });
  await call(client, 'whph_habit_records_set', {
      habitId: badHabit.id,
      date: '2026-09-08',
      status: 'not_done',
    });
  return { goodHabit, badHabit };
}

async function createNoteFlow(client, suffix, tagId) {
  const note = await call(client, 'whph_notes_create', {
      title: `MCP note ${suffix}`,
      content: '# External client\nUnicode: İstanbul 🧪',
      tagIds: [tagId],
    });
  const editedNote = await call(client, 'whph_notes_update', {
      id: note.id,
      expectedRevision: note.revision,
      title: `MCP edited note ${suffix}`,
    });
  return { note, editedNote };
}

async function runManagementFlow(client) {
  const setting = await call(client, 'whph_settings_update', { key: 'themeMode', value: 'dark' });
  await call(client, 'whph_settings_update', {
      key: 'themeMode',
      value: 'light',
      expectedRevision: setting.revision,
    });
  const usage = await call(client, 'whph_usage_list');
  await call(client, 'whph_sync_start');
  await call(client, 'whph_sync_stop');
  const exported = await call(client, 'whph_data_export', { format: 'json' });
  const operation = await callForApproval(client, 'whph_data_import_prepare', {
    sourceName: 'task-14-import.whph',
    strategy: 'merge',
  });
  const operationState = await call(client, 'whph_operations_get', {
      operationId: operation.operationId,
    });
  return { usage, operation, operationState };
}

async function runHappyScenario(endpoint, token) {
  const client = await connectModern({ endpoint, token });
  const suffix = `${Date.now()}-${process.pid}`;
  try {
    validateCatalog((await client.listTools(undefined, { cacheMode: 'refresh' })).tools);
    const tag = await call(client, 'whph_tags_create', { name: `MCP ${suffix}`, type: 'label' });
    const taskFlow = await createTaskFlow(client, suffix, tag.id);
    const habitFlow = await createHabitFlow(client, suffix);
    const noteFlow = await createNoteFlow(client, suffix, tag.id);
    const management = await runManagementFlow(client);
    return {
      suffix,
      taskId: taskFlow.task.id,
      childTaskId: taskFlow.child.id,
      taskRevision: taskFlow.reopened.revision,
      taskTimeRecordCount: taskFlow.timeRecordCount,
      goodHabitId: habitFlow.goodHabit.id,
      badHabitId: habitFlow.badHabit.id,
      noteId: noteFlow.note.id,
      noteRevision: noteFlow.editedNote.revision,
      usageItemCount: Array.isArray(management.usage.items) ? management.usage.items.length : -1,
      operationId: management.operation.operationId,
      operationStatus: management.operationState.status,
    };
  } finally {
    await client.close();
  }
}

async function verifyReadonly(endpoint, token) {
  const client = await connectModern({ endpoint, token });
  try {
    const tools = (await client.listTools(undefined, { cacheMode: 'refresh' })).tools;
    if (tools.length === 0) throw new Error('Readonly discovery unexpectedly returned no capabilities');
    const exposedMutation = tools.find((tool) => tool.annotations?.readOnlyHint !== true);
    if (exposedMutation) throw new Error(`Readonly discovery exposed ${exposedMutation.name}`);
    let deniedWrite = false;
    try {
      const result = await client.callTool({
        name: 'whph_tasks_create',
        arguments: { title: 'must not be created' },
      });
      deniedWrite = result.isError === true;
    } catch (error) {
      deniedWrite = error instanceof Error && error.name === 'ProtocolError';
    }
    if (!deniedWrite) throw new Error('Readonly token performed a write');
    return { toolCount: tools.length, deniedWrite: true };
  } finally {
    await client.close();
  }
}

async function verifyRevoked(endpoint, token) {
  try {
    const client = await connectModern({ endpoint, token });
    await client.close();
  } catch {
    return { connectionRejected: true };
  }
  throw new Error('Revoked token unexpectedly connected');
}

async function verifyDisconnectedWrite(endpoint, token) {
  const title = `MCP uncertain task ${Date.now()}-${process.pid}`;
  const loseWriteResponse = async (input, init) => {
    const response = await fetch(input, init);
    if (typeof init?.body === 'string' && init.body.includes('whph_tasks_create')) {
      await response.arrayBuffer();
      throw new Error('simulated response loss after server response');
    }
    return response;
  };
  const interruptedClient = await connectModern({ endpoint, token, fetchImpl: loseWriteResponse });
  try {
    await interruptedClient.listTools(undefined, { cacheMode: 'refresh' });
    await interruptedClient.callTool({ name: 'whph_tasks_create', arguments: { title } });
    throw new Error('Disconnected write unexpectedly returned a success response');
  } catch (error) {
    if (error instanceof Error && error.message.includes('unexpectedly returned')) throw error;
  } finally {
    await interruptedClient.close();
  }

  const readbackClient = await connectModern({ endpoint, token });
  try {
    const listed = await call(readbackClient, 'whph_tasks_list', { search: title });
    const matches = Array.isArray(listed.items)
      ? listed.items.filter((item) => item?.title === title)
      : [];
    if (matches.length !== 1) {
      throw new Error(`Disconnected write read-back found ${matches.length} matching tasks`);
    }
    return { readbackCount: matches.length, taskId: matches[0].id };
  } finally {
    await readbackClient.close();
  }
}

async function persistResult(result) {
  const outputPath = process.env.MCP_SMOKE_RESULT_PATH?.trim();
  if (!outputPath) return;
  await writeFile(outputPath, `${JSON.stringify(result)}\n`, { encoding: 'utf8', flag: 'wx' });
}

async function main() {
  const endpoint = smokeEndpoint();
  const token = requiredEnvironment('MCP_SMOKE_TOKEN');
  const mode = smokeMode();
  const result = mode === 'happy'
    ? {
        mode,
        modern: await verifyModernCatalog(endpoint, token),
        legacy: await verifyLegacyCatalog(endpoint, token),
        scenario: await runHappyScenario(endpoint, token),
      }
    : mode === 'readonly'
      ? { mode, readonly: await verifyReadonly(endpoint, token) }
      : mode === 'revoked'
        ? { mode, revoked: await verifyRevoked(endpoint, token) }
        : mode === 'disconnect'
          ? { mode, disconnect: await verifyDisconnectedWrite(endpoint, token) }
        : {
            mode,
            modern: await verifyModernCatalog(endpoint, token),
            legacy: await verifyLegacyCatalog(endpoint, token),
          };
  await persistResult(result);
  process.stdout.write(`WHPH MCP smoke passed: mode=${mode}\n`);
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : 'unknown smoke failure';
  process.stderr.write(`WHPH MCP smoke failed: ${message}\n`);
  process.exitCode = 1;
});
