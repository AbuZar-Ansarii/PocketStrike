import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/models/chat_models.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/features/providers/application/providers_controller.dart';
import 'package:pocketstrike/features/providers/data/provider_registry.dart';
import 'package:pocketstrike/features/providers/domain/provider_types.dart';
import 'package:pocketstrike/core/db/app_database.dart';

class ProviderEditScreen extends ConsumerStatefulWidget {
  const ProviderEditScreen({super.key, this.configId});

  final String? configId;

  @override
  ConsumerState<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends ConsumerState<ProviderEditScreen> {
  late ProviderType _selectedType = ProviderType.openai;
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _makeDefault = false;
  bool _testing = false;
  bool _fetchingModels = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.configId == null) {
      _nameController.text = _selectedType.displayName;
      _urlController.text = _selectedType.defaultBaseUrl;
      if (_selectedType.suggestedModels.isNotEmpty) {
        _modelController.text = _selectedType.suggestedModels.first;
      }
      return;
    }
    final configs = await ref.read(providerConfigsProvider.future);
    final config = configs.where((c) => c.id == widget.configId).firstOrNull;
    if (config != null) {
      setState(() {
        _selectedType = ProviderTypeX.fromId(config.type);
        _nameController.text = config.name;
        _urlController.text = config.baseUrl;
        _modelController.text = config.defaultModel;
        _makeDefault = config.isDefault;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    setState(() => _fetchingModels = true);
    final baseUrl = _urlController.text.trim().isNotEmpty
        ? _urlController.text.trim()
        : _selectedType.defaultBaseUrl;
    final apiKey = _keyController.text.trim();

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));

      List<String> models = [];

      if (_selectedType == ProviderType.gemini) {
        final url = '$baseUrl/v1beta/models?key=$apiKey';
        final resp = await dio.get(url);
        if (resp.data is Map<String, dynamic> && resp.data['models'] is List) {
          final list = resp.data['models'] as List;
          models = list
              .map((m) =>
                  m['name']?.toString().replaceFirst('models/', '') ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } else if (_selectedType == ProviderType.anthropic) {
        final url =
            baseUrl.endsWith('/v1') ? '$baseUrl/models' : '$baseUrl/v1/models';
        final resp = await dio.get(
          url,
          options: Options(headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          }),
        );
        if (resp.data is Map<String, dynamic> && resp.data['data'] is List) {
          final list = resp.data['data'] as List;
          models = list
              .map((m) => m['id']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } else {
        // OpenAI, Groq, OpenRouter, Ollama, OpenCode Zen, NVIDIA NIM, Custom
        final url = baseUrl.endsWith('/models') ? baseUrl : '$baseUrl/models';
        final headers = <String, String>{};
        if (apiKey.isNotEmpty) {
          headers['Authorization'] = 'Bearer $apiKey';
        }
        final resp = await dio.get(url, options: Options(headers: headers));
        if (resp.data is Map<String, dynamic>) {
          final dataArr = resp.data['data'] ?? resp.data['models'];
          if (dataArr is List) {
            models = dataArr
                .map((m) {
                  if (m is Map) {
                    return m['id']?.toString() ?? m['name']?.toString() ?? '';
                  }
                  return m.toString();
                })
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      }

      if (models.isEmpty) {
        models = _selectedType.suggestedModels;
      }

      if (mounted) {
        _showModelsSheet(models);
      }
    } catch (e) {
      final fallback = _selectedType.suggestedModels;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not fetch remote models: ${e.toString().split("\n").first}'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        _showModelsSheet(fallback.isNotEmpty ? fallback : ['gpt-4o']);
      }
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  void _showModelsSheet(List<String> models) {
    final tokens = context.glass;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: tokens.glassBorder)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(AppIcons.sparkles, color: tokens.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Available Models (${models.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tap any model to select it, or type your custom model name directly.',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final isSelected =
                        _modelController.text.trim() == model;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tokens.accent.withValues(alpha: 0.15)
                            : tokens.glassColor,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(
                          color: isSelected
                              ? tokens.accent
                              : tokens.glassBorder,
                        ),
                      ),
                      child: ListTile(
                        title: Text(
                          model,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? tokens.accent : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(AppIcons.checkCircle2,
                                color: tokens.accent, size: 18)
                            : const Icon(AppIcons.chevronRight, size: 16),
                        onTap: () {
                          setState(() {
                            _modelController.text = model;
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final baseUrl = _urlController.text.trim();
      final apiKey = _keyController.text.trim();

      final tempConfig = ProviderConfig(
        id: widget.configId ?? 'temp',
        type: _selectedType.id,
        name: _nameController.text.trim(),
        baseUrl: baseUrl.isNotEmpty ? baseUrl : _selectedType.defaultBaseUrl,
        defaultModel: _modelController.text.trim(),
        isDefault: false,
        hasKey: apiKey.isNotEmpty,
        paramsJson: '{}',
        createdAt: DateTime.now(),
      );

      final provider = ProviderRegistry.build(
          tempConfig, apiKey.isNotEmpty ? apiKey : null);
      final error =
          await ref.read(providerActionsProvider).testConnection(provider);

      setState(() {
        _testSuccess = error == null;
        _testResult =
            error ?? 'Connection successful! Provider is ready to chat.';
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(providerActionsProvider).saveProvider(
          id: widget.configId,
          type: _selectedType,
          name: name,
          baseUrl: _urlController.text.trim(),
          defaultModel: _modelController.text.trim(),
          params: const GenerationParams(),
          apiKey: _keyController.text.trim(),
          makeDefault: _makeDefault,
        );

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final isEditing = widget.configId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Provider' : 'Add AI Provider',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider Type Selection Dropdown
          DropdownButtonFormField<ProviderType>(
            initialValue: _selectedType,
            decoration: InputDecoration(
              labelText: 'Provider Type',
              filled: true,
              fillColor: tokens.glassColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
            ),
            items: ProviderType.values
                .where((t) => t != ProviderType.mock)
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.displayName),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedType = val;
                  _nameController.text = val.displayName;
                  _urlController.text = val.defaultBaseUrl;
                  if (val.suggestedModels.isNotEmpty) {
                    _modelController.text = val.suggestedModels.first;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 14),

          // Provider Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Display Name',
              filled: true,
              fillColor: tokens.glassColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // API Key
          TextField(
            controller: _keyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _selectedType.keyOptional
                  ? 'API Key (optional for ${_selectedType.displayName})'
                  : 'API Key (stored securely)',
              hintText: isEditing ? '••••••••••••••••' : 'Enter API Key',
              filled: true,
              fillColor: tokens.glassColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Custom Base URL
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Base URL',
              hintText: _selectedType.defaultBaseUrl,
              filled: true,
              fillColor: tokens.glassColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Default Model TextField + Fetch Models Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: 'Model Name / ID',
                    hintText: 'e.g. gpt-4o, opencode-zen',
                    filled: true,
                    fillColor: tokens.glassColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      borderSide: BorderSide(color: tokens.glassBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  icon: _fetchingModels
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(AppIcons.sparkles, size: 16, color: tokens.accent),
                  label: Text(_fetchingModels ? 'Fetching...' : 'Fetch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.accent,
                    side: BorderSide(
                        color: tokens.accent.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ),
                  onPressed: _fetchingModels ? null : _fetchModels,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SwitchListTile(
            title: const Text('Make Default Provider'),
            value: _makeDefault,
            onChanged: (val) => setState(() => _makeDefault = val),
          ),
          const SizedBox(height: 14),

          if (_testResult != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testSuccess
                    ? tokens.accent.withValues(alpha: 0.15)
                    : Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                    color: _testSuccess ? tokens.accent : Colors.redAccent),
              ),
              child: SelectableText(
                _testResult!,
                style: TextStyle(
                  color: _testSuccess ? tokens.accent : Colors.redAccent,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(AppIcons.zap, size: 16, color: tokens.accent),
                  label: Text(_testing ? 'Testing...' : 'Test Connection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                        color: tokens.accent.withValues(alpha: 0.4)),
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
                  label: 'Save Provider',
                  icon: AppIcons.save,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
