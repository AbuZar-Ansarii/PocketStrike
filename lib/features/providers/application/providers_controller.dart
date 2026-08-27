import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';
import '../../../core/models/chat_models.dart';
import '../../../core/storage/secure_keys.dart';
import '../../agent/data/built_in_tools.dart';
import '../../agent/data/cron_task_store.dart';
import '../../agent/data/hermes_memory_store.dart';
import '../../agent/domain/agent_tool.dart';
import '../../conversations/application/conversations_controller.dart';
import '../../mcp/application/mcp_controller.dart';
import '../../mcp/data/mcp_connection_manager.dart';
import '../data/mock_provider.dart';
import '../data/provider_registry.dart';
import '../domain/ai_provider.dart';
import '../domain/provider_types.dart';

/// Live list of configured providers (keys never included).
final providerConfigsProvider = StreamProvider<List<ProviderConfig>>((ref) {
  return ref.watch(appDatabaseProvider).providerConfigsDao.watchAll();
});

/// Default active provider config.
final activeProviderConfigProvider = FutureProvider<ProviderConfig?>((ref) async {
  return ref.watch(appDatabaseProvider).providerConfigsDao.getDefault();
});

/// Resolves stored configs (+ secure keys) into ready [AIProvider] instances.
class ProviderResolver {
  ProviderResolver(this._ref);

  final Ref _ref;

  /// Picks [configId] if given, otherwise the default provider.
  /// Returns null when nothing is configured.
  Future<AIProvider?> resolve({String? configId}) async {
    final dao = _ref.read(appDatabaseProvider).providerConfigsDao;
    ProviderConfig? config;
    if (configId != null) {
      final all = await dao.getAll();
      config = all.where((c) => c.id == configId).firstOrNull;
    }
    config ??= await dao.getDefault();
    if (config == null) return null;

    final key =
        await _ref.read(secureKeyStoreProvider).readProviderKey(config.id);
    return ProviderRegistry.build(config, key);
  }

  /// The built-in offline demo provider (not persisted).
  AIProvider mock() => const MockProvider();

  /// Available tools for this conversation's enabled MCP servers + built-in tools.
  Future<List<AgentTool>> availableTools(String conversationId) async {
    final db = _ref.read(appDatabaseProvider);
    final conv = await db.conversationsDao.getById(conversationId);
    final enabledServers = await db.mcpServersDao.getEnabled();
    final enabledServerIds = enabledServers.map((s) => s.id).toSet();

    Set<String> activeIds;
    if (conv != null && conv.enabledMcpServerIds.isNotEmpty) {
      activeIds = conv.enabledMcpServerIds.intersection(enabledServerIds);
    } else {
      activeIds = enabledServerIds;
    }

    final manager = _ref.read(mcpConnectionsProvider.notifier).manager;

    // Ensure enabled active servers are connected
    for (final server in enabledServers) {
      if (activeIds.contains(server.id)) {
        final conn = manager.connections[server.id];
        if (conn == null || conn.status != McpStatus.connected) {
          await manager.connect(server);
        }
      }
    }

    final hermesTools = _ref.read(hermesMemoryProvider.notifier).buildTools();
    final cronTools = _ref.read(cronTaskProvider.notifier).buildTools();

    return [
      ...hermesTools,
      ...cronTools,
      ...BuiltInTools.all(),
      ...manager.toolsForServers(activeIds),
    ];
  }

  /// Forced MCP confirmations set.
  Future<Set<String>> forcedMcpConfirmations(String conversationId) async {
    final db = _ref.read(appDatabaseProvider);
    final enabledServers = await db.mcpServersDao.getEnabled();
    final result = <String>{};
    for (final server in enabledServers) {
      result.addAll(McpActions.forcedConfirmations(server));
    }
    return result;
  }

  /// The generation params stored on the config row.
  Future<GenerationParams> paramsFor(String configId) async {
    final all = await _ref.read(appDatabaseProvider).providerConfigsDao.getAll();
    final config = all.where((c) => c.id == configId).firstOrNull;
    if (config == null) return const GenerationParams();
    try {
      return GenerationParams.fromJson(
        jsonDecode(config.paramsJson) as Map<String, dynamic>,
      );
    } on FormatException {
      return const GenerationParams();
    }
  }
}

final providerResolverProvider =
    Provider<ProviderResolver>((ref) => ProviderResolver(ref));

/// CRUD actions for provider configs + their secure keys.
class ProviderActions {
  ProviderActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  ProviderConfigsDao get _dao =>
      _ref.read(appDatabaseProvider).providerConfigsDao;

  Future<String> saveProvider({
    String? id,
    required ProviderType type,
    required String name,
    required String baseUrl,
    required String defaultModel,
    required GenerationParams params,
    String? apiKey, // null = keep existing / not set
    bool makeDefault = false,
  }) async {
    final configId = id ?? _uuid.v4();
    final hasNewKey = apiKey != null && apiKey.isNotEmpty;

    final existing =
        (await _dao.getAll()).where((c) => c.id == configId).firstOrNull;

    await _dao.upsert(ProviderConfigsCompanion.insert(
      id: configId,
      type: type.id,
      name: name,
      baseUrl: Value(baseUrl),
      defaultModel: Value(defaultModel),
      paramsJson: Value(jsonEncode(params.toJson())),
      hasKey: Value(hasNewKey || (existing?.hasKey ?? false)),
      createdAt: existing?.createdAt ?? DateTime.now(),
      isDefault: Value(makeDefault || (existing?.isDefault ?? false)),
    ));

    final store = _ref.read(secureKeyStoreProvider);
    if (hasNewKey) {
      await store.writeProviderKey(configId, apiKey);
    }

    final all = await _dao.getAll();
    if (makeDefault || all.length == 1) {
      await _dao.setDefault(configId);
    }
    return configId;
  }

  Future<void> deleteProvider(String configId) async {
    await _ref.read(secureKeyStoreProvider).deleteProviderKey(configId);
    await _dao.deleteById(configId);
  }

  Future<void> setDefault(String configId) => _dao.setDefault(configId);

  /// Returns null on success, an error message on failure.
  Future<String?> testConnection(AIProvider provider) async {
    try {
      await provider.listModels();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<String>> fetchModels(AIProvider provider) =>
      provider.listModels();
}

final providerActionsProvider =
    Provider<ProviderActions>((ref) => ProviderActions(ref));
