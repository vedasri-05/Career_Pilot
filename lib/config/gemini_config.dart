/// Configuration for Google Gemini API integration.
///
/// NOTE ON SECURITY:
/// In client-side Flutter applications, values injected via `--dart-define`
/// are compiled directly into the client binary / web bundle and can be
/// extracted by inspecting or decompiling the application. For production
/// distribution with sensitive credentials, API calls must be proxied through
/// a secure backend service (e.g. Firebase Cloud Functions, Cloud Run, or a REST API)
/// where the API key is kept secret on the server.
class GeminiConfig {
  GeminiConfig._();

  /// Default model configured for AI resume analysis.
  static const String _defaultModel = 'gemini-3.8-flash';

  /// Optional build-time environment variable:
  /// `--dart-define=GEMINI_MODEL=gemini-3.6-flash`
  static const String _envModel = String.fromEnvironment('GEMINI_MODEL');

  /// Runtime model override used by automated tests or dynamic fallback.
  static String _runtimeModel = '';

  /// The model configured for AI resume analysis.
  static String get modelName {
    if (_runtimeModel.isNotEmpty) return _runtimeModel;
    if (_envModel.isNotEmpty) return _envModel;
    return _defaultModel;
  }

  /// Sets a runtime model override.
  static void setRuntimeModel(String model) {
    _runtimeModel = model.trim();
  }

  /// Clears any runtime model override.
  static void clearRuntimeModel() {
    _runtimeModel = '';
  }

  /// Build-time environment variable injected via:
  /// `--dart-define=GEMINI_API_KEY=your_key`
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Runtime override used by automated unit tests or local development.
  static String _runtimeApiKey = '';

  /// Sanitizes raw key string by trimming whitespace and stripping enclosing quotes
  /// that can be inadvertently injected by command-line shells or IDE configs.
  static String _sanitizeKey(String raw) {
    var key = raw.trim();
    if ((key.startsWith('"') && key.endsWith('"')) ||
        (key.startsWith("'") && key.endsWith("'"))) {
      if (key.length >= 2) {
        key = key.substring(1, key.length - 1).trim();
      }
    }
    return key;
  }

  /// Returns the active Gemini API key:
  /// 1. Runtime override if set
  /// 2. Build-time environment variable passed via --dart-define
  static String get apiKey {
    if (_runtimeApiKey.isNotEmpty) {
      return _sanitizeKey(_runtimeApiKey);
    }
    return _sanitizeKey(_envApiKey);
  }

  /// Returns true if a valid non-empty API key is configured.
  static bool get hasApiKey => apiKey.isNotEmpty;

  /// Sets a runtime key (used for automated testing and local configuration).
  static void setRuntimeApiKey(String key) {
    _runtimeApiKey = _sanitizeKey(key);
  }

  /// Alias for backward compatibility.
  static void saveApiKey(String key) {
    setRuntimeApiKey(key);
  }

  /// Clears any runtime test key.
  static void clearRuntimeApiKey() {
    _runtimeApiKey = '';
  }
}
