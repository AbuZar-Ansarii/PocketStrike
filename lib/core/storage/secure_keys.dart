import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keystore/Keychain-backed storage for API keys and bot tokens.
///
/// Keys are stored as `apikey_<providerConfigId>`; Telegram token as
/// `telegram_bot_token`. Nothing sensitive ever lands in SharedPreferences.
class SecureKeyStore {
  SecureKeyStore()
      // v11+ defaults: AES-GCM storage + RSA-OAEP key wrapping (API 23+).
      : _storage = const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  static String _providerKey(String configId) => 'apikey_$configId';

  Future<String?> readProviderKey(String configId) =>
      _storage.read(key: _providerKey(configId));

  Future<void> writeProviderKey(String configId, String key) =>
      _storage.write(key: _providerKey(configId), value: key);

  Future<void> deleteProviderKey(String configId) =>
      _storage.delete(key: _providerKey(configId));

  static const _telegramTokenKey = 'telegram_bot_token';

  Future<String?> readTelegramToken() => _storage.read(key: _telegramTokenKey);

  Future<void> writeTelegramToken(String token) =>
      _storage.write(key: _telegramTokenKey, value: token);

  Future<void> deleteTelegramToken() => _storage.delete(key: _telegramTokenKey);

  static String _mcpHeadersKey(String serverId) => 'mcp_headers_$serverId';

  Future<String?> readMcpHeaders(String serverId) =>
      _storage.read(key: _mcpHeadersKey(serverId));

  Future<void> writeMcpHeaders(String serverId, String headersJson) =>
      _storage.write(key: _mcpHeadersKey(serverId), value: headersJson);

  Future<void> deleteMcpHeaders(String serverId) =>
      _storage.delete(key: _mcpHeadersKey(serverId));

  Future<void> wipeAll() => _storage.deleteAll();
}

final secureKeyStoreProvider =
    Provider<SecureKeyStore>((ref) => SecureKeyStore());
