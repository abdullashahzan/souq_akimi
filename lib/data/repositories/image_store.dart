import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/souq_exception.dart';
import '../collections.dart';

/// Listing photos, stored inside Firestore itself rather than Cloud Storage.
///
/// The whole point is to stay on the Spark (free) tier: a photo is resized to
/// [maxEdge], re-encoded as JPEG, base64-encoded and written to its own
/// `images/{id}` document. Listings point at it with an opaque
/// `img:{id}` token stored in their `images` / `image` fields — anything that
/// is not a token is treated as a plain URL, so seeded rows that reference
/// external placeholder photos keep working.
///
/// Keeping the bytes in a separate document (instead of on the listing) means
/// catalogue queries still only transfer the listing documents; the grid pays
/// for a photo only when it actually renders one.
class ImageStore {
  ImageStore({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Marks a value as a Firestore-hosted photo rather than a URL.
  static const String tokenPrefix = 'img:';

  /// Longest edge (px) kept on a stored photo — plenty for a card thumbnail.
  static const int maxEdge = 1024;

  /// JPEG quality used when re-encoding.
  static const int jpegQuality = 72;

  /// Ceiling on the *decoded* payload. Firestore caps a document at 1 MB and
  /// base64 inflates by ~4/3, so 600 KB leaves comfortable headroom.
  static const int maxEncodedBytes = 600 * 1024;

  /// Processed photos are cached in memory so re-rendering a grid does not
  /// re-read (or re-decode) the same photo over and over.
  static final Map<String, Uint8List> _cache = {};

  static bool isToken(String value) => value.startsWith(tokenPrefix);

  static String _idOf(String token) => token.substring(tokenPrefix.length);

  static String _tokenFor(String id) => '$tokenPrefix$id';

  /// Resizes and re-encodes [bytes]; returns the payload to store.
  static Uint8List normalise(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Not decodable (an exotic format, say) — keep it only if it is already
      // small enough to store as-is, otherwise refuse rather than blow the
      // 1 MB document limit.
      if (bytes.lengthInBytes <= maxEncodedBytes) return bytes;
      throw const SouqException(
        'That photo could not be read. Please pick a JPEG or PNG.',
      );
    }

    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final img.Image resized;
    if (longest > maxEdge) {
      final scale = maxEdge / longest;
      resized = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    } else {
      resized = decoded;
    }

    return img.encodeJpg(resized, quality: jpegQuality);
  }

  /// Stores [bytes] and returns the token to put on the listing document.
  Future<String> saveImage({
    required String ownerId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final payload = await compute(normalise, bytes);
    if (payload.lengthInBytes > maxEncodedBytes) {
      throw const SouqException('That photo is too large to store.');
    }

    final doc = _db.collection(Col.images).doc();
    await doc.set(<String, Object?>{
      'ownerId': ownerId,
      'data': base64Encode(payload),
      'contentType': contentType,
      'size': payload.lengthInBytes,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final token = _tokenFor(doc.id);
    _cache[token] = payload;
    return token;
  }

  /// Reads the bytes for [token], or null when it is a plain URL, missing or
  /// unreadable — callers fall back to their placeholder.
  Future<Uint8List?> load(String token) async {
    if (!isToken(token)) return null;
    final cached = _cache[token];
    if (cached != null) return cached;

    try {
      final snapshot = await _db.collection(Col.images).doc(_idOf(token)).get();
      final data = snapshot.data()?['data'] as String?;
      if (data == null || data.isEmpty) return null;
      final payload = base64Decode(data);
      _cache[token] = payload;
      return payload;
    } catch (_) {
      // A missing photo must never break a listing card.
      return null;
    }
  }

  /// Removes a stored photo. Tokens that are not tokens (external URLs) are
  /// ignored, so cleaning up after a seeded placeholder is a no-op.
  Future<void> delete(String token) async {
    _cache.remove(token);
    if (!isToken(token)) return;
    try {
      await _db.collection(Col.images).doc(_idOf(token)).delete();
    } catch (_) {
      // An orphaned photo is not worth surfacing to the user.
    }
  }

  /// Best-effort cleanup of several tokens at once.
  Future<void> deleteAll(Iterable<String> tokens) async {
    for (final token in tokens) {
      await delete(token);
    }
  }
}
