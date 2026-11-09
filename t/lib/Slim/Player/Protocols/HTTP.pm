package Slim::Player::Protocols::HTTP;
use strict;
sub new { my ($c,$a)=@_; bless {%$a}, $c }
1;
