import 'package:drift/drift.dart';

/// Conversation threads shown in the sidebar.
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('New chat'))();
  TextColumn get personaId => text().nullable()();
  TextColumn get providerId => text().nullable()();
  TextColumn get model => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  /// Set when this conversation branched from another one.
  TextColumn get branchedFromId => text().nullable()();

  /// `app` or `telegram` — used for the sidebar tag icon.
  TextColumn get source => text().withDefault(const Constant('app'))();

  /// JSON array of MCP server ids enabled for this conversation.
  TextColumn get mcpServerIds =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Individual chat messages.
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id,
      onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // system|user|assistant|tool
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get toolCallsJson => text().nullable()();
  TextColumn get toolCallId => text().nullable()();
  TextColumn get toolName => text().nullable()();
  TextColumn get attachmentsJson => text().nullable()();
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Agent personas / system prompts, switchable per conversation.
class Personas extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  TextColumn get icon => text().withDefault(const Constant('robot'))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Saved MCP server connection configs.
class McpServers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `streamableHttp` or `sse`.
  TextColumn get transport =>
      text().withDefault(const Constant('streamableHttp'))();
  TextColumn get url => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get lastStatus => text().withDefault(const Constant('idle'))();

  /// JSON object: toolName -> bool (true = confirm before running).
  TextColumn get toolConfirmations =>
      text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Non-secret AI provider configuration (keys live in secure storage).
class ProviderConfigs extends Table {
  TextColumn get id => text()();

  /// openai|anthropic|gemini|groq|openrouter|ollama|custom
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text().withDefault(const Constant(''))();
  TextColumn get defaultModel => text().withDefault(const Constant(''))();
  TextColumn get paramsJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get hasKey => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Persisted agent runs (tool-call timelines) for the Run Viewer.
class AgentRuns extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get triggerMessageId => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('running'))(); // running|done|error|cancelled
  TextColumn get stepsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
