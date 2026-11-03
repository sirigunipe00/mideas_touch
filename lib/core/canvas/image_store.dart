import 'dart:typed_data';
import 'dart:ui' as ui;

/// Decodes uploaded pictures once and keeps the result keyed by the byte
/// buffer, so the canvas painter can draw them synchronously.
class ImageStore {
  ImageStore._();

  static final Expando<ui.Image> _decoded = Expando('decoded');
  static final Expando<Future<ui.Image?>> _pending = Expando('pending');

  /// The decoded image, or `null` while it is still decoding.
  static ui.Image? peek(Uint8List? bytes) =>
      bytes == null ? null : _decoded[bytes];

  static Future<ui.Image?> load(Uint8List bytes) {
    final existing = _decoded[bytes];
    if (existing != null) return Future.value(existing);
    return _pending[bytes] ??= _decode(bytes);
  }

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return _decoded[bytes] = frame.image;
    } catch (_) {
      return null;
    }
  }
}
