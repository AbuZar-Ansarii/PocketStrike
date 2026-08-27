// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daos.dart';

// ignore_for_file: type=lint
mixin _$ConversationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ConversationsTable get conversations => attachedDatabase.conversations;
  ConversationsDaoManager get managers => ConversationsDaoManager(this);
}

class ConversationsDaoManager {
  final _$ConversationsDaoMixin _db;
  ConversationsDaoManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db.attachedDatabase, _db.conversations);
}

mixin _$MessagesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ConversationsTable get conversations => attachedDatabase.conversations;
  $MessagesTable get messages => attachedDatabase.messages;
  MessagesDaoManager get managers => MessagesDaoManager(this);
}

class MessagesDaoManager {
  final _$MessagesDaoMixin _db;
  MessagesDaoManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db.attachedDatabase, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
}

mixin _$PersonasDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonasTable get personas => attachedDatabase.personas;
  PersonasDaoManager get managers => PersonasDaoManager(this);
}

class PersonasDaoManager {
  final _$PersonasDaoMixin _db;
  PersonasDaoManager(this._db);
  $$PersonasTableTableManager get personas =>
      $$PersonasTableTableManager(_db.attachedDatabase, _db.personas);
}

mixin _$McpServersDaoMixin on DatabaseAccessor<AppDatabase> {
  $McpServersTable get mcpServers => attachedDatabase.mcpServers;
  McpServersDaoManager get managers => McpServersDaoManager(this);
}

class McpServersDaoManager {
  final _$McpServersDaoMixin _db;
  McpServersDaoManager(this._db);
  $$McpServersTableTableManager get mcpServers =>
      $$McpServersTableTableManager(_db.attachedDatabase, _db.mcpServers);
}

mixin _$ProviderConfigsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProviderConfigsTable get providerConfigs => attachedDatabase.providerConfigs;
  ProviderConfigsDaoManager get managers => ProviderConfigsDaoManager(this);
}

class ProviderConfigsDaoManager {
  final _$ProviderConfigsDaoMixin _db;
  ProviderConfigsDaoManager(this._db);
  $$ProviderConfigsTableTableManager get providerConfigs =>
      $$ProviderConfigsTableTableManager(
        _db.attachedDatabase,
        _db.providerConfigs,
      );
}

mixin _$AgentRunsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AgentRunsTable get agentRuns => attachedDatabase.agentRuns;
  AgentRunsDaoManager get managers => AgentRunsDaoManager(this);
}

class AgentRunsDaoManager {
  final _$AgentRunsDaoMixin _db;
  AgentRunsDaoManager(this._db);
  $$AgentRunsTableTableManager get agentRuns =>
      $$AgentRunsTableTableManager(_db.attachedDatabase, _db.agentRuns);
}
