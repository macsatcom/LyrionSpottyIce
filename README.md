# Spotty Ice

Lyrion Music Server (LMS 8+) plugin for
[Spotify_Soloist_Icecast](https://github.com/macsatcom/Spotify_Soloist_Icecast).
Browse and search Spotify through the container's API v1 and play it in LMS via the
container's Icecast stream.

## Install

1. `make zip` (runs tests, builds `SpottyIce-<version>.zip`).
2. Unzip into the LMS plugin folder (e.g. `/var/lib/squeezeboxserver/cache/InstalledPlugins/Plugins/`
   or `<prefs>/Plugins/`) so you get `.../Plugins/SpottyIce/install.xml`, then restart LMS.
3. *Settings → Plugins → Spotty Ice*: set the API URL (e.g. `http://192.168.1.75:8380`) and,
   if *Require API token* is enabled in the container, the token. The page shows the
   connection status (logged in, device, days left).

The stream URL is read from `/api/v1/status`; use the override field only for unusual
network setups. Search/library menus require the Spotify Web API to be connected once in
the container's Browse tab.

## How it works

- Menus (*My Apps → Spotty Ice*): Search, Playlists, Albums, Liked songs, Artists,
  Podcasts, Recently played, Now playing.
- Items play as `spottyice://spotify:…`. The protocol handler calls `POST /play {uri}` and
  hands LMS the Icecast stream. A whole album/playlist plays inside that one live stream.
- Now-playing metadata is polled from `/api/v1/now` every 2 s while playing.
- LMS pause/unpause/stop → `/pause` / `/play`. Seeking and LMS next/prev are not supported
  (live stream). Keep volume in LMS; Soloist stays at 100.
- Expect a few seconds of latency between a command and hearing it.

One container = one Spotify device = one stream; players on the same container hear the same thing.

## Development

`make test` runs the test suite against minimal LMS stubs in `t/lib/` (no LMS needed).

## Releases

Publishing a GitHub release (tag `vX.Y`) triggers `.github/workflows/release.yml`: it runs
the tests, sets `install.xml` version from the tag, and attaches `SpottyIce-X.Y.zip` (+ `.sha1`)
as a release asset. Download counts are visible via
`gh release view vX.Y --json assets`. A release can be rebuilt with *Run workflow* (tag input).
