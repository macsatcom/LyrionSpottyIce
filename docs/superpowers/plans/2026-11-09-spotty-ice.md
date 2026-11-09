# Spotty Ice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LMS plugin that browses/plays Spotify via a Spotify_Soloist_Icecast container (API v1).

**Architecture:** Pure-Perl `Entity.pm` (LMS-independent, unit tested) maps API entities to OPML items. `API.pm` wraps async HTTP. `Plugin.pm` builds OPML menus; `ProtocolHandler.pm` handles `spottyice://` by calling `POST /play` and redirecting to the Icecast stream; `Settings.pm` stores prefs.

**Tech Stack:** Perl 5, LMS 8 plugin API (`Slim::Plugin::OPMLBased`, `Slim::Networking::SimpleAsyncHTTP`, `Slim::Player::Protocols::HTTP`), `Test::More`.

Layout: `SpottyIce/` (plugin, zip-able), `t/` (tests), `t/lib/Slim/...` (minimal stubs for compile checks).

---

### Task 1: Entity mapping (TDD)
**Files:** Create `SpottyIce/Entity.pm`, Test `t/entity.t`
- [ ] Write `t/entity.t` covering: `name`, `creators` (joined ", "), `cover` (prefers large > default > last), `isContainer` (album/playlist/artist/show), `toItem` (type `audio` + `url spottyice://uri` for track/episode; `link` container for others; `line2`, `image`), missing fields don't die.
- [ ] Run `prove -l t/entity.t` → FAIL (module missing).
- [ ] Implement `SpottyIce/Entity.pm` (package `Plugins::SpottyIce::Entity`, no Slim deps).
- [ ] Run → PASS. Commit.

### Task 2: Manifest, strings, settings
**Files:** `SpottyIce/install.xml`, `SpottyIce/strings.txt`, `SpottyIce/Settings.pm`, `SpottyIce/HTML/EN/plugins/SpottyIce/settings/basic.html`
- [ ] Prefs `plugin.spottyice`: `api_url`, `token`, `stream_override`. Settings page shows connection test from cached `/status`. Commit.

### Task 3: API client
**Files:** `SpottyIce/API.pm`
- [ ] `get($path,$cb,$ecb)`, `post($path,$body,$cb,$ecb)`, `status`, `streamUrl`, `errorText($code)` (401/409/other). Bearer header. Commit.

### Task 4: Plugin menus
**Files:** `SpottyIce/Plugin.pm`
- [ ] OPML top menu, search (per type), library endpoints, `/item/{uri}` children with paging ("More…" item when `next`), `children.error` text, Now playing. Track items: play + "Add to queue". Commit.

### Task 5: Protocol handler + metadata poller
**Files:** `SpottyIce/ProtocolHandler.pm`
- [ ] `getNextTrack` → `POST /play {uri}` → `$song->streamUrl(API->streamUrl)`; `canSeek` 0; `isRemote` 1; `getMetadataFor` from `/now` cache; poll `/now` every 2 s while a client plays `spottyice://`; notify `newmetadata` on change; forward pause/resume. Commit.

### Task 6: Compile checks + packaging
**Files:** `t/lib/Slim/**` stubs, `t/compile.t`, `Makefile`/script producing `SpottyIce.zip`, `README.md`
- [ ] `prove -l -It/lib t/` → PASS. Build zip. Commit.
