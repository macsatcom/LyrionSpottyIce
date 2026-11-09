use strict;
use warnings;
use lib 't/lib';
use Test::More;
BEGIN { *main::WEBUI = sub () { 0 } }
# map Plugins::SpottyIce::* onto ./SpottyIce
unshift @INC, sub {
	my (undef, $f) = @_;
	return unless $f =~ m{^Plugins/SpottyIce/(.+)$};
	open my $fh, '<', "./SpottyIce/$1" or return;
	$INC{$f} = "./SpottyIce/$1";
	return $fh;
};
require_ok('Plugins/SpottyIce/API.pm');
require_ok('Plugins/SpottyIce/Settings.pm');
require_ok('Plugins/SpottyIce/ProtocolHandler.pm');
require_ok('Plugins/SpottyIce/Plugin.pm');
done_testing;
