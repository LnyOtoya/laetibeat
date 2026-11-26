import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 从封面字节提取一个代表性主色（采样数最多的量化桶的平均色）。
///
/// 供播放页、网易云详情页等封面取色共用。
Future<ui.Color> dominantCoverColor(Uint8List bytes) async {
  const int grid = 24;
  // 只解码到 64px 宽：取色只需要缩略采样，避免在 UI 线程解码整张大图
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 64,
    allowUpscaling: false,
  );
  final frame = await codec.getNextFrame();
  final ui.Image img = frame.image;
  final w = img.width;
  final h = img.height;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  codec.dispose();
  if (data == null || w <= 0 || h <= 0) {
    return const ui.Color(0xFF6750A4);
  }
  final px = data.buffer.asUint8List();

  final Map<int, _Bucket> buckets = {};
  for (var gy = 0; gy < grid; gy++) {
    for (var gx = 0; gx < grid; gx++) {
      final x = math.max(0, math.min(w - 1, gx * w ~/ grid));
      final y = math.max(0, math.min(h - 1, gy * h ~/ grid));
      final i = (y * w + x) * 4;
      final r = px[i];
      final g = px[i + 1];
      final b = px[i + 2];
      // 每通道量化到 /8（32 级），近似合并相近色进同一桶
      final key = ((r ~/ 8) << 10) | ((g ~/ 8) << 5) | (b ~/ 8);
      final bucket = buckets.putIfAbsent(key, _Bucket.new);
      bucket.r += r;
      bucket.g += g;
      bucket.b += b;
      bucket.count++;
    }
  }

  _Bucket? best;
  for (final bucket in buckets.values) {
    if (best == null || bucket.count > best.count) best = bucket;
  }
  if (best == null) return const ui.Color(0xFF6750A4);
  return ui.Color.fromARGB(
    255,
    best.r ~/ best.count,
    best.g ~/ best.count,
    best.b ~/ best.count,
  );
}

/// 单色彩量化桶：累加 RGB 与采样次数，最终取平均色。
class _Bucket {
  int r = 0;
  int g = 0;
  int b = 0;
  int count = 0;
}
