import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Conversations])
class ConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationsDaoMixin {
  ConversationsDao(super.db);

  /// Pinned first, then most recently updated.
  Stream<List<Conversation>> watchAll() {
    final query = select(conversations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.pinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.watch();
  }

  Future<List<Conversation>> getAll() => select(conversations).get();

  Future<Conversation?> getById(String id) =>
      (select(conversations)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsert(ConversationsCompanion entry) =>
      into(conversations).insertOnConflictUpdate(entry);

  Future<void> rename(String id, String title) =>
      (update(conversations)..where((t) => t.id.equals(id)))
          .write(ConversationsCompanion(title: Value(title)));

  Future<void> setPinned(String id, bool pinned) =>
      (update(conversations)..where((t) => t.id.equals(id)))
          .write(ConversationsCompanion(pinned: Value(pinned)));

  Future<void> touch(String id) =>
      (update(conversations)..where((t) => t.id.equals(id)))
          .write(ConversationsCompanion(updatedAt: Value(DateTime.now())));

  Future<void> setProviderAndModel(
    String id, {
    String? providerId,
    String? model,
  }) =>
      (update(conversations)..where((t) => t.id.equals(id))).write(
        ConversationsCompanion(
          providerId: Value(providerId),
          model: Value(model),
        ),
      );

  Future<void> setMcpServerIds(String id, String jsonIds) =>
      (update(conversations)..where((t) => t.id.equals(id)))
          .write(ConversationsCompanion(mcpServerIds: Value(jsonIds)));

  Future<int> deleteById(String id) =>
      (delete(conversations)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Messages])
class MessagesDao extends DatabaseAccessor<AppDatabase>
    with _$MessagesDaoMixin {
  MessagesDao(super.db);

  Stream<List<Message>> watchForConversation(String conversationId) {
    final query = select(messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch();
  }

  Future<List<Message>> getForConversation(String conversationId) {
    final query = select(messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }

  Future<void> insertMessage(MessagesCompanion entry) =>
      into(messages).insertOnConflictUpdate(entry);

  Future<void> updateContent(String id, String content) =>
      (update(messages)..where((t) => t.id.equals(id)))
          .write(MessagesCompanion(content: Value(content)));

  /// Deletes the message and everything after it (edit-and-resend).
  Future<int> deleteFrom(String conversationId, DateTime from) =>
      (delete(messages)
            ..where((t) =>
                t.conversationId.equals(conversationId) &
                t.createdAt.isBiggerOrEqualValue(from)))
          .go();

  Future<int> deleteForConversation(String conversationId) =>
      (delete(messages)..where((t) => t.conversationId.equals(conversationId)))
          .go();
}

@DriftAccessor(tables: [Personas])
class PersonasDao extends DatabaseAccessor<AppDatabase>
    with _$PersonasDaoMixin {
  PersonasDao(super.db);

  Stream<List<Persona>> watchAll() => select(personas).watch();

  Future<List<Persona>> getAll() => select(personas).get();

  Future<void> upsert(PersonasCompanion entry) =>
      into(personas).insertOnConflictUpdate(entry);

  Future<int> deleteById(String id) =>
      (delete(personas)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [McpServers])
class McpServersDao extends DatabaseAccessor<AppDatabase>
    with _$McpServersDaoMixin {
  McpServersDao(super.db);

  Stream<List<McpServer>> watchAll() => select(mcpServers).watch();

  Future<List<McpServer>> getEnabled() =>
      (select(mcpServers)..where((t) => t.enabled.equals(true))).get();

  Future<void> upsert(McpServersCompanion entry) =>
      into(mcpServers).insertOnConflictUpdate(entry);

  Future<void> setStatus(String id, String status) =>
      (update(mcpServers)..where((t) => t.id.equals(id)))
          .write(McpServersCompanion(lastStatus: Value(status)));

  Future<void> setEnabled(String id, bool enabled) =>
      (update(mcpServers)..where((t) => t.id.equals(id)))
          .write(McpServersCompanion(enabled: Value(enabled)));

  Future<void> setToolConfirmations(String id, String json) =>
      (update(mcpServers)..where((t) => t.id.equals(id)))
          .write(McpServersCompanion(toolConfirmations: Value(json)));

  Future<int> deleteById(String id) =>
      (delete(mcpServers)..where((t) => t.id.equals(id))).go();
}


@DriftAccessor(tables: [ProviderConfigs])
class ProviderConfigsDao extends DatabaseAccessor<AppDatabase>
    with _$ProviderConfigsDaoMixin {
  ProviderConfigsDao(super.db);

  Stream<List<ProviderConfig>> watchAll() => select(providerConfigs).watch();

  Future<List<ProviderConfig>> getAll() => select(providerConfigs).get();

  Future<ProviderConfig?> getDefault() async {
    final explicit = await (select(providerConfigs)
          ..where((t) => t.isDefault.equals(true)))
        .getSingleOrNull();
    if (explicit != null) return explicit;
    final all = await select(providerConfigs).get();
    return all.firstOrNull;
  }

  Future<void> upsert(ProviderConfigsCompanion entry) =>
      into(providerConfigs).insertOnConflictUpdate(entry);

  Future<void> setDefault(String id) async {
    await transaction(() async {
      await update(providerConfigs)
          .write(const ProviderConfigsCompanion(isDefault: Value(false)));
      await (update(providerConfigs)..where((t) => t.id.equals(id)))
          .write(const ProviderConfigsCompanion(isDefault: Value(true)));
    });
  }

  Future<void> setHasKey(String id, bool hasKey) =>
      (update(providerConfigs)..where((t) => t.id.equals(id)))
          .write(ProviderConfigsCompanion(hasKey: Value(hasKey)));

  Future<int> deleteById(String id) =>
      (delete(providerConfigs)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [AgentRuns])
class AgentRunsDao extends DatabaseAccessor<AppDatabase>
    with _$AgentRunsDaoMixin {
  AgentRunsDao(super.db);

  Stream<List<AgentRun>> watchForConversation(String conversationId) {
    final query = select(agentRuns)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  Future<AgentRun?> getById(String id) =>
      (select(agentRuns)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(AgentRunsCompanion entry) =>
      into(agentRuns).insertOnConflictUpdate(entry);

  Future<void> updateRun(String id, String status, String stepsJson) =>
      (update(agentRuns)..where((t) => t.id.equals(id))).write(
        AgentRunsCompanion(status: Value(status), stepsJson: Value(stepsJson)),
      );
}
