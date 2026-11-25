import 'dart:convert';

import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import '../../l10n/generated/app_localizations.dart';
import '../settings/netease_provider.dart';

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
    extraJson: track.sourceExtraJson,
  );
}

/// Convert a NetEase provider track into the `wy` music info expected by LX.
///
/// NetEase tracks use `sourceId` for the API base URL, not the LX platform key,
/// so [lxMusicInfoFromTrack] cannot be reused directly.
rust_lx.UiLxMusicInfo neteaseLxMusicInfoFromTrack(rust.UiTrack track) {
  final singers = track.artist
      .split('、')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return rust_lx.UiLxMusicInfo(
    source: 'wy',
    id: neteaseSongIdFromTrack(track),
    name: track.title,
    singer: singers,
    album: track.album,
    albumId: track.albumId,
    interval: track.durationSeconds.toInt(),
    img: track.coverId,
    extraJson: track.sourceExtraJson,
  );
}

String lxQualityForTrack(rust.UiTrack track) {
  final bitrate = track.bitrate ?? 0;
  if (bitrate >= 1000) return 'flac';
  if (bitrate >= 320) return '320k';
  return '128k';
}

rust.UiTrack lxSearchTrackToUiTrack(rust_lx.UiLxSearchTrack track) {
  final artist = track.singer.join('、');
  final seconds = track.interval < 0 ? 0 : track.interval;
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return rust.UiTrack(
    id: track.id,
    title: track.name,
    artist: artist,
    album: track.album,
    albumArtist: artist,
    albumId: track.albumId,
    artistId: '',
    duration: '$minutes:${remainder.toString().padLeft(2, '0')}',
    durationSeconds: BigInt.from(seconds),
    path: '',
    source: 'lx',
    sourceId: track.source,
    coverId: track.img,
    sourceExtraJson: track.extraJson.isEmpty ? null : track.extraJson,
  );
}

/// 曲目可用音质（`sourceExtraJson.types`），按音质从高到低排列。
///
/// 该列表由 Rust 侧解析（kw / kg / tx / wy / mg 各自的质量字段）后写入
/// `extra`，随队列快照持久化；老数据没有这个字段时返回空列表。
List<String> lxAvailableQualities(String? extraJson) {
  if (extraJson == null || extraJson.isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(extraJson);
    if (decoded is Map) {
      final types = decoded['types'];
      if (types is List) {
        return types.whereType<String>().toList(growable: false);
      }
    }
  } catch (_) {
    // 快照损坏或旧格式：交给播放端回退到默认质量阶梯。
  }
  return const <String>[];
}

/// 列表中展示用的音质标签；没有音质信息时返回 null。
String? lxQualityLabel(AppLocalizations l10n, rust.UiTrack track) {
  final types = lxAvailableQualities(track.sourceExtraJson);
  if (types.isEmpty) return null;
  return switch (types.first) {
    'flac24bit' => l10n.lxQualityFlac,
    'flac' => l10n.lxQualityFlac,
    '320k' => l10n.lxQuality320,
    '128k' => l10n.lxQuality128,
    _ => types.first,
  };
}
