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
my %cases = ('401 Unauthorized' => 'PLUGIN_SPOTTYICE_ERR_401', '409 Conflict' => 'PLUGIN_SPOTTYICE_ERR_409',
	'422 Unprocessable Entity' => 'PLUGIN_SPOTTYICE_ERR_GENERIC: 422 Unprocessable Entity',
	'500 Internal Server Error' => 'PLUGIN_SPOTTYICE_ERR_GENERIC: 500 Internal Server Error',
	'Connect timed out' => 'PLUGIN_SPOTTYICE_ERR_GENERIC: Connect timed out');
for my $c (sort keys %cases) {
	my $e; $API->pause(sub { fail('cb') }, sub { $e = shift });
	$H->last->fail($c);
	is($e, $cases{$c}, "error $c");
}
$API->status(undef, undef, 5);
is($H->last->params->{timeout}, 5, 'custom timeout');
$API->now;
is($H->last->params->{timeout}, 15, 'default timeout');
my $e; $API->get('/now', sub { fail('cb') }, sub { $e = shift });
$H->last->respond('not json');
like($e, qr/ERR_GENERIC/, 'bad json');
done_testing;
