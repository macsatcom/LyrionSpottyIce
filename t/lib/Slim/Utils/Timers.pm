package Slim::Utils::Timers;
use strict;
our @TIMERS;
sub setTimer { my ($o,$t,$f)=@_; push @TIMERS, $f }
sub killTimers { my ($o,$f)=@_; @TIMERS = grep { $_ != $f } @TIMERS }
1;
