# Spotty Ice – Lyrion plugin design

Lyrion Music Server (LMS 8+) plugin that drives a Spotify_Soloist_Icecast container via its
API v1 (docs/API.md upstream) and plays its Icecast stream.

## Components (`SpottyIce/`)
- `install.xml`, `strings.txt` – manifest, EN/DA strings.
- `Plugin.pm` – `Slim::Plugin::OPMLBased`. Menus: Search (track, album, artist, playlist,
  show), Playlists, Albums, Liked songs, Artists, Podcasts, Recently played, Now playing.
  Entity → item: name = `identity.name`, line2 = creator names, image = cover
  (`large` > `default` > last). Containers (album/playlist/artist/show) open via
  `/api/v1/item/{uri}`; paging via `limit`/`offset` while `next` is true ("More…" item).
  `children.error` shown as a text item. Playable items: `type => 'audio'`,
  `url => spottyice://<uri>`. Containers also get a play URL so the whole context plays.
- `API.pm` – async JSON client (`Slim::Networking::SimpleAsyncHTTP`), Bearer token header,
  callbacks `(data)` / `(error)`. Caches `/status`. `streamUrl()` = override pref or
  `stream.url`, token appended as `?token=` if set.
- `ProtocolHandler.pm` – subclass of `Slim::Player::Protocols::HTTP`, scheme `spottyice`.
  `getNextTrack`: `POST /play {uri}`, then `$song->streamUrl(streamUrl)`. Live stream:
  `isRemote`, `canSeek` = 0. `getMetadataFor`: from cached `/now`. Transport: subscribe to
  `pause`/`playlist jump` commands – pause → `/pause`, resume → `/play {}`.
- Metadata poller: while any player plays a `spottyice://` URL, poll `/now` every 2 s;
  on item URI change, call `Slim::Control::Request::notifyFromArray($client,['newmetadata'])`.
- `Settings.pm` + `HTML/EN/plugins/SpottyIce/settings/basic.html`: prefs `api_url`,
  `token`, `stream_override`; shows `logged_in`, device name, `updater.days_left`.

## Errors
401 → "check API token"; 409 → "Soloist not running / not logged in"; Web API not
connected → message item. No retries beyond user re-selection.

## Out of scope
SSE, multiple containers, seeking, Soloist volume control (always LMS volume).

## Testing
`perl -c`-style syntax check with stubbed Slim modules; mock API (Python) for manual requests.
