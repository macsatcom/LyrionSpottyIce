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
is(scalar @{ $res->{items} }, 8, '8 top items');
is_deeply([map { $_->{name} } @{ $res->{items} }],
	[qw(PLUGIN_SPOTTYICE_SEARCH PLUGIN_SPOTTYICE_PLAYLISTS PLUGIN_SPOTTYICE_ALBUMS PLUGIN_SPOTTYICE_LIKED
	    PLUGIN_SPOTTYICE_ARTISTS PLUGIN_SPOTTYICE_PODCASTS PLUGIN_SPOTTYICE_RECENT PLUGIN_SPOTTYICE_NOW_PLAYING)], 'names');
is(scalar @{ $res->{items}[0]{items} }, 5, '5 search types');

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
is_deeply($res->{items}, [{ name => 'boom', type => 'text' }], 'children error');

Plugins::SpottyIce::Plugin::browseItem(undef, $cb, {}, { uri => 'spotify:artist:1' });
$H->last->respond('{"item":{"uri":"spotify:artist:1","entity_type":"artist"},"top_tracks":[{"uri":"spotify:track:1","entity_type":"track"}],"children":{"items":[{"uri":"spotify:album:3","entity_type":"album"}],"offset":0,"limit":50,"next":true}}');
is($res->{items}[0]{name}, 'PLUGIN_SPOTTYICE_TOP_TRACKS', 'top tracks');
is($res->{items}[0]{items}[0]{url}, 'spottyice://spotify:track:1');
is($res->{items}[1]{type}, 'playlist', 'album child');
my $more = $res->{items}[2];
$more->{url}->(undef, $cb, {}, $more->{passthrough}[0]);
is($H->last->{url}, 'http://h/api/v1/item/spotify:artist:1?limit=50&offset=50', 'children paging');

Plugins::SpottyIce::Plugin::nowPlaying(undef, $cb, {});
$H->last->respond('{}');
is($res->{items}[0]{name}, 'PLUGIN_SPOTTYICE_NOTHING_PLAYING');
Plugins::SpottyIce::Plugin::nowPlaying(undef, $cb, {});
$H->last->respond('{"status":"playing","item":{"uri":"spotify:track:1","entity_type":"track","decorations":{"identity":{"name":"Song"}}}}');
is($H->last->{url}, 'http://h/api/v1/queue?limit=10', 'queue fetch');
$H->last->respond('{"upcoming":[{"uri":"spotify:track:2","entity_type":"track"}]}');
is_deeply([map { $_->{name} } @{ $res->{items} }], ['Song', 'playing', 'spotify:track:2'], 'now playing');
done_testing;
