import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;

import '../core/ai_config.dart';
import '../core/l10n.dart';
import '../core/souq_exception.dart';

/// Small wrapper around Groq's OpenAI-compatible chat endpoint.
///
/// Everything here is best-effort: AI is a convenience, never a dependency.
/// Failures surface as a friendly [SouqException] and callers leave the form
/// untouched.
class AiAssistant {
  AiAssistant({http.Client? client, String? apiKey, Duration? timeout})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? AiConfig.groqApiKey,
      _timeout = timeout ?? AiConfig.timeout;

  final http.Client _client;
  final String _apiKey;
  final Duration _timeout;

  // --------------------------------------------------------------------- #
  // Public helpers
  // --------------------------------------------------------------------- #

  /// A ready-to-publish description for a product.
  Future<String> productDescription({
    required String title,
    String category = '',
    String condition = '',
    String price = '',
    String notes = '',
  }) => _text(
    system:
        'You write short, honest marketplace listings for university hostel '
        'students. Never invent brands, model numbers, sizes or features that '
        'were not provided. Use 2-4 short sentences of plain text. No emojis, '
        'no hashtags, no markdown, no surrounding quotes.',
    user: [
      'Write the description for this second-hand listing.',
      'Title: $title',
      if (category.isNotEmpty) 'Category: $category',
      if (condition.isNotEmpty) 'Condition: $condition',
      if (price.isNotEmpty) 'Price: $price',
      if (notes.isNotEmpty) 'Seller notes: $notes',
      'Language: ${_languageName()}',
    ].join('\n'),
    maxTokens: 512,
  );

  /// A ready-to-publish description for a service.
  Future<String> serviceDescription({
    required String title,
    String category = '',
    String price = '',
    String notes = '',
  }) => _text(
    system:
        'You write warm, specific service listings for a university campus '
        'marketplace. Only mention inclusions and turnaround when provided. '
        'Never invent qualifications, prices or guarantees. Use 2-4 short '
        'sentences of plain text. No emojis, no hashtags, no markdown.',
    user: [
      'Write the "what you get" description for this student service.',
      'Service: $title',
      if (category.isNotEmpty) 'Category: $category',
      if (price.isNotEmpty) 'Price: $price',
      if (notes.isNotEmpty) 'Provider notes: $notes',
      'Language: ${_languageName()}',
    ].join('\n'),
    maxTokens: 512,
  );

  /// A comma-separated tag list, lowercase, without the '#' character.
  Future<List<String>> tags({
    required String title,
    String description = '',
    String category = '',
  }) async {
    final raw = await _text(
      system:
          'You suggest search keywords for a campus marketplace listing. '
          'Return ONLY a JSON object of the shape {"tags":["..."]}. Give 5-8 '
          'short, lowercase, single-word or two-word tags. No duplicates, no '
          'hashtags, no explanations.',
      user: [
        'Title: $title',
        if (description.isNotEmpty) 'Description: $description',
        if (category.isNotEmpty) 'Category: $category',
        'Language: ${_languageName()}',
      ].join('\n'),
      maxTokens: 512,
      json: true,
    );
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['tags'] is List) {
        return (decoded['tags'] as List)
            .map((tag) => '$tag'.trim().toLowerCase().replaceAll('#', ''))
            .where((tag) => tag.isNotEmpty && tag.length <= 30)
            .take(8)
            .toList(growable: false);
      }
    } catch (_) {
      // Fall through to a forgiving split: models occasionally add a sentence.
    }
    return raw
        .replaceAll(RegExp(r'[\[\]{}"]'), '')
        .split(RegExp(r'[,\n]'))
        .map((tag) => tag.trim().toLowerCase().replaceAll('#', ''))
        .where((tag) => tag.isNotEmpty && tag.length <= 30 && tag != 'tags')
        .take(8)
        .toList(growable: false);
  }

  /// A clear service brief from a one-line hint.
  Future<String> serviceBrief({
    required String serviceTitle,
    String hint = '',
    String building = '',
    String room = '',
  }) => _text(
    system:
        'You help a student write a short, polite request to a service '
        'provider on their campus. Be specific but do not invent dates, page '
        'counts, budgets or requirements. 2-4 sentences, plain text, no '
        'greeting line, no emojis.',
    user: [
      'Service: $serviceTitle',
      if (hint.isNotEmpty) 'What I need: $hint',
      if (building.isNotEmpty) 'My building: $building',
      if (room.isNotEmpty) 'My room: $room',
      'Language: ${_languageName()}',
    ].join('\n'),
    maxTokens: 512,
  );

  /// Title + body for an admin announcement.
  Future<({String title, String body})> announcement({
    required String topic,
  }) async {
    final raw = await _text(
      system:
          'You write short announcements for the users of a campus marketplace '
          'app. Return ONLY a JSON object {"title":"...","body":"..."}. The '
          'title is at most 60 characters; the body is 1-2 friendly sentences. '
          'No emojis, no markdown.',
      user: 'Announcement topic: $topic\nLanguage: ${_languageName()}',
      maxTokens: 512,
      json: true,
    );
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return (
          title: '${decoded['title'] ?? topic}'.trim(),
          body: '${decoded['body'] ?? ''}'.trim(),
        );
      }
    } catch (_) {
      // Fall through to using the model's prose as the body.
    }
    return (title: topic, body: raw.trim());
  }

  // --------------------------------------------------------------------- #
  // Transport
  // --------------------------------------------------------------------- #

  Future<String> _text({
    required String system,
    required String user,
    required int maxTokens,
    bool json = false,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw SouqException(translate('AI is not configured for this build.'));
    }

    final body = <String, Object?>{
      'model': AiConfig.groqModel,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': json ? 0.3 : 0.65,
      'max_completion_tokens': maxTokens,
      if (json) 'response_format': {'type': 'json_object'},
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(AiConfig.groqEndpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'SouqAkimi/1.0 (Flutter)',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw SouqException(
        translate('AI is taking too long. Please try again.'),
      );
    } catch (_) {
      throw SouqException(
        translate('AI needs a connection. Check your internet and try again.'),
      );
    }

    if (kDebugMode &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      debugPrint('Groq ${response.statusCode}: ${_short(response.body)}');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SouqException(translate('AI is not configured for this build.'));
    }
    if (response.statusCode == 429) {
      throw SouqException(
        translate('AI is busy right now. Please try again in a moment.'),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SouqException(
        translate('AI could not write that. Please try again.'),
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      final content = decoded['choices']?[0]?['message']?['content'];
      if (content is! String) throw const FormatException('missing content');
      if (decoded['choices'][0]['finish_reason'] == 'length') {
        throw const FormatException('truncated content');
      }
      final text = _clean(content);
      if (text.isEmpty) {
        if (kDebugMode) {
          debugPrint('Groq returned empty content: ${_short(response.body)}');
        }
        throw const FormatException('empty');
      }
      return text;
    } catch (_) {
      throw SouqException(
        translate('AI could not write that. Please try again.'),
      );
    }
  }

  String _short(String value) =>
      value.length <= 600 ? value : '${value.substring(0, 600)}…';

  /// The models occasionally ignore the "plain text" instruction. Strip the
  /// few markdown decorations that would look broken inside a text field.
  String _clean(String text) {
    var out = text.trim();
    out = out.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), '');
    out = out.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    out = out.replaceAll(RegExp(r'\*\*|__|`'), '');
    out = out.replaceAll(RegExp(r'^["“]|["”]$'), '').trim();
    return out;
  }

  String _languageName() => AppLocale.isArabic ? 'Arabic' : 'English';
}
