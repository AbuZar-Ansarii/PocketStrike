import '../../providers/domain/provider_types.dart';

/// How dangerous a tool invocation can be — drives the confirmation policy.
enum ToolRisk {
  /// Read-only, local, reversible (time, calculator, list_files...).
  safe,

  /// Touches the network or third parties (MCP calls, web, Telegram).
  external,

  /// Irreversible or hard to reverse (delete/overwrite/move files).
  destructive,
}

/// When the agent should pause for a one-tap user confirmation.
enum ConfirmationPolicy {
  /// Confirm every tool call.
  alwaysAsk,

  /// Confirm only `external` and `destructive` tools (default).
  destructiveOnly,

  /// Never confirm (power users).
  autonomous,
}

extension ConfirmationPolicyX on ConfirmationPolicy {
  String get id => switch (this) {
        ConfirmationPolicy.alwaysAsk => 'alwaysAsk',
        ConfirmationPolicy.destructiveOnly => 'destructiveOnly',
        ConfirmationPolicy.autonomous => 'autonomous',
      };

  String get label => switch (this) {
        ConfirmationPolicy.alwaysAsk => 'Always ask',
        ConfirmationPolicy.destructiveOnly => 'Ask for risky actions only',
        ConfirmationPolicy.autonomous => 'Autonomous (no confirmations)',
      };

  static ConfirmationPolicy fromId(String? id) => switch (id) {
        'alwaysAsk' => ConfirmationPolicy.alwaysAsk,
        'autonomous' => ConfirmationPolicy.autonomous,
        _ => ConfirmationPolicy.destructiveOnly,
      };
}

/// Normalized tool used by the agent engine.
///
/// Built-in tools, MCP tools and future storage tools all converge here;
/// adapters convert to OpenAI functions / Anthropic tool_use / MCP schemas.
class AgentTool {
  const AgentTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.risk,
    required this.run,
    this.mcpServerId,
  });

  /// Unique name — MCP tools are namespaced `mcp__<server>__<tool>`.
  final String name;
  final String description;

  /// JSON Schema (object root) for the tool's arguments.
  final Map<String, dynamic> inputSchema;
  final ToolRisk risk;

  /// Executes the tool; returns a string observation for the model.
  final Future<String> Function(Map<String, dynamic> args) run;

  /// Set when this tool comes from an MCP server.
  final String? mcpServerId;

  ProviderToolSpec toSpec() => ProviderToolSpec(
        name: name,
        description: description,
        parameters: inputSchema,
      );
}
