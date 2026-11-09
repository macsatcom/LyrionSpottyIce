package Slim::Utils::Prefs;
use strict;
use Exporter 'import';
our @EXPORT = qw(preferences);
my %NS;
sub preferences { my $ns=shift; $NS{$ns} ||= bless { ns=>$ns, v=>{} }, 'Slim::Utils::Prefs::Namespace' }
package Slim::Utils::Prefs::Namespace;
sub get { $_[0]{v}{$_[1]} }
sub set { $_[0]{v}{$_[1]} = $_[2] }
sub init { my ($s,$d)=@_; $s->{v}{$_} //= $d->{$_} for keys %$d; $s }
sub remove { delete $_[0]{v}{$_[1]} }
1;
