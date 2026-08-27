import '../../../core/db/app_database.dart';
import '../domain/ai_provider.dart';
import '../domain/provider_types.dart';
import 'anthropic_provider.dart';
import 'gemini_provider.dart';
import 'mock_provider.dart';
import 'openai_compatible_provider.dart';

/// Builds concrete [AIProvider] instances from stored configs.
class ProviderRegistry {
  const ProviderRegistry._();

  static AIProvider build(ProviderConfig config, String? apiKey) {
    final type = ProviderTypeX.fromId(config.type);
    final baseUrl = config.baseUrl.isNotEmpty
        ? config.baseUrl
        : type.defaultBaseUrl;

    return switch (type) {
      ProviderType.anthropic => AnthropicProvider(
          configId: config.id,
          baseUrl: baseUrl,
          apiKey: apiKey,
        ),
      ProviderType.gemini => GeminiProvider(
          configId: config.id,
          baseUrl: baseUrl,
          apiKey: apiKey,
        ),
      ProviderType.mock => const MockProvider(),
      _ => OpenAiCompatibleProvider(
          configId: config.id,
          type: type,
          baseUrl: baseUrl,
          apiKey: apiKey,
        ),
    };
  }
}
