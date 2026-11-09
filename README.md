# Spotty Ice

Lyrion Music Server (LMS 8+) plugin for
[Spotify_Soloist_Icecast](https://github.com/macsatcom/Spotify_Soloist_Icecast).
Browse and search Spotify through the container's API v1 and play it in LMS via the
container's Icecast stream.

## Install

1. In LMS: *Settings → Manage Plugins*, add this repository URL at the bottom and apply:

   `https://raw.githubusercontent.com/macsatcom/LyrionSpottyIce/master/repo.xml`

2. Enable *Spotty Ice* in the plugin list, apply and restart LMS when asked. Updates are
   offered automatically when a new release is published.
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
as a release asset, and (for the latest release) regenerates `repo.xml` on `master`
with the asset URL and SHA1, so LMS offers the update. Download counts are visible via
`gh release view vX.Y --json assets`. A release can be rebuilt with *Run workflow* (tag input).
