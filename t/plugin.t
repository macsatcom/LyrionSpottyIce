use strict;
use warnings; no warnings "once";
use lib 't/lib';
use Test::More;
unshift @INC, sub {
	my (undef, $f) = @_;
	return unless $f =~ m{^Plugins/SpottyIce/(.+)$};
	open my $fh, '<', "./SpottyIce/$1" or return;
	$INC{$f} = "./SpottyIce/$1";
	return $fh;
};
BEGIN { $INC{'Plugins/SpottyIce/ProtocolHandler.pm'} = 1; *main::WEBUI = sub () { 0 } }
use Slim::Utils::Prefs;
require Plugins::SpottyIce::Plugin;
my $P = 'Plugins::SpottyIce::Plugin';
my $H = 'Slim::Networking::SimpleAsyncHTTP';
my $prefs = preferences('plugin.spottyice');

$P->initPlugin;
is($Slim::Plugin::OPMLBased::ARGS{tag}, 'spottyice', 'tag');
is($Slim::Player::ProtocolHandlers::HANDLERS{spottyice}, 'Plugins::SpottyIce::ProtocolHandler', 'handler');
is_deeply($Slim::Control::Request::SUBS[0][1], [['pause', 'play', 'stop']], 'transport subscribe');

my $res; my $cb = sub { $res = shift };
Plugins::SpottyIce::Plugin::handleFeed(undef, $cb, {});
is($res->{items}[0]{type}, 'textarea', 'not configured');

$prefs->set(api_url => 'http://h');
Plugins::SpottyIce::Plugin::handleFeed(undef, $cb, {});
is(scalar @{ $res->{items} }, 11, '11 top items');
is_deeply([map { $_->{name} } @{ $res->{items} }],
	[qw(PLUGIN_SPOTTYICE_SEARCH PLUGIN_SPOTTYICE_PLAYLISTS PLUGIN_SPOTTYICE_ALBUMS PLUGIN_SPOTTYICE_LIKED
	    PLUGIN_SPOTTYICE_ARTISTS PLUGIN_SPOTTYICE_PODCASTS PLUGIN_SPOTTYICE_RECENT PLUGIN_SPOTTYICE_TOP_TRACKS
	    PLUGIN_SPOTTYICE_TOP_ARTISTS PLUGIN_SPOTTYICE_PLAY_LINK PLUGIN_SPOTTYICE_NOW_PLAYING)], 'names');
is(scalar @{ $res->{items}[0]{items} }, 6, '6 search types');
is($res->{items}[0]{items}[5]{passthrough}[0]{type}, 'episode', 'episode search');
is($res->{items}[7]{passthrough}[0]{path}, '/library/top/tracks', 'top tracks path');
is($res->{items}[8]{passthrough}[0]{path}, '/library/top/artists', 'top artists path');
is($res->{items}[9]{type}, 'search', 'play link is an input item');

Plugins::SpottyIce::Plugin::_browsePage(undef, $cb, {}, { path => '/library/albums', offset => 0 });
is($H->last->{url}, 'http://h/api/v1/library/albums?limit=50&offset=0', 'page url');
$H->last->respond('{"items":[{"uri":"spotify:album:1","entity_type":"album"},{"uri":"x","entity_type":"ad"}],"offset":0,"limit":50,"next":true}');
is(scalar @{ $res->{items} }, 2, 'album + more');
is($res->{items}[0]{type}, 'playlist');
is($res->{items}[1]{name}, 'PLUGIN_SPOTTYICE_MORE');
is($res->{items}[1]{passthrough}[0]{offset}, 50, 'next offset');

Plugins::SpottyIce::Plugin::_browsePage(undef, $cb, {}, { path => '/library/x?a=1', offset => 5 });
is($H->last->{url}, 'http://h/api/v1/library/x?a=1&limit=50&offset=5', '& join');
$H->last->respond('{"items":[]}');
is($res->{items}[0]{name}, 'PLUGIN_SPOTTYICE_NO_RESULTS', 'empty');

Plugins::SpottyIce::Plugin::_browsePage(undef, $cb, {}, { path => '/library/x' });
$H->last->fail('409 Conflict');
is_deeply($res, { items => [{ name => 'PLUGIN_SPOTTYICE_ERR_409', type => 'text' }] }, 'error');

Plugins::SpottyIce::Plugin::search(undef, $cb, { search => 'a b' }, { type => 'album' });
is($H->last->{url}, 'http://h/api/v1/search?q=a%20b&type=album&limit=10&offset=0', 'search url');
$H->last->respond('{"album":{"items":[{"uri":"spotify:album:2","entity_type":"album"}],"offset":0,"limit":10,"next":true}}');
is($res->{items}[1]{passthrough}[0]{offset}, 10, 'search more');
is($res->{items}[1]{passthrough}[0]{query}, 'a b');

Plugins::SpottyIce::Plugin::browseItem(undef, $cb, {}, { uri => 'spotify:playlist:1' });
is($H->last->{url}, 'http://h/api/v1/item/spotify:playlist:1');
$H->last->respond('{"item":{"uri":"spotify:playlist:1","entity_type":"playlist"},"children":{"items":[],"total":0,"error":"boom"}}');
is_deeply($res->{items}[1], { name => 'boom', type => 'text' }, 'children error shown');
is_deeply([@{ $res->{items}[0] }{qw(name type url)}], ['PLUGIN_SPOTTYICE_PLAY', 'audio', 'spottyice://spotify:playlist:1'], 'Play entry even when tracks cannot be listed');

Plugins::SpottyIce::Plugin::browseItem(undef, $cb, {}, { uri => 'spotify:artist:1' });
$H->last->respond('{"item":{"uri":"spotify:artist:1","entity_type":"artist"},"top_tracks":[{"uri":"spotify:track:1","entity_type":"track"}],"children":{"items":[{"uri":"spotify:album:3","entity_type":"album"}],"offset":0,"limit":50,"next":true}}');
is($res->{items}[0]{url}, 'spottyice://spotify:artist:1', 'play artist');
is($res->{items}[1]{name}, 'PLUGIN_SPOTTYICE_TOP_TRACKS', 'top tracks');
is($res->{items}[1]{items}[0]{url}, 'spottyice://spotify:track:1');
is($res->{items}[2]{type}, 'playlist', 'album child');
my $more = $res->{items}[3];
$more->{url}->(undef, $cb, {}, $more->{passthrough}[0]);
is($H->last->{url}, 'http://h/api/v1/item/spotify:artist:1?limit=50&offset=50', 'children paging');

Plugins::SpottyIce::Plugin::nowPlaying(undef, $cb, {});
$H->last->respond('{}');
is($res->{items}[0]{name}, 'PLUGIN_SPOTTYICE_NOTHING_PLAYING');
Plugins::SpottyIce::Plugin::nowPlaying(undef, $cb, {});
$H->last->respond('{"status":"playing","item":{"uri":"spotify:track:1","entity_type":"track","decorations":{"identity":{"name":"Song"}}}}');
is($H->last->{url}, 'http://h/api/v1/queue?limit=10', 'queue fetch');
$H->last->respond('{"upcoming":[{"uid":"u","source":"context","item":{"uri":"spotify:track:2","entity_type":"track"}}]}');
is_deeply([map { $_->{name} } @{ $res->{items} }], ['Song', 'playing', 'spotify:track:2'], 'now playing');
# Playing a container: playlist is a coderef yielding one spottyice:// audio item (never an HTTP-fetched string)
{
	my $it = Plugins::SpottyIce::Plugin::_mapPage(undef, { items => [{ uri => 'spotify:album:6y', entity_type => 'album', decorations => { identity => { name => 'Alb' } } }] })->[0];
	is(ref $it->{playlist}, 'CODE', 'container playlist is a coderef');
	my $got;
	$it->{playlist}->(undef, sub { $got = shift }, {}, @{ $it->{passthrough} });
	is_deeply($got->{items}, [{ name => 'Alb', type => 'audio', url => 'spottyice://spotify:album:6y' }], 'play container -> one spottyice item');
}
# Play Spotify link / URI
Plugins::SpottyIce::Plugin::playLink(undef, $cb, { search => 'https://open.spotify.com/intl-de/album/4aaw?si=x' });
is_deeply($res->{items}[0]{url}, 'spottyice://spotify:album:4aaw', 'share link -> audio item');
is($res->{items}[0]{type}, 'audio');
Plugins::SpottyIce::Plugin::playLink(undef, $cb, { search => 'hello' });
is_deeply($res, { items => [{ name => 'PLUGIN_SPOTTYICE_PLAY_LINK_INVALID', type => 'text' }] }, 'invalid link');
done_testing;
