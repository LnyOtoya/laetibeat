# Laetibeat local patch

This directory is a copy of `github.com/guohuiyuan/music-lib` pinned by
`laetibeat_musicapi_host/go.mod`.

Only one change is applied:

- `netease/netease.go`: `cloudSearch` now uses
  `https://music.163.com/weapi/cloudsearch/pc` with `EncryptWeApi` instead of
  the removed `http://music.163.com/api/linux/forward` route (HTTP 502).

The host uses a local `replace` to this directory. When upstream music-lib
fixes the NetEase search provider, delete this directory and the `replace`
line, then bump the module version.
