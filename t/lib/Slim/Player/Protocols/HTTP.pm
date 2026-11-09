package Slim::Player::Protocols::HTTP;
use strict;
sub new { my ($c,$a)=@_; bless {%$a}, $c }
# Real LMS hands the URL to Slim::Utils::Scanner::Remote, which fails for non-HTTP URLs.
sub scanUrl {
	my ($class, $url, $args) = @_;
	$args->{cb}->(undef, "Cannot request non-HTTP URL $url") unless $url =~ m{^https?://};
}
1;
