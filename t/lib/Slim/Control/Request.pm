package Slim::Control::Request;
use strict;
our (@SUBS, @NOTIFY);
sub subscribe { push @SUBS, [@_] }
sub notifyFromArray { push @NOTIFY, [@_] }
sub new { my ($c,$client,$cmd)=@_; bless { client=>$client, cmd=>$cmd }, $c }
sub client { $_[0]{client} }
sub isCommand { my ($s,$p)=@_; $s->{cmd} eq $p->[0][0] }
1;
