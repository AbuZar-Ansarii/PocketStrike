import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcp_dart/mcp_dart.dart' show Tool;
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';
import '../../../core/storage/secure_keys.dart';
import '../data/mcp_connection_manager.dart';

/// Persisted server configs.
final mcpServersProvider = StreamProvider<List<McpServer>>((ref) {
  return ref.watch(appDatabaseProvider).mcpServersDao.watchAll();
});

/// Live connection states keyed by server id.
final mcpConnectionsProvider =
    NotifierProvider<McpConnectionsNotifier, Map<String, McpConnection>>(
        McpConnectionsNotifier.new);

class McpConnectionsNotifier extends Notifier<Map<String, McpConnection>> {
  late final McpConnectionManager manager;

  @override
  Map<String, McpConnection> build() {
    final dao = ref.watch(appDatabaseProvider).mcpServersDao;
    final secureKeys = ref.watch(secureKeyStoreProvider);
    manager = McpConnectionManager(
      onStatusChanged: (conn) {
        state = Map.from(state)..[conn.server.id] = conn;
      },
      persistStatus: dao.setStatus,
      getHeaders: (serverId) async {
        final raw = await secureKeys.readMcpHeaders(serverId);
        if (raw == null || raw.isEmpty) return const <String, String>{};
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        } catch (_) {}
        return const <String, String>{};
      },
    );
    ref.onDispose(manager.disposeAll);
    // Auto-connect enabled servers on startup.
    Future.microtask(connectEnabled);
    return const {};
  }

  Future<void> connectEnabled() async {
    final enabled = await ref.read(appDatabaseProvider).mcpServersDao.getEnabled();
    for (final server in enabled) {
      await manager.connect(server);
    }
  }

  Future<void> reconnect(McpServer server) => manager.connect(server);

  Future<void> disconnect(String serverId) => manager.disconnect(serverId);
}

/// CRUD + probe actions for MCP servers.
class McpActions {
  McpActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  McpServersDao get _dao => _db.mcpServersDao;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  /// Throws on connection failure; returns discovered tools on success.
  Future<List<Tool>> probe(
    String url,
    String transport, {
    Map<String, String> headers = const {},
  }) {
    return _ref.read(mcpConnectionsProvider.notifier).manager.probe(
          url,
          transport,
          headers: headers,
        );
  }

  Future<String> saveServer({
    String? id,
    required String name,
    required String url,
    required String transport,
    Map<String, String>? headers,
    bool connectNow = true,
  }) async {
    final serverId = id ?? _uuid.v4();
    if (headers != null && headers.isNotEmpty) {
      await _ref
          .read(secureKeyStoreProvider)
          .writeMcpHeaders(serverId, jsonEncode(headers));
    } else {
      await _ref.read(secureKeyStoreProvider).deleteMcpHeaders(serverId);
    }
    await _dao.upsert(McpServersCompanion.insert(
      id: serverId,
      name: name,
      transport: Value(transport),
      url: url,
      createdAt: DateTime.now(),
    ));
    if (connectNow) {
      final conn = _ref.read(mcpConnectionsProvider)[serverId];
      final server = McpServer(
        id: serverId,
        name: name,
        transport: transport,
        url: url,
        enabled: true,
        lastStatus: conn?.status.name ?? 'idle',
        toolConfirmations: '{}',
        createdAt: DateTime.now(),
      );
      await _ref.read(mcpConnectionsProvider.notifier).reconnect(server);
    }
    return serverId;
  }

  Future<void> deleteServer(String id) async {
    await _ref.read(mcpConnectionsProvider.notifier).disconnect(id);
    await _ref.read(secureKeyStoreProvider).deleteMcpHeaders(id);
    await _dao.deleteById(id);
  }

  Future<void> setEnabled(McpServer server, bool enabled) async {
    await _dao.setEnabled(server.id, enabled);
    if (enabled) {
      await _ref
          .read(mcpConnectionsProvider.notifier)
          .reconnect(server.copyWith(enabled: true));
    } else {
      await _ref.read(mcpConnectionsProvider.notifier).disconnect(server.id);
    }
  }

  /// Per-tool "confirm before running" toggles (JSON map in the DB row).
  Future<void> setToolConfirmation(
    McpServer server,
    String toolName,
    bool confirm,
  ) async {
    final map = <String, dynamic>{
      ..._decodeConfirmations(server.toolConfirmations),
      toolName: confirm,
    };
    await _dao.setToolConfirmations(server.id, jsonEncode(map));
  }

  static Map<String, dynamic> _decodeConfirmations(String json) {
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  /// Tool names the user explicitly wants to confirm for this server.
  static Set<String> forcedConfirmations(McpServer server) {
    final map = _decodeConfirmations(server.toolConfirmations);
    return {
      for (final entry in map.entries)
        if (entry.value == true) 'mcp__${server.id}__${entry.key}',
    };
  }
}

final mcpActionsProvider = Provider<McpActions>((ref) => McpActions(ref));
