// Prints the two placeholder gradient colours (top-left / bottom-right
// quadrant averages) for every template image. The app shows this gradient for
// the instant before the real picture has downloaded from Storage.
//
//   dart run tool/image_colors.dart
import 'dart:io';
import 'package:image/image.dart' as img;

String _hex(int r, int g, int b) =>
    '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';

String _avg(img.Image im, int x0, int y0, int x1, int y1) {
  var r = 0, g = 0, b = 0, n = 0;
  for (var y = y0; y < y1; y += 4) {
    for (var x = x0; x < x1; x += 4) {
      final p = im.getPixel(x, y);
      r += p.r.toInt();
      g += p.g.toInt();
      b += p.b.toInt();
      n++;
    }
  }
  return _hex(r ~/ n, g ~/ n, b ~/ n);
}

void main() {
  final dir = Directory('supabase/seed/images');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final im = img.decodeJpg(f.readAsBytesSync())!;
    final w = im.width, h = im.height;
    final name = f.uri.pathSegments.last;
    print("$name ${_avg(im, 0, 0, w ~/ 2, h ~/ 2)} ${_avg(im, w ~/ 2, h ~/ 2, w, h)}");
  }
}
