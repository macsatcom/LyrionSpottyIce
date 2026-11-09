use strict;
use warnings; no warnings 'once';
use lib 't/lib';
use Test::More;
unshift @INC, sub {
	my (undef, $f) = @_;
	return unless $f =~ m{^Plugins/SpottyIce/(.+)$};
	open my $fh, '<', "./SpottyIce/$1" or return;
	$INC{$f} = "./SpottyIce/$1";
	return $fh;
};
use Slim::Utils::Prefs;
require Plugins::SpottyIce::ProtocolHandler;
my $PH = 'Plugins::SpottyIce::ProtocolHandler';
my $H  = 'Slim::Networking::SimpleAsyncHTTP';
preferences('plugin.spottyice')->set(api_url => 'http://h');

package FakeTrack; sub new { bless { url => $_[1] }, $_[0] } sub url { $_[0]{url} }
package FakeSong;  sub new { bless { track => FakeTrack->new($_[1]) }, $_[0] }
sub track { $_[0]{track} } sub streamUrl { my $s = shift; $s->{su} = shift if @_; $s->{su} }
package FakeClient; sub new { bless { song => $_[1], paused => 0, playing => 1 }, $_[0] }
sub playingSong { $_[0]{song} } sub isPaused { $_[0]{paused} } sub isPlaying { $_[0]{playing} }
package main;

is($PH->uriFromUrl('spottyice://spotify:track:1'), 'spotify:track:1', 'uriFromUrl');
ok($PH->isRemote && !$PH->canSeek, 'remote, no seek');
is($PH->contentType, 'mp3', 'default mp3');

# getNextTrack
my $song = FakeSong->new('spottyice://spotify:album:9');
my ($ok, $err);
$PH->getNextTrack($song, sub { $ok = 1 }, sub { $err = shift });
is($H->last->{url}, 'http://h/api/v1/status', 'status first');
$H->last->respond('{"stream":{"url":"http://ice/live","content_type":"audio/ogg","codec":"flac"}}');
is($H->last->{url}, 'http://h/api/v1/play', 'then play');
like($H->last->{body}, qr/"uri":"spotify:album:9"/, 'play uri');
$H->last->respond('{}');
ok($ok && !$err, 'success');
is($song->streamUrl, 'http://ice/live', 'streamUrl set');
is($PH->contentType, 'ogf', 'flac in ogg');
ok(grep({ $_ == \&Plugins::SpottyIce::ProtocolHandler::_poll } @Slim::Utils::Timers::TIMERS), 'poller scheduled');

my %ct = ('audio/mpeg' => 'mp3', 'audio/aac' => 'aac', 'audio/ogg' => 'ogg');
for (sort keys %ct) {
	$PH->getNextTrack(FakeSong->new('spottyice://x'), sub {}, sub {});
	$H->last->respond(qq({"stream":{"url":"u","content_type":"$_","codec":"vorbis"}}));
	is($PH->getFormatForURL('spottyice://x'), $ct{$_}, "format $_");
}

# play error
($ok, $err) = ();
$PH->getNextTrack($song, sub { $ok = 1 }, sub { $err = shift });
$H->last->fail('Connect timed out');   # status failure is non-fatal
$H->last->fail('409 Conflict');
ok(!$ok, 'no success'); is($err, 'PLUGIN_SPOTTYICE_ERR_409', 'play error');

# new
my $sock = $PH->new({ song => $song, client => 'c' });
is($sock->{url}, 'http://ice/live', 'new uses streamUrl');
ok(!defined $PH->new({ song => FakeSong->new('spottyice://y') }), 'no streamUrl -> undef');

# metadata
my $client = FakeClient->new($song);
my $now = '{"status":"playing","item":{"uri":"spotify:track:5","entity_type":"track","decorations":{"identity":{"name":"Song"},'
	. '"creators":[{"entity":{"decorations":{"identity":{"name":"Art"}}}}],"parent":{"entity":{"decorations":{"identity":{"name":"Alb"}}}},'
	. '"visual_identity":{"cover":[{"url":"http://c","size":"large"}]},"playback":{"duration_ms":61000}}}}';
@Slim::Player::Client::CLIENTS = ($client);
Plugins::SpottyIce::ProtocolHandler::_poll();
is($H->last->{url}, 'http://h/api/v1/now', 'poll /now');
$H->last->respond($now);
is(scalar @Slim::Control::Request::NOTIFY, 1, 'newmetadata on change');
is_deeply($Slim::Control::Request::NOTIFY[0], [$client, ['newmetadata']]);
Plugins::SpottyIce::ProtocolHandler::_poll(); $H->last->respond($now);
is(scalar @Slim::Control::Request::NOTIFY, 1, 'no notify when unchanged');

my $md = $PH->getMetadataFor($client, 'spottyice://spotify:album:9');
is_deeply($md, { title => 'Song', artist => 'Art', album => 'Alb', cover => 'http://c', icon => 'http://c',
	duration => 61, type => 'Spotify (Spotty Ice)' }, 'metadata from now');
my $other = FakeClient->new(FakeSong->new('http://radio'));
is($PH->getMetadataFor($other, 'spottyice://spotify:album:9')->{title}, 'spotify:album:9', 'fallback');

$client->{playing} = 0;
my $before = scalar @Slim::Networking::SimpleAsyncHTTP::REQUESTS;
Plugins::SpottyIce::ProtocolHandler::_poll();
is(scalar @Slim::Networking::SimpleAsyncHTTP::REQUESTS, $before, 'poller stops without active clients');

# onCommand
my $cmd = sub { Plugins::SpottyIce::ProtocolHandler::onCommand(Slim::Control::Request->new(@_)); $H->last };
$client->{paused} = 1; is($cmd->($client, 'pause')->{url}, 'http://h/api/v1/pause', 'pause');
$client->{paused} = 0; my $r = $cmd->($client, 'pause'); is($r->{url}, 'http://h/api/v1/play'); is($r->{body}, '{}', 'resume');
is($cmd->($client, 'stop')->{url}, 'http://h/api/v1/pause', 'stop -> pause');
$before = scalar @Slim::Networking::SimpleAsyncHTTP::REQUESTS;
$cmd->($other, 'pause');
is(scalar @Slim::Networking::SimpleAsyncHTTP::REQUESTS, $before, 'ignore other clients');
done_testing;
