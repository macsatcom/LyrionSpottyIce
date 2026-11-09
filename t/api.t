use strict;
use warnings;
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
require Plugins::SpottyIce::API;
my $API = 'Plugins::SpottyIce::API';
my $H = 'Slim::Networking::SimpleAsyncHTTP';
my $prefs = preferences('plugin.spottyice');

# not configured
is($API->baseUrl, undef, 'no base');
is($API->streamUrl, undef, 'no stream url');
my $err; $API->get('/x', sub {}, sub { $err = shift });
is($err, 'PLUGIN_SPOTTYICE_NOT_CONFIGURED', 'not configured error');

$prefs->set(api_url => 'http://h:8380//');
is($API->baseUrl, 'http://h:8380', 'trailing slash stripped');
is($API->streamUrl, 'http://h:8380/api/v1/stream', 'fallback stream');
$prefs->set(token => 'a b');
is($API->streamUrl, 'http://h:8380/api/v1/stream?token=a%20b', 'token appended');

# status cached stream url
$API->status(sub {});
my $r = $H->last;
is($r->{url}, 'http://h:8380/api/v1/status', 'status url');
is($r->{headers}{Authorization}, 'Bearer a b', 'auth header');
$r->respond('{"stream":{"url":"http://ice:8000/live"}}');
is($API->cachedStatus->{stream}{url}, 'http://ice:8000/live', 'cached');
is($API->streamUrl, 'http://ice:8000/live', 'status stream url, no token for foreign host');
$prefs->set(stream_override => 'http://h:8380/api/v1/stream?x=1');
is($API->streamUrl, 'http://h:8380/api/v1/stream?x=1&token=a%20b', 'override wins, & token');
$prefs->set(stream_override => '');

is($API->itemPath('spotify:album:abc def/x'), '/item/spotify:album:abc%20def%2Fx', 'itemPath');

# post
my $data; $API->play('spotify:track:1', sub { $data = shift });
$r = $H->last;
is($r->{method}, 'POST'); is($r->{url}, 'http://h:8380/api/v1/play');
is($r->{headers}{'Content-Type'}, 'application/json');
like($r->{body}, qr/"uri":"spotify:track:1"/, 'body');
$r->respond('');
is_deeply($data, {}, 'empty body -> {}');
$API->resume; is($H->last->{body}, '{}', 'resume {}');

# error mapping
my %cases = (401 => [undef, 'PLUGIN_SPOTTYICE_ERR_401'], 409 => ['{"detail":"x"}', 'PLUGIN_SPOTTYICE_ERR_409'],
	422 => ['{"detail":"bad uri"}', 'bad uri'], 500 => ['oops', 'PLUGIN_SPOTTYICE_ERR_GENERIC: boom']);
for my $c (sort keys %cases) {
	my $e; $API->pause(sub { fail('cb') }, sub { $e = shift });
	$H->last->fail($c, $cases{$c}[0], 'boom');
	is($e, $cases{$c}[1], "error $c");
}
my $e; $API->get('/now', sub { fail('cb') }, sub { $e = shift });
$H->last->respond('not json');
like($e, qr/ERR_GENERIC/, 'bad json');
is(Plugins::SpottyIce::API::itemPath('spotify:x:1'), '/item/spotify:x:1', 'function call');
done_testing;
