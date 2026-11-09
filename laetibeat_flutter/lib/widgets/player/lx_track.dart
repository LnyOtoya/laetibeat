import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

/// Convert the app's generic track into the music info expected by LX.
///
/// LX tracks use:
/// - [rust.UiTrack.source] = "lx"
/// - [rust.UiTrack.sourceId] = LX platform key, e.g. "kw", "kg", "tx"
/// - [rust.UiTrack.id] = music id inside that platform
/// - [rust.UiTrack.coverId] = optional resolved picture URL
rust_lx.UiLxMusicInfo lxMusicInfoFromTrack(rust.UiTrack track) {
  return rust_lx.UiLxMusicInfo(
    source: track.sourceId,
    id: track.id,
    name: track.title,
    singer: <String>[if (track.artist.trim().isNotEmpty) track.artist],
    album: track.album,
    albumId: track.albumId,
    interval: track.durationSeconds.toInt(),
    img: track.coverId,
  );
}

String lxQualityForTrack(rust.UiTrack track) {
  final bitrate = track.bitrate ?? 0;
  if (bitrate >= 1000) return 'flac';
  if (bitrate >= 320) return '320k';
  return '128k';
}
