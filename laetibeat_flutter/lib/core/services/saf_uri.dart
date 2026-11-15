/// Android SAF document URI helpers.
///
/// Document URI 形如：
/// `content://.../tree/<treeId>/document/<encodedDocId>`
/// 其中 encodedDocId 解码后通常是 `primary:Music/Artist/Album/song.flac`。
String? safParentDocumentUri(String uri) {
  const marker = '/document/';
  final index = uri.lastIndexOf(marker);
  if (index < 0) return null;

  final prefix = uri.substring(0, index + marker.length);
  final encodedDocument = uri.substring(index + marker.length);
  final document = Uri.decodeComponent(encodedDocument);
  final slash = document.lastIndexOf('/');
  if (slash <= 0) return null;

  final parent = Uri.encodeComponent(document.substring(0, slash));
  return '$prefix$parent';
}

/// 从 SAF document URI 取文件名（已解码）。
String safDocumentName(String uri) {
  const marker = '/document/';
  final index = uri.lastIndexOf(marker);
  if (index < 0) return uri;
  final document = Uri.decodeComponent(uri.substring(index + marker.length));
  final slash = document.lastIndexOf('/');
  return slash < 0 ? document : document.substring(slash + 1);
}

/// 去掉扩展名后的文件名。
String safDocumentStem(String uri) {
  final name = safDocumentName(uri);
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}
