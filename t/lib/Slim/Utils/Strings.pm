package Slim::Utils::Strings;
use strict;
use Exporter 'import';
our @EXPORT_OK = qw(string cstring);
sub string { $_[0] }
sub cstring { $_[1] }
1;
