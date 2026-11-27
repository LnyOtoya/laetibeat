import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/core/playback/netease_audio_https_proxy.dart';

void main() {
  group('NeteaseAudioUrlPolicy', () {
    test('upgrades HTTP audio URLs while preserving path and query', () {
      final uri = NeteaseAudioUrlPolicy.normalize(
        'http://m801.music.126.net/song.mp3?auth=abc',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'm801.music.126.net');
      expect(uri.hasPort, isFalse);
      expect(uri.path, '/song.mp3');
      expect(uri.query, 'auth=abc');
    });

    test('moves an explicit HTTP port 80 to HTTPS port 443', () {
      final uri = NeteaseAudioUrlPolicy.normalize(
        'http://m801.music.126.net:80/song.mp3',
      );

      expect(uri.scheme, 'https');
      expect(uri.port, 443);
    });

    test('keeps HTTPS audio URLs unchanged', () {
      final uri = NeteaseAudioUrlPolicy.normalize(
        'https://m801.music.126.net/song.mp3?auth=abc',
      );

      expect(uri.toString(), 'https://m801.music.126.net/song.mp3?auth=abc');
    });

    test('rejects non-HTTP audio URLs', () {
      expect(
        () => NeteaseAudioUrlPolicy.normalize('file:///tmp/song.mp3'),
        throwsFormatException,
      );
    });

    test('allows HTTPS redirects and resolves relative locations', () {
      final next = NeteaseAudioUrlPolicy.resolveRedirect(
        Uri.parse('https://m801.music.126.net/audio/song.mp3'),
        302,
        '../backup/song.mp3',
      );

      expect(next.toString(), 'https://m801.music.126.net/backup/song.mp3');
    });

    test('rejects redirects that downgrade to HTTP', () {
      expect(
        () => NeteaseAudioUrlPolicy.resolveRedirect(
          Uri.parse('https://m801.music.126.net/audio/song.mp3'),
          302,
          'http://m801.music.126.net/backup/song.mp3',
        ),
        throwsFormatException,
      );
    });
  });
}
