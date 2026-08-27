/// Supported provider kinds.
enum ProviderType {
  openai,
  anthropic,
  gemini,
  groq,
  openrouter,
  ollama,
  opencode,
  nvidia,
  custom,
  mock,
}

extension ProviderTypeX on ProviderType {
  String get displayName => switch (this) {
        ProviderType.openai => 'OpenAI',
        ProviderType.anthropic => 'Anthropic (Claude)',
        ProviderType.gemini => 'Google Gemini',
        ProviderType.groq => 'Groq',
        ProviderType.openrouter => 'OpenRouter',
        ProviderType.ollama => 'Ollama',
        ProviderType.opencode => 'OpenCode Zen',
        ProviderType.nvidia => 'NVIDIA NIM',
        ProviderType.custom => 'Custom (OpenAI-compatible)',
        ProviderType.mock => 'Demo (offline mock)',
      };

  String get id => switch (this) {
        ProviderType.openai => 'openai',
        ProviderType.anthropic => 'anthropic',
        ProviderType.gemini => 'gemini',
        ProviderType.groq => 'groq',
        ProviderType.openrouter => 'openrouter',
        ProviderType.ollama => 'ollama',
        ProviderType.opencode => 'opencode',
        ProviderType.nvidia => 'nvidia',
        ProviderType.custom => 'custom',
        ProviderType.mock => 'mock',
      };

  static ProviderType fromId(String id) => switch (id) {
        'openai' => ProviderType.openai,
        'anthropic' => ProviderType.anthropic,
        'gemini' => ProviderType.gemini,
        'groq' => ProviderType.groq,
        'openrouter' => ProviderType.openrouter,
        'ollama' => ProviderType.ollama,
        'opencode' => ProviderType.opencode,
        'nvidia' => ProviderType.nvidia,
        'custom' => ProviderType.custom,
        _ => ProviderType.mock,
      };

  /// Default API base URL (user-overridable).
  String get defaultBaseUrl => switch (this) {
        ProviderType.openai => 'https://api.openai.com/v1',
        ProviderType.anthropic => 'https://api.anthropic.com',
        ProviderType.gemini => 'https://generativelanguage.googleapis.com',
        ProviderType.groq => 'https://api.groq.com/openai/v1',
        ProviderType.openrouter => 'https://openrouter.ai/api/v1',
        ProviderType.ollama => 'http://localhost:11434/v1',
        ProviderType.opencode => 'https://opencode.ai/zen/v1',
        ProviderType.nvidia => 'https://integrate.api.nvidia.com/v1',
        ProviderType.custom => '',
        ProviderType.mock => '',
      };

  /// Suggested model names for the picker (live fetch when available).
  List<String> get suggestedModels => switch (this) {
        ProviderType.openai => ['gpt-4o', 'gpt-4o-mini', 'o4-mini'],
        ProviderType.anthropic => [
            'claude-sonnet-4-5',
            'claude-opus-4-1',
            'claude-haiku-4-5',
          ],
        ProviderType.gemini => [
            'gemini-2.5-pro',
            'gemini-2.5-flash',
            'gemini-2.5-flash-lite',
          ],
        ProviderType.groq => [
            'llama-3.3-70b-versatile',
            'llama-3.1-8b-instant',
            'openai/gpt-oss-120b',
          ],
        ProviderType.openrouter => [
            'openai/gpt-4o',
            'anthropic/claude-sonnet-4-5',
            'google/gemini-2.5-pro',
          ],
        ProviderType.ollama => ['llama3.2', 'qwen3', 'deepseek-r1'],
        ProviderType.opencode => [
            'opencode-zen',
            'claude-3-5-sonnet',
            'deepseek-coder',
            'opencode-coder',
          ],
        ProviderType.nvidia => [
            'meta/llama-3.1-70b-instruct',
            'meta/llama-3.1-8b-instruct',
            'deepseek-ai/deepseek-r1',
            'nvidia/nemotron-4-340b-instruct',
          ],
        ProviderType.custom => const [],
        ProviderType.mock => ['pocketstrike-demo-1'],
      };

  /// Ollama and the offline mock work without an API key.
  bool get keyOptional =>
      this == ProviderType.ollama || this == ProviderType.mock;

  /// Whether to send OpenAI-style penalties (Anthropic/Gemini reject them).
  bool get supportsPenalties => switch (this) {
        ProviderType.openai ||
        ProviderType.groq ||
        ProviderType.openrouter ||
        ProviderType.ollama ||
        ProviderType.opencode ||
        ProviderType.nvidia ||
        ProviderType.custom =>
          true,
        _ => false,
      };
}

/// A normalized tool spec handed to providers; each client formats it into
/// its own wire schema (OpenAI functions / Anthropic tool_use / Gemini
/// functionDeclarations).
class ProviderToolSpec {
  const ProviderToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;
}
