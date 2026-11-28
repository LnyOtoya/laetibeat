import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_mode.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/settings/mode_runtime.dart';

class _FakeAppModeNotifier extends AppModeNotifier {
  @override
  AppMode build() => AppMode.netease;
}

class _FakePlayerNotifier extends PlayerNotifier {
  _FakePlayerNotifier(this.track);

  final rust.UiTrack track;

  @override
  PlayerState build() => PlayerState(queue: <rust.UiTrack>[track]);
}

class _FakeLxCoverProvider extends LxCoverProvider {
  _FakeLxCoverProvider(this.bytes);

  final Uint8List bytes;
  rust.UiTrack? requestedTrack;

  @override
  Future<Uint8List?> cover(rust.UiTrack track) async {
    requestedTrack = track;
    return bytes;
  }
}

class _DirectHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

rust.UiTrack _track({required String source, required String coverId}) {
  return rust.UiTrack(
    id: 'track-1',
    title: 'Track',
    artist: 'Artist',
    album: 'Album',
    albumArtist: 'Artist',
    albumId: 'album-1',
    artistId: 'artist-1',
    duration: '1:00',
    durationSeconds: BigInt.from(60),
    path: '',
    source: source,
    sourceId: source == 'lx' ? 'kw' : source,
    coverId: coverId,
  );
}

Future<Uint8List> _testPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xff336699), ui.BlendMode.src);
  final image = await recorder.endRecording().toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'online playback cover retries when its sidecar becomes ready',
    () async {
      final bytes = await _testPng();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      server.listen((HttpRequest request) async {
        requestCount++;
        expect(request.uri.path, '/api/v1/image');
        expect(request.uri.queryParameters['url'], 'https://cover.example/art');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-token',
        );
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('image', 'png')
          ..add(bytes);
        await request.response.close();
      });

      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWith(_FakeAppModeNotifier.new),
          playerProvider.overrideWith(
            () => _FakePlayerNotifier(
              _track(source: 'netease', coverId: 'https://cover.example/art'),
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await server.close(force: true);
      });

      expect(await container.read(playbackCoverProvider.future), isNull);
      expect(requestCount, 0);

      container
          .read(modeRuntimeProvider.notifier)
          .set(
            mode: AppMode.netease,
            baseUrl: 'http://${server.address.address}:${server.port}',
            token: 'test-token',
          );

      final cover = await HttpOverrides.runZoned(
        () => container.read(playbackCoverProvider.future),
        createHttpClient: (context) =>
            _DirectHttpOverrides().createHttpClient(context),
      );
      expect(cover?.bytes, bytes);
      expect(requestCount, 1);
    },
  );

  test(
    'LX playback cover uses its source even when cover ID is a URL',
    () async {
      final bytes = await _testPng();
      final track = _track(source: 'lx', coverId: 'https://cover.example/art');
      final lxCoverProvider = _FakeLxCoverProvider(bytes);
      final container = ProviderContainer(
        overrides: [
          playerProvider.overrideWith(() => _FakePlayerNotifier(track)),
          lxCoverSourceProvider.overrideWith((ref) => lxCoverProvider),
        ],
      );
      addTearDown(container.dispose);

      final cover = await container.read(playbackCoverProvider.future);

      expect(cover?.bytes, bytes);
      expect(lxCoverProvider.requestedTrack, track);
    },
  );
}
