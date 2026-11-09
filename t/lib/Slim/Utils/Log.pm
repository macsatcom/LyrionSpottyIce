package Slim::Utils::Log;
use strict;
use Exporter 'import';
our @EXPORT = qw(logger);
my $L = bless {}, 'Slim::Utils::Log::Logger';
sub logger { $L }
sub addLogCategory { $L }
package Slim::Utils::Log::Logger;
sub is_debug { 0 } sub is_info { 0 }
sub debug {} sub info {} sub warn {} sub error {}
package main;
BEGIN { *main::DEBUGLOG = sub () { 0 } unless defined &main::DEBUGLOG; *main::INFOLOG = sub () { 0 } unless defined &main::INFOLOG; }
1;
