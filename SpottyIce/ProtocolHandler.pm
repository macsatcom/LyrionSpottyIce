package Plugins::SpottyIce::ProtocolHandler;

# Spotty Ice protocol handler: spottyice://spotify:<type>:<id>
# Starting playback asks the container to play the URI, then LMS streams the
# container's live Icecast stream via the HTTP protocol handler. The whole Spotify
# context plays inside that one stream, so metadata is polled from /now.

use strict;
use warnings;
use base qw(Slim::Player::Protocols::HTTP);

use Slim::Control::Request;
use Slim::Player::Client;
use Slim::Utils::Log;
use Slim::Utils::Timers;

use Plugins::SpottyIce::API;
use Plugins::SpottyIce::Entity;

use constant POLL_INTERVAL => 2;
use constant ICON => 'plugins/SpottyIce/html/images/icon.png';

my $log = logger('plugin.spottyice');
my $API = 'Plugins::SpottyIce::API';
my $E   = 'Plugins::SpottyIce::Entity';

my $lastItemUri;

sub isRemote { 1 }
sub canSeek  { 0 }
sub canDirectStream { 0 }    # always proxy through LMS (token in URL, Icecast)

sub uriFromUrl {
	my ($class, $url) = @_;
	$url = '' unless defined $url;
	$url =~ s{^spottyice://}{};
	return $url;
}

sub _isOurs { defined $_[0] && $_[0] =~ m{^spottyice://} }

sub _format {
	my $status = $API->cachedStatus;
	my $stream = ref $status eq 'HASH' && ref $status->{stream} eq 'HASH' ? $status->{stream} : {};
	my $ct    = lc($stream->{content_type} || '');
	my $codec = lc($stream->{codec} || '');
	return 'mp3' if $ct =~ m{audio/(?:mpeg|mp3)};
	return 'aac' if $ct =~ m{audio/(?:aac|aacp)};
	return ($codec =~ /flac/ ? 'ogf' : 'ogg') if $ct =~ m{(?:audio|application)/ogg};
	return 'mp3';
}

sub contentType     { _format() }
sub getFormatForURL { _format() }

sub getNextTrack {
	my ($class, $song, $successCb, $errorCb) = @_;
	my $uri = $class->uriFromUrl($song->track->url);

	my $start = sub {
		$API->play($uri, sub {
			my $streamUrl = $API->streamUrl;
			return $errorCb->('PLUGIN_SPOTTYICE_NOT_CONFIGURED') unless $streamUrl;
			$song->streamUrl($streamUrl);
			$lastItemUri = undef;
			_startPoller();
			$successCb->();
		}, sub { $errorCb->(shift) });
	};

	# refresh stream info (url/content type); failure is not fatal
	$API->status($start, $start, 5);
}

# Slim::Player::Protocols::HTTP->new($args): connect to the real stream URL
sub new {
	my ($class, $args) = @_;
	my $song = $args->{song} or return;
	my $streamUrl = $song->streamUrl() or return;
	return $class->SUPER::new({ %$args, url => $streamUrl });
}

sub getIcon { ICON }

sub _clientPlaysUs {
	my $client = shift;
	my $song = $client && $client->playingSong or return 0;
	my $track = $song->track or return 0;
	return _isOurs($track->url);
}

sub getMetadataFor {
	my ($class, $client, $url) = @_;
	my $now  = $API->cachedNow;
	my $item = ref $now eq 'HASH' ? $now->{item} : undef;

	if (ref $item eq 'HASH' && $item->{uri} && _clientPlaysUs($client)) {
		my $cover = $E->can('cover')->($item) || ICON;
		return {
			title    => $E->can('name')->($item),
			artist   => $E->can('creators')->($item),
			album    => $E->can('parentName')->($item),
			cover    => $cover,
			icon     => $cover,
			duration => $E->can('durationSecs')->($item),
			type     => 'Spotify (Spotty Ice)',
		};
	}

	return { title => $class->uriFromUrl($url), icon => ICON, cover => ICON, type => 'Spotify (Spotty Ice)' };
}

sub _activeClients {
	grep { $_->isPlaying && _clientPlaysUs($_) } Slim::Player::Client::clients();
}

sub _startPoller {
	Slim::Utils::Timers::killTimers(undef, \&_poll);
	Slim::Utils::Timers::setTimer(undef, time() + POLL_INTERVAL, \&_poll);
}

sub _poll {
	Slim::Utils::Timers::killTimers(undef, \&_poll);
	my @clients = _activeClients() or return;

	$API->now(sub {
		my $now = shift;
		my $uri = ref $now eq 'HASH' && ref $now->{item} eq 'HASH' ? $now->{item}{uri} : undef;
		if (($uri // '') ne ($lastItemUri // '')) {
			$lastItemUri = $uri;
			Slim::Control::Request::notifyFromArray($_, ['newmetadata']) for @clients;
		}
		_startPoller();
	}, sub {
		$log->warn('now poll failed: ' . (shift // ''));
		_startPoller();
	});
}

# Transport forwarding (subscribed in Plugin::initPlugin for pause/stop).
# Only pause/unpause/stop are forwarded; next/prev are not mapped because the
# Spotify context continues inside the single live stream.
sub onCommand {
	my $request = shift;
	my $client = $request->client or return;
	return unless _clientPlaysUs($client);

	if ($request->isCommand([['pause']])) {
		$client->isPaused ? $API->pause : $API->resume;
	}
	elsif ($request->isCommand([['stop']])) {
		$API->pause;
	}
	elsif ($request->isCommand([['play']])) {
		$API->resume;
	}
}

1;
