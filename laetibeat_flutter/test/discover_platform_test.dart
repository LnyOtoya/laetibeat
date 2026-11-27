import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/pages/mobile/discover/discover_platform.dart';

void main() {
  test('defaults to NetEase', () {
    expect(DiscoverPlatform.fromId(null), DiscoverPlatform.netease);
    expect(DiscoverPlatform.fromId(''), DiscoverPlatform.netease);
  });

  test('resolves QQ', () {
    expect(DiscoverPlatform.fromId('qq'), DiscoverPlatform.qq);
  });

  test('unknown ids fall back to NetEase', () {
    expect(DiscoverPlatform.fromId('unknown'), DiscoverPlatform.netease);
  });
}
