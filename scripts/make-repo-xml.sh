#!/bin/sh
# Usage: scripts/make-repo-xml.sh VERSION SHA1 ZIP_URL > repo.xml
set -eu
VERSION="$1"; SHA="$2"; URL="$3"
REPO="https://github.com/macsatcom/LyrionSpottyIce"
cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<extensions>
	<details>
		<title lang="EN">Spotty Ice plugin repository</title>
	</details>
	<plugins>
		<plugin name="SpottyIce" version="${VERSION}" minTarget="8.0" maxTarget="*">
			<title lang="EN">Spotty Ice</title>
			<title lang="DA">Spotty Ice</title>
			<desc lang="EN">Browse and play Spotify via a Spotify_Soloist_Icecast container.</desc>
			<desc lang="DA">Gennemse og afspil Spotify via en Spotify_Soloist_Icecast-container.</desc>
			<creator>Kasper S Nielsen</creator>
			<category>musicservices</category>
			<link>${REPO}</link>
			<icon>https://raw.githubusercontent.com/macsatcom/LyrionSpottyIce/master/SpottyIce/HTML/EN/plugins/SpottyIce/html/images/spottyice_svg.png</icon>
			<url>${URL}</url>
			<sha>${SHA}</sha>
		</plugin>
	</plugins>
</extensions>
EOF
