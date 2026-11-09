<p align="center">
  <img src="SpottyIce/HTML/EN/plugins/SpottyIce/html/images/spottyice.svg" alt="Spotty Ice logo" width="160">
</p>

# Spotty Ice

Lyrion Music Server (LMS 8+) plugin for
[Spotify_Soloist_Icecast](https://github.com/macsatcom/Spotify_Soloist_Icecast).
Browse and search Spotify through the container's API v1 and play it in LMS via the
container's Icecast stream.

## Requirements

- Lyrion Music Server 8.0 or newer.
- A running [Spotify_Soloist_Icecast](https://github.com/macsatcom/Spotify_Soloist_Icecast)
  container that LMS can reach on the network (API, default port 8380, and the Icecast
  stream, default port 8100).
- Soloist paired with your Spotify account (select the device once in the Spotify app).
- For the Search and library menus: the Spotify Web API connected once in the container's
  web UI (*Browse* tab).

## Install in Lyrion

### 1. Add the plugin repository

1. Open the Lyrion web interface (e.g. `http://<lms-host>:9000`).
2. Go to *Settings* → *Manage Plugins*.
3. Scroll to the bottom. In the field *Additional Repositories*, paste:

   ```
   https://raw.githubusercontent.com/macsatcom/LyrionSpottyIce/master/repo.xml
   ```

4. Click *Apply*. Lyrion reloads the plugin list.

### 2. Install the plugin

1. Still in *Manage Plugins*, find *Spotty Ice* under the third-party plugins
   (category *Music services*).
2. Tick its checkbox and click *Apply*.
3. Lyrion downloads the plugin and asks to restart. Click *Restart now*
   (or restart the server yourself).

### 3. Configure

1. After the restart, go to *Settings* → *Manage Plugins*, find *Spotty Ice* and click
   *Settings* (or *Settings* → *Advanced* → *Spotty Ice*).
2. *Container URL*: the container address with its web port, e.g.
   `http://192.168.1.75:8380`. Use an IP/hostname that the LMS host can reach, not
   `localhost` (unless LMS runs on the same host).
3. *API token*: only if *Require API token* is enabled in the container's settings.
4. *Stream URL override*: leave empty. The stream URL is read from the container
   (`/api/v1/status`); only set this for unusual network setups.
5. Click *Apply*. The *Connection* section should show *Logged in*, the device name and the
   days left of the Soloist binary.

### 4. Play

On any player: *My Apps* → *Spotty Ice*. Browse or search and pick a track, album,
playlist or podcast. Expect a few seconds before the music starts.

### Updates

When a new version is released, Lyrion shows it in *Manage Plugins* (and on the home
screen as "plugin updates available"). Apply and restart to update.

### Manual install (without the repository)

Download `SpottyIce-<version>.zip` from the
[Releases](https://github.com/macsatcom/LyrionSpottyIce/releases) page and unzip it into a
folder named `SpottyIce` inside the LMS `Plugins` folder, so that you get
`.../Plugins/SpottyIce/install.xml`. Typical locations:

- Linux package: `/usr/share/squeezeboxserver/Plugins/` or `/var/lib/squeezeboxserver/Plugins/`
- Docker (`lmscommunity/lyrionmusicserver`): `/config/cache/Plugins/` (the
  `/config` volume)

Then restart LMS. Manually installed plugins are not updated automatically.

### Troubleshooting

| Message | Fix |
|---|---|
| *API token missing or wrong* | Enter the token from the container settings, or disable *Require API token* |
| *Soloist is not running or not logged in* | Select the Soloist device once in the Spotify app; wait for the container to finish restarting |
| *Spotify Web API not connected* | Connect it in the container's web UI, *Browse* tab |
| Plugin not listed after adding the repository | Check the URL; LMS caches repositories for a few minutes, restart LMS to force a reload |
| No sound but status says playing | Check that the LMS host can reach the stream URL shown in `/api/v1/status` |

Debug logging: *Settings* → *Advanced* → *Logging*, set `plugin.spottyice` to *Debug*.

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
