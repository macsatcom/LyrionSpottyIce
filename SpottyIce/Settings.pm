package Plugins::SpottyIce::Settings;

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;
use Plugins::SpottyIce::API;

my $prefs = preferences('plugin.spottyice');

sub name { Slim::Web::HTTP::CSRF->protectName('PLUGIN_SPOTTYICE') }

sub page { Slim::Web::HTTP::CSRF->protectURI('plugins/SpottyIce/settings/basic.html') }

sub prefs { return ($prefs, qw(api_url token stream_override)) }

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;

	if ($params->{saveSettings} && defined $params->{pref_api_url}) {
		$params->{pref_api_url} =~ s/^\s+|\s+$//g;
		$params->{pref_api_url} =~ s{/+$}{};
		# so the status probe below targets the new URL; base handler persists all prefs
		$prefs->set('api_url', $params->{pref_api_url});
	}

	my $done = sub {
		$callback->($client, $params, $class->SUPER::handler($client, $params), @args);
	};

	if (!Plugins::SpottyIce::API->baseUrl) {
		$params->{status_error} = Slim::Utils::Strings::string('PLUGIN_SPOTTYICE_NOT_CONFIGURED');
		$done->();
		return undef;
	}

	Plugins::SpottyIce::API->status(
		sub {
			my $status = shift || {};
			my $days = eval { $status->{updater}{days_left} };
			$status->{days_left_rounded} = sprintf('%d', $days + 0.5) if defined $days && $days =~ /^-?[\d.]+$/;
			$params->{status} = $status;
			$done->();
		},
		sub {
			$params->{status_error} = shift;
			$done->();
		},
		5,
	);

	return undef;
}

1;
