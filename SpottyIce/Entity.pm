package Plugins::SpottyIce::Entity;

# Pure helpers mapping Spotty Ice API entities to OPML items. No Slim deps.
use strict;
use warnings;

sub _h { ref $_[0] eq 'HASH' ? $_[0] : {} }
sub _dec { _h(_h($_[0])->{decorations}) }
sub _entName { my $n = _h(_dec($_[0])->{identity})->{name}; defined $n && length $n ? $n : undef }

sub name {
	my $e = shift;
	my $n = _entName($e);
	return $n if defined $n;
	my $u = _h($e)->{uri};
	return defined $u ? $u : '';
}

sub creators {
	my $c = _dec(shift)->{creators};
	return '' unless ref $c eq 'ARRAY';
	return join(', ', grep { defined } map { _entName(_h($_)->{entity}) } @$c);
}

sub parentName { _entName(_h(_dec(shift)->{parent})->{entity}) }

sub cover {
	my $c = _h(_dec(shift)->{visual_identity})->{cover};
	return undef unless ref $c eq 'ARRAY';
	my @c = grep { ref $_ eq 'HASH' && defined $_->{url} } @$c;
	return undef unless @c;
	for my $size (qw(large xlarge default)) {
		my ($m) = grep { ($_->{size} || '') eq $size } @c;
		return $m->{url} if $m;
	}
	return $c[-1]{url};
}

sub durationSecs {
	my $ms = _h(_dec(shift)->{playback})->{duration_ms};
	return defined $ms ? $ms / 1000 : undef;
}

sub _type { my $t = _h($_[0])->{entity_type}; defined $t ? $t : '' }
sub isPlayable  { _type($_[0]) =~ /^(?:track|episode)$/ ? 1 : 0 }
sub isContainer { _type($_[0]) =~ /^(?:album|playlist|artist|show)$/ ? 1 : 0 }

sub toItem {
	my ($e, $linkCb, $playCb) = @_;
	my $uri = _h($e)->{uri};
	return undef unless defined $uri && length $uri;
	my $line2 = creators($e);
	$line2 = parentName($e) unless length $line2;
	my %i;
	if (isPlayable($e)) {
		%i = (name => name($e), line1 => name($e), line2 => $line2, image => cover($e),
			type => 'audio', url => "spottyice://$uri", duration => durationSecs($e),
			on_select => 'play', playall => 1);
	} elsif (isContainer($e)) {
		%i = (name => name($e), line2 => $line2, image => cover($e), type => 'playlist',
			url => $linkCb, passthrough => [{ uri => $uri, name => name($e) }], playlist => $playCb);
	} else {
		return undef;
	}
	delete $i{$_} for grep { !defined $i{$_} || $i{$_} eq '' } keys %i;
	return \%i;
}

1;
