package Slim::Networking::SimpleAsyncHTTP;
# Test stub: records requests; tests trigger callbacks via respond()/fail().
use strict;
our @REQUESTS;
sub new { my ($c,$cb,$ecb,$p)=@_; bless { cb=>$cb, ecb=>$ecb, params=>$p||{} }, $c }
sub get  { my ($s,$url,@h)=@_; @$s{qw(method url headers)}=('GET',$url,{@h}); push @REQUESTS,$s; $s }
sub post { my ($s,$url,@h)=@_; my $b=pop @h; @$s{qw(method url headers body)}=('POST',$url,{@h},$b); push @REQUESTS,$s; $s }
sub last { $REQUESTS[-1] }
sub reset { @REQUESTS=() }
sub code { $_[0]{code} }
sub content { $_[0]{content} }
sub params { $_[0]{params} }
sub respond { my ($s,$content,$code)=@_; $s->{content}=$content; $s->{code}=$code||200; $s->{cb}->($s) }
sub fail { my ($s,$code,$content,$err)=@_; $s->{code}=$code; $s->{content}=$content; $s->{ecb}->($s,$err||"HTTP $code") }
1;
