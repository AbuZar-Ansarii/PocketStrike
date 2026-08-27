import 'dart:async';

import 'package:mcp_dart/mcp_dart.dart'
    show
        CallToolRequest,
        Implementation,
        McpClient,
        // ignore: deprecated_member_use — legacy SSE kept for old servers
        SseClientTransport,
        // ignore: deprecated_member_use
        SseClientTransportOptions,
        StreamableHttpClientTransport,
        StreamableHttpClientTransportOptions,
        TextContent,
        Tool,
        Transport;

import '../../../core/db/app_database.dart' show McpServer;
import '../../agent/domain/agent_tool.dart';

enum McpStatus { idle, connecting, connected, reconnecting, error }

/// Live state of one configured MCP server.
class McpConnection {
  const McpConnection({
    required this.server,
    required this.status,
    this.tools = const [],
    this.errorMessage,
  });

  final McpServer server;
  final McpStatus status;
  final List<AgentTool> tools;
  final String? errorMessage;

  McpConnection copyWith({
    McpStatus? status,
    List<AgentTool>? tools,
    String? errorMessage,
  }) =>
      McpConnection(
        server: server,
        status: status ?? this.status,
        tools: tools ?? this.tools,
        errorMessage: errorMessage,
      );
}

/// Holds live [McpClient] connections for all configured servers and
/// converts discovered tools into the agent's normalized [AgentTool] format.
class McpConnectionManager {
  McpConnectionManager({
    required this.onStatusChanged,
    required this.persistStatus,
    this.getHeaders,
  });

  /// Called whenever a server's status/tools change (drives UI dots).
  final void Function(McpConnection connection) onStatusChanged;

  /// Persists status text into the McpServers table.
  final Future<void> Function(String serverId, String status) persistStatus;

  /// Optional async loader for encrypted auth headers/tokens.
  final Future<Map<String, String>> Function(String serverId)? getHeaders;

  final Map<String, McpConnection> _connections = {};
  final Map<String, McpClient> _clients = {};
  final Map<String, int> _retryCounts = {};

  Map<String, McpConnection> get connections =>
      Map.unmodifiable(_connections);

  List<AgentTool> toolsForServers(Set<String> serverIds) => [
        for (final conn in _connections.values)
          if (conn.status == McpStatus.connected &&
              serverIds.contains(conn.server.id))
            ...conn.tools,
      ];

  Transport _buildTransport(
    McpServer server, {
    Map<String, String> headers = const {},
  }) {
    final uri = Uri.parse(server.url.trim());
    return switch (server.transport) {
      // ignore: deprecated_member_use — legacy SSE kept per brief for old servers
      'sse' => SseClientTransport(
          uri,
          // ignore: deprecated_member_use
          opts: SseClientTransportOptions(headers: headers),
        ),
      _ => StreamableHttpClientTransport(
          uri,
          opts: StreamableHttpClientTransportOptions(
            requestInit: headers.isNotEmpty ? {'headers': headers} : null,
          ),
        ),
    };
  }

  /// Classifies tool risk so read-only/safe tools execute automatically without confirmation prompts.
  ToolRisk _classifyToolRisk(String toolName, String? description) {
    final nameLower = toolName.toLowerCase();
    final descLower = (description ?? '').toLowerCase();

    // Destructive keywords
    if (nameLower.contains('delete') ||
        nameLower.contains('remove') ||
        nameLower.contains('kill') ||
        nameLower.contains('shutdown') ||
        nameLower.contains('restart') ||
        nameLower.contains('sleep') ||
        nameLower.contains('format') ||
        nameLower.contains('clear') ||
        nameLower.contains('drop') ||
        descLower.contains('irreversible') ||
        descLower.contains('warning: this will')) {
      return ToolRisk.destructive;
    }

    // Read-only / Safe query keywords -> run without confirmation prompt!
    if (nameLower.contains('add') ||
        nameLower.contains('calc') ||
        nameLower.contains('sum') ||
        nameLower.contains('get') ||
        nameLower.contains('list') ||
        nameLower.contains('read') ||
        nameLower.contains('search') ||
        nameLower.contains('fetch') ||
        nameLower.contains('query') ||
        nameLower.contains('generate') ||
        nameLower.contains('info') ||
        nameLower.contains('status') ||
        nameLower.contains('view') ||
        nameLower.contains('count') ||
        nameLower.contains('check') ||
        nameLower.contains('show') ||
        nameLower.contains('find') ||
        nameLower.contains('number') ||
        nameLower.contains('random')) {
      return ToolRisk.safe;
    }

    return ToolRisk.external;
  }

  /// Connects (or reconnects) one server and discovers its tools.
  Future<void> connect(McpServer server) async {
    await disconnect(server.id, silent: true);
    _setConnecting(server);

    final client = McpClient(
      const Implementation(name: 'PocketStrike', version: '1.0.0'),
    );

    try {
      final headers = await getHeaders?.call(server.id) ?? const <String, String>{};
      await client
          .connect(_buildTransport(server, headers: headers))
          .timeout(const Duration(seconds: 20));
      _clients[server.id] = client;

      final result = await client.listTools();
      final tools = [
        for (final tool in result.tools)
          AgentTool(
            name: 'mcp__${server.id}__${tool.name}',
            description: tool.description ?? tool.title ?? tool.name,
            inputSchema: _schemaToMap(tool),
            risk: _classifyToolRisk(tool.name, tool.description),
            mcpServerId: server.id,
            run: (args) => _callTool(server.id, tool.name, args),
          ),
      ];

      _retryCounts.remove(server.id);
      _connections[server.id] = McpConnection(
        server: server,
        status: McpStatus.connected,
        tools: tools,
      );
      await persistStatus(server.id, 'connected');
      onStatusChanged(_connections[server.id]!);
    } catch (e) {
      _connections[server.id] = McpConnection(
        server: server,
        status: McpStatus.error,
        errorMessage: e.toString(),
      );
      await persistStatus(server.id, 'error');
      onStatusChanged(_connections[server.id]!);
      _scheduleReconnect(server);
    }
  }

  void _setConnecting(McpServer server) {
    _connections[server.id] = McpConnection(
      server: server,
      status: McpStatus.connecting,
    );
    onStatusChanged(_connections[server.id]!);
  }

  Map<String, dynamic> _schemaToMap(Tool tool) {
    try {
      return tool.inputSchema.toJson();
    } catch (_) {
      return const {'type': 'object', 'properties': <String, dynamic>{}};
    }
  }

  Future<String> _callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final client = _clients[serverId];
    if (client == null) {
      throw StateError('MCP server "$serverId" is not connected.');
    }
    final result = await client.callTool(
      CallToolRequest(name: toolName, arguments: args),
    );
    final buffer = StringBuffer();
    for (final content in result.content) {
      if (content is TextContent) {
        buffer.writeln(content.text);
      } else {
        buffer.writeln('[${content.type} content]');
      }
    }
    final text = buffer.toString().trim();
    if (result.isError) {
      throw StateError(text.isEmpty ? 'MCP tool returned an error' : text);
    }
    return text.isEmpty ? '(no output)' : text;
  }

  /// One-shot connectivity probe used by the "Connect MCP Server" sheet.
  /// Returns discovered tools on success; throws on failure.
  Future<List<Tool>> probe(
    String url,
    String transport, {
    Map<String, String> headers = const {},
  }) async {
    final probeServer = McpServer(
      id: 'probe',
      name: 'probe',
      transport: transport,
      url: url.trim(),
      enabled: true,
      lastStatus: 'idle',
      toolConfirmations: '{}',
      createdAt: DateTime.now(),
    );
    final client = McpClient(
      const Implementation(name: 'PocketStrike', version: '1.0.0'),
    );
    try {
      await client
          .connect(_buildTransport(probeServer, headers: headers))
          .timeout(const Duration(seconds: 20));
      final result = await client.listTools();
      return result.tools;
    } finally {
      unawaited(client.close());
    }
  }

  Future<void> disconnect(String serverId, {bool silent = false}) async {
    final client = _clients.remove(serverId);
    if (client != null) {
      unawaited(client.close());
    }
    if (!silent) {
      final conn = _connections[serverId];
      if (conn != null) {
        _connections[serverId] = McpConnection(
          server: conn.server,
          status: McpStatus.idle,
        );
        await persistStatus(serverId, 'idle');
        onStatusChanged(_connections[serverId]!);
      }
    }
  }

  void _scheduleReconnect(McpServer server) {
    final retries = (_retryCounts[server.id] ?? 0) + 1;
    _retryCounts[server.id] = retries;
    if (retries > 3) return; // give up after 3 attempts

    final delay = Duration(seconds: 5 * retries);
    unawaited(Future.delayed(delay, () async {
      final conn = _connections[server.id];
      if (conn == null || conn.status == McpStatus.connected) return;
      if (!conn.server.enabled) return;
      _connections[server.id] =
          conn.copyWith(status: McpStatus.reconnecting);
      onStatusChanged(_connections[server.id]!);
      await connect(server);
    }));
  }

  Future<void> disposeAll() async {
    for (final id in _clients.keys.toList()) {
      await disconnect(id);
    }
  }
}
