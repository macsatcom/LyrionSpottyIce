package Slim::Player::ProtocolHandlers;
use strict;
our %HANDLERS;
sub registerHandler { my ($c,$s,$h)=@_; $HANDLERS{$s}=$h }
1;
