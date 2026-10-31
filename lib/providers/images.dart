import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/image_store.dart';
import 'dependencies.dart';

/// Decoded bytes for a Firestore-hosted photo, keyed by its `img:{id}` token.
///
/// [ImageStore] keeps its own in-memory cache, so re-rendering a grid reuses
/// the bytes instead of re-reading the document. Tokens that are actually
/// external URLs resolve to null and the caller renders its placeholder.
final listingImageBytesProvider = FutureProvider.family<Uint8List?, String>(
  (ref, token) => ref.watch(imageStoreProvider).load(token),
);
