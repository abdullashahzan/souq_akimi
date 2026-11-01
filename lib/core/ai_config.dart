import 'package:flutter/foundation.dart' show kReleaseMode;

/// Debug-only AI configuration. Release builds never accept a shared API key.
/// Restore public AI only behind a separately approved authenticated backend.
class AiConfig {
  const AiConfig._();

  /// `--dart-define=GROQ_API_KEY=...` supplies the key. Empty in a plain
  /// checkout, which makes the AI buttons show the friendly "not configured"
  /// message instead of crashing.
  static const String groqApiKey = kReleaseMode
      ? ''
      : String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  static const bool enabled = !kReleaseMode && groqApiKey != '';

  static const String groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Qwen's latest general model is fast, multilingual, and reliably returns
  /// the whole answer (unlike reasoning models that can spend a small token
  /// budget on hidden reasoning and leave `content` empty).
  static const String groqModel = 'qwen/qwen3.8-27b';

  /// The Web OAuth client created for Firebase Authentication's Google
  /// provider. `--dart-define=GOOGLE_WEB_CLIENT_ID=...` can override it.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '105148624941-hpq1ogq6808h1608f07dsvtgveurvff4.apps.googleusercontent.com',
  );

  static const Duration timeout = Duration(seconds: 25);
}
