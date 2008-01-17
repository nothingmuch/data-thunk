#!/usr/bin/perl

package Data::Thunk::ScalarValue;

use strict;
use warnings;

use UNIVERSAL::ref;

use overload (
	fallback => 1, map {
		$_ => our $vivify_scalar = sub {
			my $self = $_[0];

			# must rebless to something unoverloaded in order to get at the value
			bless $self, "Data::Thunk::NoOverload";
			my $val = $$self;
			bless $self, __PACKAGE__;

			# try to replace the container with the value wherever we found it
			local $@; eval { $_[0] = $val }; # might be readonly;

			$val;
		}
	} qw( bool "" 0+ ${} @{} %{} &{} *{} )
);

sub ref {
	my $self = shift;
	return;
}

__PACKAGE__

__END__
