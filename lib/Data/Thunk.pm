#!/usr/bin/perl

package Data::Thunk;

use strict;
use warnings;

use Data::Thunk::Code;
use Data::Thunk::ScalarValue;

use Scalar::Util qw(blessed);

use base qw(Exporter);

our $VERSION = "0.01";

our @EXPORT = our @EXPORT_OK = qw(lazy force);

sub lazy (&) {
	my $thunk = shift;
	bless { code => $thunk }, "Data::Thunk::Code";
}

my ( $vivify_code, $vivify_scalar ) = ( $Data::Thunk::Code::vivify_code, $Data::Thunk::ScalarValue::vivify_scalar );

sub force ($) {
	my $val = shift;

	if ( blessed($val) ) { 
		if ( blessed($val) eq 'Data::Thunk::Code' ) {
			return $val->$vivify_code;
		} elsif ( blessed($val) eq 'Data::Thunk::ScalarValue' ) {
			return $val->$vivify_scalar;
		}
	}

	return $val;
}

{
	package Data::Thunk::NoOverload;
	# we temporarily bless into this to avoid overloading
}

__PACKAGE__

__END__

=pod

=head1 NAME

Data::Thunk - A sneakier Scalar::Defer ;-)

=head1 SYNOPSIS

	use Data::Thunk qw(lazy);

	my %hash = (
		foo => lazy { $expensive },
	);

	$hash{bar}{gorch} = $hash{foo};

	$hash{bar}{gorch}->foo; # vivifies the object

	warn overload::StrVal($hash{foo}); # replaced with the value

=head1 DESCRIPTION

This is an implementation of thunks a la L<Scalar::Defer>, but uses
L<Data::Swap> and assignment to C<$_[0]> in order to leave a minimal trace of the thunk.

In the case that a reference is returned from C<lazy { }> L<Data::Swap> can
replace the thunk ref with the result ref, so all the references that pointed
to the thunk are now pointing to the result (at the same address).

If a simple value is returned then the thunk is swapped with a simple scalar
container, which will assign the value to C<$_[0]> on each overloaded use.

In this particular example:

	my $x = {
		foo => lazy { "blah" },
		bar => lazy { [ "boink" ] },
	};

	$x->{quxx} = $x->{foo};
	$x->{gorch} = $x->{bar};

	warn $x->{bar};
	warn $x->{foo};
	warn $x->{quxx};

	use Data::Dumper;
	warn Dumper($x);

The resulting structure is:

	$VAR1 = {
		'bar' => [ 'boink' ],
		'foo' => 'blah',
		'gorch' => $VAR1->{'bar'},
		'quxx' => 'blah'
	};

Whereas with L<Scalar::Defer> the trampoline objects remain:

	$VAR1 = {
		'bar' => bless( do{\(my $o = 25206320)}, '0' ),
		'foo' => bless( do{\(my $o = 25387232)}, '0' ),
		'gorch' => $VAR1->{'bar'},
		'quxx' => $VAR1->{'foo'}
	};

This is potentially problematic because L<Scalar::Util/reftype> and
L<Scalar::Util/blessed> can't be fooled. With L<Data::Thunk> the problem still
exists before values are vivified, but not after.

Furthermore this module uses L<UNIVERSAL::ref> instead of blessing to C<0>.
Blessing to C<0> pretends that everything is a non ref (C<ref($thunk)> returns
the name of the package, which evaluates as false), so deferred values that
become objects don't appear to be as such.

=head1 EXPORTS

=over 4

=item lazy { ... }

Create a new thunk.

=item force

Vivify the value and return the result.

=back

=head1 SEE ALSO

L<Scalar::Defer>, L<Data::Lazy>, L<Data::Swap>, L<UNIVERSAL::ref>.

=head1 VERSION CONTROL

This module is maintained using Darcs. You can get the latest version from
L<http://nothingmuch.woobling.org/code>, and use C<darcs send> to commit
changes.

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

	Copyright (c) 2008 Yuval Kogman. All rights reserved
	This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut

