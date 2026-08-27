import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcp_dart/mcp_dart.dart' show Tool;
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/features/mcp/application/mcp_controller.dart';
import 'package:pocketstrike/features/mcp/ui/mcp_marketplace_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

enum _AuthMode { none, token, oauth }

/// Bottom sheet flow for "🔌 Connect MCP Server":
/// quick presets + name + URL + transport + authentication (Header/Token & Generic OAuth) → test → preview discovered tools → save.
///
/// Keyboard-aware with dynamic bottom inset padding and max height constraints.
class ConnectMcpSheet extends ConsumerStatefulWidget {
  const ConnectMcpSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConnectMcpSheet(),
    );
  }

  @override
  ConsumerState<ConnectMcpSheet> createState() => _ConnectMcpSheetState();
}

class _ConnectMcpSheetState extends ConsumerState<ConnectMcpSheet> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  String _transport = 'streamableHttp';

  // Auth State
  _AuthMode _authMode = _AuthMode.none;

  // Header / Token Mode Controllers
  final _tokenController = TextEditingController();
  final _headerNameController = TextEditingController(text: 'Authorization');
  bool _isBearer = true;
  bool _obscureToken = true;

  // OAuth Mode Controllers
  String _oauthProvider = 'custom'; // 'custom' | 'notion' | 'linear' | 'slack' | 'github'
  final _oauthTokenController = TextEditingController();
  final _oauthAuthUrlController = TextEditingController();
  final _oauthHeaderNameController = TextEditingController(text: 'Authorization');
  bool _obscureOAuthToken = true;

  bool _testing = false;
  String? _error;
  List<Tool>? _discoveredTools;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _headerNameController.dispose();
    _oauthTokenController.dispose();
    _oauthAuthUrlController.dispose();
    _oauthHeaderNameController.dispose();
    super.dispose();
  }

  /// Automatically parses URLs to extract tokens from query params or fragment hashes.
  String _extractToken(String input) {
    final trimmed = input.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    // Check fragment: e.g. https://app.com/callback#access_token=12345&token_type=bearer
    if (uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      if (fragmentParams.containsKey('access_token')) {
        return fragmentParams['access_token']!;
      }
      if (fragmentParams.containsKey('token')) {
        return fragmentParams['token']!;
      }
      if (fragmentParams.containsKey('code')) {
        return fragmentParams['code']!;
      }
    }

    // Check query params: e.g. https://app.com/callback?access_token=12345
    if (uri.queryParameters.containsKey('access_token')) {
      return uri.queryParameters['access_token']!;
    }
    if (uri.queryParameters.containsKey('token')) {
      return uri.queryParameters['token']!;
    }
    if (uri.queryParameters.containsKey('code')) {
      return uri.queryParameters['code']!;
    }
    if (uri.queryParameters.containsKey('key')) {
      return uri.queryParameters['key']!;
    }

    return trimmed;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{};
    if (_authMode == _AuthMode.token) {
      final token = _tokenController.text.trim();
      if (token.isNotEmpty) {
        if (_isBearer) {
          final val = token.startsWith('Bearer ') ? token : 'Bearer $token';
          headers['Authorization'] = val;
        } else {
          final headerKey = _headerNameController.text.trim().isNotEmpty
              ? _headerNameController.text.trim()
              : 'Authorization';
          headers[headerKey] = token;
        }
      }
    } else if (_authMode == _AuthMode.oauth) {
      final rawToken = _oauthTokenController.text.trim();
      final token = _extractToken(rawToken);
      if (token.isNotEmpty) {
        final headerKey = _oauthHeaderNameController.text.trim().isNotEmpty
            ? _oauthHeaderNameController.text.trim()
            : 'Authorization';
        if (headerKey.toLowerCase() == 'authorization') {
          final val = token.startsWith('Bearer ') ? token : 'Bearer $token';
          headers['Authorization'] = val;
        } else {
          headers[headerKey] = token;
        }

        if (_oauthProvider == 'notion') {
          headers['Notion-Version'] = '2022-06-28';
        } else if (_oauthProvider == 'github') {
          headers['User-Agent'] = 'PocketStrike-MCP';
        }
      }
    }
    return headers;
  }

  void _applyPreset({
    required String name,
    required String url,
    required String transport,
    _AuthMode authMode = _AuthMode.none,
    String? oauthProvider,
    String? oauthAuthUrl,
  }) {
    setState(() {
      _nameController.text = name;
      _urlController.text = url;
      _transport = transport;
      _authMode = authMode;
      if (oauthProvider != null) {
        _oauthProvider = oauthProvider;
      }
      if (oauthAuthUrl != null) {
        _oauthAuthUrlController.text = oauthAuthUrl;
      }
      _error = null;
      _discoveredTools = null;
    });
  }

  Future<void> _pasteTo(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      final raw = data.text!.trim();
      final extracted = _extractToken(raw);
      setState(() {
        controller.text = extracted;
      });
      if (extracted != raw && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Auto-extracted access token from callback URL!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _launchExternalUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _test() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Enter a server URL first.');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
      _discoveredTools = null;
    });
    try {
      final headers = _buildHeaders();
      final tools = await ref
          .read(mcpActionsProvider)
          .probe(url, _transport, headers: headers);
      setState(() => _discoveredTools = tools);
      HapticFeedback.mediumImpact();
    } catch (e) {
      final cleanMsg = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('StateError: ', '');
      setState(() => _error = cleanMsg);
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim().isEmpty
        ? Uri.tryParse(url)?.host ?? 'MCP Server'
        : _nameController.text.trim();
    if (url.isEmpty) return;
    HapticFeedback.selectionClick();
    final headers = _buildHeaders();
    await ref.read(mcpActionsProvider).saveServer(
          name: name,
          url: url,
          transport: _transport,
          headers: headers.isNotEmpty ? headers : null,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Connected "$name" successfully!'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.90,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusLg),
          ),
          border: Border(top: BorderSide(color: tokens.glassBorder)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Icon + Title on left, Sleek & Small Explore button at top right corner
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tokens.accent.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(AppIcons.plug, color: tokens.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connect MCP Server',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Small Explore Button placed at top right corner
                  Material(
                    color: tokens.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                        McpMarketplaceSheet.show(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: tokens.accent.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.accent.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIcons.sparkles,
                                size: 12, color: tokens.accent),
                            const SizedBox(width: 4),
                            Text(
                              'Explore',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Connect Model Context Protocol (MCP) servers to give your AI agent live external tools.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: tokens.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),

              // Quick Presets
              Text(
                'QUICK PRESETS',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: tokens.textSecondary,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(AppIcons.zap, size: 14),
                      label: const Text('FastMCP Calc'),
                      backgroundColor: tokens.glassColor,
                      onPressed: () => _applyPreset(
                        name: 'FastMCP Calculator',
                        url: 'https://bizarre-gold-antelope.fastmcp.app/mcp',
                        transport: 'streamableHttp',
                        authMode: _AuthMode.none,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(AppIcons.smartphone, size: 14),
                      label: const Text('PC Tools (SSE)'),
                      backgroundColor: tokens.glassColor,
                      onPressed: () => _applyPreset(
                        name: 'Local PC Tools',
                        url: 'http://10.84.104.59:8000/sse',
                        transport: 'sse',
                        authMode: _AuthMode.none,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.menu_book_rounded, size: 14),
                      label: const Text('Notion MCP'),
                      backgroundColor: tokens.glassColor,
                      onPressed: () => _applyPreset(
                        name: 'Notion MCP',
                        url: 'https://api.smithery.ai/mcp/v1/notion',
                        transport: 'streamableHttp',
                        authMode: _AuthMode.oauth,
                        oauthProvider: 'notion',
                        oauthAuthUrl: 'https://www.notion.so/my-integrations',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(AppIcons.code, size: 14),
                      label: const Text('GitHub MCP'),
                      backgroundColor: tokens.glassColor,
                      onPressed: () => _applyPreset(
                        name: 'GitHub MCP',
                        url: 'https://api.smithery.ai/mcp/v1/github',
                        transport: 'streamableHttp',
                        authMode: _AuthMode.token,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 14),
                      label: const Text('Linear MCP'),
                      backgroundColor: tokens.glassColor,
                      onPressed: () => _applyPreset(
                        name: 'Linear MCP',
                        url: 'https://api.smithery.ai/mcp/v1/linear',
                        transport: 'streamableHttp',
                        authMode: _AuthMode.oauth,
                        oauthProvider: 'linear',
                        oauthAuthUrl: 'https://linear.app/settings/api',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(AppIcons.brain, size: 14),
                      label: const Text('Local Memory'),
                      backgroundColor: tokens.glassColor,
                      onPressed: () => _applyPreset(
                        name: 'Memory Server',
                        url: 'http://localhost:8080/mcp',
                        transport: 'streamableHttp',
                        authMode: _AuthMode.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Server Name Input
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Server Name (optional)',
                  hintText: 'e.g. Linear MCP / Notion MCP / GitHub MCP',
                  filled: true,
                  fillColor: tokens.glassColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide(color: tokens.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide(color: tokens.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide(color: tokens.accent, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Server URL Input
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Server URL',
                  hintText: _transport == 'sse'
                      ? 'http://10.84.104.59:8000/sse'
                      : 'https://mcp.example.com/mcp',
                  filled: true,
                  fillColor: tokens.glassColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide(color: tokens.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide(color: tokens.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide(color: tokens.accent, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Transport Selection: Two Switch Buttons (HTTP MCP / SSE MCP)
              Text(
                'TRANSPORT TYPE',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: tokens.textSecondary,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TransportSwitchButton(
                      label: 'HTTP MCP',
                      subtitle: 'Streamable HTTP',
                      icon: AppIcons.globe,
                      isSelected: _transport == 'streamableHttp',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _transport = 'streamableHttp');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TransportSwitchButton(
                      label: 'SSE MCP',
                      subtitle: 'Server-Sent Events',
                      icon: Icons.wifi_tethering_rounded,
                      isSelected: _transport == 'sse',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _transport = 'sse');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // -------------------------------------------------------------
              // Authentication & Credentials Section
              // -------------------------------------------------------------
              Text(
                'AUTHENTICATION & CREDENTIALS',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: tokens.textSecondary,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 8),

              // 3 Auth Modes Switch (None, Header / Token, OAuth 2.0)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: tokens.glassColor,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(color: tokens.glassBorder, width: 0.8),
                ),
                child: Row(
                  children: [
                    _buildAuthModeTab(
                      label: 'None (Public)',
                      mode: _AuthMode.none,
                      icon: Icons.lock_open_rounded,
                    ),
                    _buildAuthModeTab(
                      label: 'Header / Token',
                      mode: _AuthMode.token,
                      icon: AppIcons.key,
                    ),
                    _buildAuthModeTab(
                      label: 'OAuth 2.0',
                      mode: _AuthMode.oauth,
                      icon: Icons.verified_user_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Auth Mode 1: Header / Token Details
              if (_authMode == _AuthMode.token) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.glassColor,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(AppIcons.key, color: tokens.accent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Header Authentication',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          // Toggle between Bearer Auth vs Custom Header Key
                          InkWell(
                            onTap: () {
                              setState(() => _isBearer = !_isBearer);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tokens.accent.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                _isBearer ? 'Bearer Auth' : 'Custom Header',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: tokens.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (!_isBearer) ...[
                        TextField(
                          controller: _headerNameController,
                          decoration: InputDecoration(
                            labelText: 'Header Key Name',
                            hintText: 'e.g. X-API-Key, Notion-Version',
                            filled: true,
                            fillColor: tokens.glassColor,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              borderSide: BorderSide(color: tokens.glassBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Token Input
                      TextField(
                        controller: _tokenController,
                        obscureText: _obscureToken,
                        decoration: InputDecoration(
                          labelText: _isBearer
                              ? 'Access Token / PAT'
                              : 'Header Value',
                          hintText: _isBearer
                              ? 'e.g. ghp_... or ntn_... or eyJ...'
                              : 'e.g. secret_api_key_here',
                          filled: true,
                          fillColor: tokens.glassColor,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            borderSide: BorderSide(color: tokens.glassBorder),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _obscureToken
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 18,
                                  color: tokens.textSecondary,
                                ),
                                onPressed: () => setState(
                                    () => _obscureToken = !_obscureToken),
                              ),
                              IconButton(
                                icon: Icon(Icons.paste_rounded,
                                    size: 18, color: tokens.accent),
                                tooltip: 'Paste Token',
                                onPressed: () => _pasteTo(_tokenController),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isBearer
                            ? 'Attached as "Authorization: Bearer <token>" on every HTTP/SSE MCP call.'
                            : 'Attached as custom header on all MCP requests.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Auth Mode 2: Generic OAuth 2.0 Details
              if (_authMode == _AuthMode.oauth) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.glassColor,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user_rounded,
                              color: tokens.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OAuth 2.0 Authentication',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  'Works with any MCP server that uses OAuth 2.0 authorization.',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quick Provider Shortcuts
                      Text(
                        'QUICK SHORTCUTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildOAuthProviderChip(
                              id: 'custom',
                              label: 'Any OAuth MCP',
                              icon: AppIcons.globe,
                              defaultAuthUrl: '',
                            ),
                            const SizedBox(width: 6),
                            _buildOAuthProviderChip(
                              id: 'notion',
                              label: 'Notion',
                              icon: Icons.menu_book_rounded,
                              defaultAuthUrl: 'https://www.notion.so/my-integrations',
                            ),
                            const SizedBox(width: 6),
                            _buildOAuthProviderChip(
                              id: 'linear',
                              label: 'Linear',
                              icon: Icons.bolt_rounded,
                              defaultAuthUrl: 'https://linear.app/settings/api',
                            ),
                            const SizedBox(width: 6),
                            _buildOAuthProviderChip(
                              id: 'slack',
                              label: 'Slack',
                              icon: Icons.chat_bubble_outline_rounded,
                              defaultAuthUrl: 'https://api.slack.com/apps',
                            ),
                            const SizedBox(width: 6),
                            _buildOAuthProviderChip(
                              id: 'github',
                              label: 'GitHub',
                              icon: AppIcons.code,
                              defaultAuthUrl: 'https://github.com/settings/tokens/new?description=PocketStrike%20MCP&scopes=repo,read:org',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 1. OAuth Authorization Portal URL
                      TextField(
                        controller: _oauthAuthUrlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'OAuth Authorization URL / Portal',
                          hintText: _oauthProvider == 'custom'
                              ? 'e.g. https://mcp-server.com/oauth/authorize'
                              : 'Auth Portal URL',
                          filled: true,
                          fillColor: tokens.glassColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                            borderSide: BorderSide(color: tokens.glassBorder),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.open_in_browser_rounded,
                                size: 18, color: tokens.accent),
                            tooltip: 'Open in Browser',
                            onPressed: () {
                              final url = _oauthAuthUrlController.text.trim();
                              if (url.isNotEmpty) {
                                _launchExternalUrl(url);
                              } else if (_urlController.text.trim().isNotEmpty) {
                                _launchExternalUrl(_urlController.text.trim());
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 1-Tap Browser Auth Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.open_in_browser_rounded,
                              size: 16, color: tokens.accent),
                          label: Text(
                            _oauthAuthUrlController.text.trim().isNotEmpty
                                ? '1-Tap Open OAuth Portal in Browser'
                                : 'Open Authorization URL in Browser',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.accent,
                            side: BorderSide(
                                color: tokens.accent.withValues(alpha: 0.45)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                            ),
                          ),
                          onPressed: () {
                            final authUrl = _oauthAuthUrlController.text.trim();
                            if (authUrl.isNotEmpty) {
                              _launchExternalUrl(authUrl);
                            } else if (_urlController.text.trim().isNotEmpty) {
                              _launchExternalUrl(_urlController.text.trim());
                            } else {
                              setState(() => _error = 'Enter an OAuth URL or Server URL first.');
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Access Token or Callback URL Input (Smart Auto-Extraction)
                      TextField(
                        controller: _oauthTokenController,
                        obscureText: _obscureOAuthToken,
                        onChanged: (val) {
                          final extracted = _extractToken(val);
                          if (extracted != val) {
                            _oauthTokenController.text = extracted;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Access Token OR Redirect Callback URL',
                          hintText: 'Paste token (or full redirect URL like https://...#access_token=...)',
                          filled: true,
                          fillColor: tokens.glassColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                            borderSide: BorderSide(color: tokens.glassBorder),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _obscureOAuthToken
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 18,
                                  color: tokens.textSecondary,
                                ),
                                onPressed: () => setState(
                                    () => _obscureOAuthToken = !_obscureOAuthToken),
                              ),
                              IconButton(
                                icon: Icon(Icons.paste_rounded,
                                    size: 18, color: tokens.accent),
                                tooltip: 'Paste & Auto-Extract Token',
                                onPressed: () =>
                                    _pasteTo(_oauthTokenController),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '💡 Paste either the direct access token or the full redirect URL — PocketStrike auto-extracts the token and stores it with AES-GCM encryption in Android Keystore.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: tokens.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error display
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(AppIcons.alertCircle,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Discovered Tools Preview (Glowing Success Card)
              if (_discoveredTools != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: tokens.accent,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(AppIcons.checkCircle2,
                              color: tokens.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Connected! Discovered ${_discoveredTools!.length} tool(s)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : tokens.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final tool in _discoveredTools!) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(AppIcons.wrench,
                                    size: 13, color: tokens.accent),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11.5,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${tool.name}: ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: tool.description ??
                                            'No description provided',
                                        style: TextStyle(
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons (Test Connection / Save Server)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _testing
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: tokens.accent),
                            )
                          : const Icon(AppIcons.zap, size: 18),
                      label: Text(_testing ? 'Testing...' : 'Test Connection'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.glassBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                      ),
                      onPressed: _testing ? null : _test,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      label: 'Save Server',
                      icon: AppIcons.save,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthModeTab({
    required String label,
    required _AuthMode mode,
    required IconData icon,
  }) {
    final tokens = context.glass;
    final isSelected = _authMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _authMode = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radiusSm - 2),
            border: isSelected
                ? Border.all(color: tokens.accent, width: 1.0)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? tokens.accent : tokens.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? tokens.accent : tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOAuthProviderChip({
    required String id,
    required String label,
    required IconData icon,
    required String defaultAuthUrl,
  }) {
    final tokens = context.glass;
    final isSelected = _oauthProvider == id;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _oauthProvider = id;
          if (defaultAuthUrl.isNotEmpty) {
            _oauthAuthUrlController.text = defaultAuthUrl;
          }
          if (id == 'notion' && _urlController.text.trim().isEmpty) {
            _urlController.text = 'https://api.smithery.ai/mcp/v1/notion';
          } else if (id == 'linear' && _urlController.text.trim().isEmpty) {
            _urlController.text = 'https://api.smithery.ai/mcp/v1/linear';
          } else if (id == 'slack' && _urlController.text.trim().isEmpty) {
            _urlController.text = 'https://api.smithery.ai/mcp/v1/slack';
          } else if (id == 'github' && _urlController.text.trim().isEmpty) {
            _urlController.text = 'https://api.smithery.ai/mcp/v1/github';
          }
        });
      },
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accent.withValues(alpha: 0.16)
              : tokens.glassColor,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: isSelected ? tokens.accent : tokens.glassBorder,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? tokens.accent : tokens.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? tokens.accent : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sleek, segmented switch button for choosing transport type (HTTP MCP vs SSE MCP).
class _TransportSwitchButton extends StatelessWidget {
  const _TransportSwitchButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.accent.withValues(alpha: 0.14)
                : tokens.glassColor,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: isSelected ? tokens.accent : tokens.glassBorder,
              width: isSelected ? 1.4 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: tokens.accent.withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? tokens.accent.withValues(alpha: 0.22)
                      : tokens.textSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: isSelected ? tokens.accent : tokens.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.white : tokens.accent)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isSelected
                            ? tokens.accent.withValues(alpha: 0.85)
                            : tokens.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  AppIcons.checkCircle2,
                  size: 14,
                  color: tokens.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
