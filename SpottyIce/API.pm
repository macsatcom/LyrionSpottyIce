package Plugins::SpottyIce::API;

use strict;
use warnings;

use JSON::XS::VersionOneAndTwo;
use URI::Escape qw(uri_escape_utf8);

use Slim::Networking::SimpleAsyncHTTP;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);

my $log = Slim::Utils::Log->addLogCategory({
	category     => 'plugin.spottyice',
	defaultLevel => 'WARN',
	description  => 'PLUGIN_SPOTTYICE',
});

my $prefs = preferences('plugin.spottyice');

use constant TIMEOUT => 15;

my ($STATUS, $STATUS_TS, $NOW, $NOW_TS);

sub baseUrl {
	my $url = $prefs->get('api_url');
	return undef unless defined $url && $url =~ /\S/;
	$url =~ s/^\s+|\s+$//g;
	$url =~ s{/+$}{};
	return $url;
}

sub _token {
	my $t = $prefs->get('token');
	return (defined $t && length $t) ? $t : undef;
}

sub get {
	my ($class, $path, $cb, $ecb, $timeout) = @_;
	$class->_request('GET', $path, undef, $cb, $ecb, $timeout);
}

sub post {
	my ($class, $path, $body, $cb, $ecb) = @_;
	$class->_request('POST', $path, $body || {}, $cb, $ecb);
}

sub _request {
	my ($class, $method, $path, $body, $cb, $ecb, $timeout) = @_;
	$cb  ||= sub {};
	$ecb ||= sub {};

	my $base = $class->baseUrl or return $ecb->(string('PLUGIN_SPOTTYICE_NOT_CONFIGURED'));
	my $url = "$base/api/v1$path";

	my @headers;
	if (my $token = _token()) {
		push @headers, Authorization => "Bearer $token";
	}

	main::DEBUGLOG && $log->is_debug && $log->debug("$method $url");

	my $http = Slim::Networking::SimpleAsyncHTTP->new(
		sub {
			my $http = shift;
			my $content = $http->content;
			my $data = {};
			if (defined $content && $content =~ /\S/) {
				$data = eval { decode_json($content) };
				if ($@) {
					$log->warn("Invalid JSON from $url: $@");
					return $ecb->(string('PLUGIN_SPOTTYICE_ERR_GENERIC') . ': invalid JSON');
				}
			}
			$cb->($data);
		},
		sub {
			my ($http, $error) = @_;
			$ecb->(_errorMessage($http, $error, $url));
		},
		{ timeout => $timeout || TIMEOUT },
	);

	if ($method eq 'POST') {
		$http->post($url, @headers, 'Content-Type' => 'application/json', encode_json($body));
	}
	else {
		$http->get($url, @headers);
	}
}

sub _errorMessage {
	my ($http, $error, $url) = @_;
	# LMS SimpleAsyncHTTP passes e.g. "401 Unauthorized" and does not set code/content
	my ($code) = (defined $error ? $error : '') =~ /^(\d{3})\b/;
	$code ||= eval { $http->code } || 0;
	$log->warn("Request failed ($url): " . ($error || '') . ($code ? " [$code]" : ''));

	return string('PLUGIN_SPOTTYICE_ERR_401') if $code == 401;
	return string('PLUGIN_SPOTTYICE_ERR_409') if $code == 409;
	return string('PLUGIN_SPOTTYICE_ERR_GENERIC') . (defined $error && length $error ? ": $error" : '');
}

sub status {
	my ($class, $cb, $ecb, $timeout) = @_;
	$class->get('/status', sub {
		$STATUS = shift;
		$STATUS_TS = time();
		$cb->($STATUS) if $cb;
	}, $ecb, $timeout);
}
sub cachedStatus { wantarray ? ($STATUS, $STATUS_TS) : $STATUS }

sub now {
	my ($class, $cb, $ecb) = @_;
	$class->get('/now', sub {
		$NOW = shift;
		$NOW_TS = time();
		$cb->($NOW) if $cb;
	}, $ecb);
}

sub cachedNow { wantarray ? ($NOW, $NOW_TS) : $NOW }

sub streamUrl {
	my $class = shift;
	my $base = $class->baseUrl;

	my $url = $prefs->get('stream_override');
	$url = undef unless defined $url && $url =~ /\S/;
	$url ||= eval { $STATUS->{stream}{url} };
	$url ||= "$base/api/v1/stream" if $base;
	return undef unless $url;

	my $token = _token();
	if ($token && $base && $url =~ m{^\Q$base\E/api/v1/stream(?:[?#]|$)} && $url !~ /[?&]token=/) {
		$url .= ($url =~ /\?/ ? '&' : '?') . 'token=' . uri_escape_utf8($token);
	}
	return $url;
}

sub play {
	my ($class, $uri, $cb, $ecb) = @_;
	$class->post('/play', (defined $uri && length $uri ? { uri => $uri } : {}), $cb, $ecb);
}

sub resume { my ($class, $cb, $ecb) = @_; $class->play(undef, $cb, $ecb) }
sub pause  { my ($class, $cb, $ecb) = @_; $class->post('/pause', {}, $cb, $ecb) }
sub next   { my ($class, $cb, $ecb) = @_; $class->post('/next',  {}, $cb, $ecb) }
sub prev   { my ($class, $cb, $ecb) = @_; $class->post('/prev',  {}, $cb, $ecb) }

sub queue {
	my ($class, $uri, $cb, $ecb) = @_;
	$class->post('/queue', { uri => $uri }, $cb, $ecb);
}

sub itemPath {
	my ($class, $uri) = @_;
	return '/item/' . uri_escape_utf8($uri, '^A-Za-z0-9\-\._~:');
}

1;
