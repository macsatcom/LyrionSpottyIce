package Plugins::SpottyIce::Plugin;

use strict;
use warnings;
use base qw(Slim::Plugin::OPMLBased);

use URI::Escape qw(uri_escape_utf8);

use Slim::Control::Request;
use Slim::Player::ProtocolHandlers;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(cstring);

use Plugins::SpottyIce::API;
use Plugins::SpottyIce::Entity;
use Plugins::SpottyIce::ProtocolHandler;

use constant PAGE_SIZE   => 50;
use constant SEARCH_SIZE => 10;

my $prefs = preferences('plugin.spottyice');
my $API   = 'Plugins::SpottyIce::API';
my $E     = 'Plugins::SpottyIce::Entity';

sub initPlugin {
	my $class = shift;

	$prefs->init({ api_url => '', token => '', stream_override => '' });

	if (main::WEBUI) {
		require Plugins::SpottyIce::Settings;
		Plugins::SpottyIce::Settings->new;
	}

	Slim::Player::ProtocolHandlers->registerHandler(spottyice => 'Plugins::SpottyIce::ProtocolHandler');

	Slim::Control::Request::subscribe(\&Plugins::SpottyIce::ProtocolHandler::onCommand, [['pause', 'play', 'stop']]);

	$class->SUPER::initPlugin(
		feed   => \&handleFeed,
		tag    => 'spottyice',
		menu   => 'apps',
		is_app => 1,
		weight => 1,
	);
}

sub getDisplayName { 'PLUGIN_SPOTTYICE' }

sub playerMenu { undef }

sub getIcon { Plugins::SpottyIce::ProtocolHandler->getIcon }

sub _text { { items => [{ name => $_[0], type => 'text' }] } }

sub handleFeed {
	my ($client, $cb, $args) = @_;

	return $cb->({ items => [{ name => cstring($client, 'PLUGIN_SPOTTYICE_NOT_CONFIGURED'), type => 'textarea' }] })
		unless $API->baseUrl;

	my @search = map {
		my ($type, $str) = @$_;
		{ type => 'search', name => cstring($client, $str), url => \&search, passthrough => [{ type => $type }] }
	} ([track => 'PLUGIN_SPOTTYICE_SEARCH_TRACKS'], [album => 'PLUGIN_SPOTTYICE_SEARCH_ALBUMS'],
	   [artist => 'PLUGIN_SPOTTYICE_SEARCH_ARTISTS'], [playlist => 'PLUGIN_SPOTTYICE_SEARCH_PLAYLISTS'],
	   [show => 'PLUGIN_SPOTTYICE_SEARCH_PODCASTS']);

	my @lib = map {
		my ($path, $str) = @$_;
		{ type => 'link', name => cstring($client, $str), url => \&_browsePage, passthrough => [{ path => $path, offset => 0 }] }
	} (['/library/playlists' => 'PLUGIN_SPOTTYICE_PLAYLISTS'], ['/library/albums' => 'PLUGIN_SPOTTYICE_ALBUMS'],
	   ['/library/tracks' => 'PLUGIN_SPOTTYICE_LIKED'], ['/library/artists' => 'PLUGIN_SPOTTYICE_ARTISTS'],
	   ['/library/shows' => 'PLUGIN_SPOTTYICE_PODCASTS'], ['/library/recent' => 'PLUGIN_SPOTTYICE_RECENT']);

	$cb->({ items => [
		{ type => 'link', name => cstring($client, 'PLUGIN_SPOTTYICE_SEARCH'), items => \@search },
		@lib,
		{ type => 'link', name => cstring($client, 'PLUGIN_SPOTTYICE_NOW_PLAYING'), url => \&nowPlaying },
	] });
}

# Map a Page to OPML items; $more is a closure ($nextOffset) -> passthrough-able item or undef
sub _mapPage {
	my ($client, $page, $moreItem) = @_;
	$page = {} unless ref $page eq 'HASH';
	my @items = grep { defined } map { $E->can('toItem')->($_, \&browseItem) } @{ ref $page->{items} eq 'ARRAY' ? $page->{items} : [] };
	if ($page->{next} && $moreItem) {
		my $offset = ($page->{offset} || 0) + ($page->{limit} || scalar(@{ $page->{items} || [] }) || 0);
		push @items, $moreItem->($offset);
	}
	return \@items;
}

sub _more {
	my ($client, $url, $pt) = @_;
	return { name => cstring($client, 'PLUGIN_SPOTTYICE_MORE'), type => 'link', url => $url, passthrough => [$pt] };
}

sub _withQuery {
	my ($path, $query) = @_;
	return $path . ($path =~ /\?/ ? '&' : '?') . $query;
}

sub _browsePage {
	my ($client, $cb, $args, $params) = @_;
	my $path   = $params->{path};
	my $offset = $params->{offset} || 0;

	$API->get(_withQuery($path, 'limit=' . PAGE_SIZE . "&offset=$offset"), sub {
		my $items = _mapPage($client, shift, sub {
			_more($client, \&_browsePage, { path => $path, offset => $_[0] });
		});
		$items = _text(cstring($client, 'PLUGIN_SPOTTYICE_NO_RESULTS'))->{items} unless @$items;
		$cb->({ items => $items });
	}, sub { $cb->(_text(shift)) });
}

sub search {
	my ($client, $cb, $args, $params) = @_;
	my $query  = defined $params->{query} ? $params->{query} : $args->{search};
	my $type   = $params->{type} || 'track';
	my $offset = $params->{offset} || 0;

	return $cb->(_text(cstring($client, 'PLUGIN_SPOTTYICE_NO_RESULTS'))) unless defined $query && length $query;

	$API->get('/search?q=' . uri_escape_utf8($query) . "&type=$type&limit=" . SEARCH_SIZE . "&offset=$offset", sub {
		my $data = shift;
		my $items = _mapPage($client, ref $data eq 'HASH' ? $data->{$type} : undef, sub {
			_more($client, \&search, { query => $query, type => $type, offset => $_[0] });
		});
		$items = _text(cstring($client, 'PLUGIN_SPOTTYICE_NO_RESULTS'))->{items} unless @$items;
		$cb->({ items => $items });
	}, sub { $cb->(_text(shift)) });
}

sub browseItem {
	my ($client, $cb, $args, $params) = @_;
	my $uri = $params->{uri};

	$API->get($API->itemPath($uri), sub {
		my $data = shift || {};
		my $type = eval { $data->{item}{entity_type} } || '';
		my $children = $data->{children};
		my @items;

		if ($type eq 'artist' && ref $data->{top_tracks} eq 'ARRAY' && @{ $data->{top_tracks} }) {
			my @top = grep { defined } map { $E->can('toItem')->($_, \&browseItem) } @{ $data->{top_tracks} };
			push @items, { name => cstring($client, 'PLUGIN_SPOTTYICE_TOP_TRACKS'), type => 'playlist', items => \@top } if @top;
		}

		if (ref $children eq 'HASH' && $children->{error}) {
			push @items, { name => $children->{error}, type => 'text' };
		}
		elsif (ref $children eq 'HASH') {
			push @items, @{ _mapPage($client, $children, sub {
				_more($client, \&_browseChildren, { uri => $uri, offset => $_[0] });
			}) };
		}
		elsif (my $item = $E->can('toItem')->($data->{item}, \&browseItem)) {
			push @items, $item;    # track/episode
		}

		@items = @{ _text(cstring($client, 'PLUGIN_SPOTTYICE_NO_RESULTS'))->{items} } unless @items;
		$cb->({ items => \@items });
	}, sub { $cb->(_text(shift)) });
}

sub _browseChildren {
	my ($client, $cb, $args, $params) = @_;
	my $uri = $params->{uri};
	$API->get(_withQuery($API->itemPath($uri), 'limit=' . PAGE_SIZE . "&offset=" . ($params->{offset} || 0)), sub {
		my $data = shift || {};
		my $children = $data->{children};
		return $cb->(_text($children->{error})) if ref $children eq 'HASH' && $children->{error};
		my $items = _mapPage($client, $children, sub {
			_more($client, \&_browseChildren, { uri => $uri, offset => $_[0] });
		});
		$items = _text(cstring($client, 'PLUGIN_SPOTTYICE_NO_RESULTS'))->{items} unless @$items;
		$cb->({ items => $items });
	}, sub { $cb->(_text(shift)) });
}

sub nowPlaying {
	my ($client, $cb, $args) = @_;

	$API->now(sub {
		my $now = shift || {};
		my $item = $now->{item};
		return $cb->(_text(cstring($client, 'PLUGIN_SPOTTYICE_NOTHING_PLAYING'))) unless ref $item eq 'HASH' && $item->{uri};

		my @items = grep { defined $_->{name} && length $_->{name} } (
			{ name => $E->can('name')->($item), type => 'text', image => $E->can('cover')->($item) },
			{ name => $E->can('creators')->($item), type => 'text' },
			{ name => $E->can('parentName')->($item), type => 'text' },
			{ name => $now->{status}, type => 'text' },
		);

		$API->get('/queue?limit=10', sub {
			my $q = shift;
			my $up = ref $q eq 'HASH' ? $q->{upcoming} : undef;
			push @items, grep { defined } map { $E->can('toItem')->($_, \&browseItem) } @{ ref $up eq 'ARRAY' ? $up : [] };
			$cb->({ items => \@items });
		}, sub { $cb->({ items => \@items }) });
	}, sub { $cb->(_text(shift)) });
}

1;
